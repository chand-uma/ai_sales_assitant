"""
Business Insights Generation Module
Generates business insights from processed SAP data
"""

import logging
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
import pyodbc
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
import os

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class InsightsGenerator:
    def __init__(self):
        self.credential = DefaultAzureCredential()
        self.key_vault_url = os.environ.get('KEY_VAULT_URL')
        self.sql_connection_string = os.environ.get('SQL_CONNECTION_STRING')
        
        if self.key_vault_url:
            self.secret_client = SecretClient(
                vault_url=self.key_vault_url,
                credential=self.credential
            )
        else:
            self.secret_client = None

    def get_sql_connection_string(self) -> str:
        """Get SQL connection string from environment or Key Vault"""
        try:
            if self.sql_connection_string:
                return self.sql_connection_string
            
            if self.secret_client:
                secret = self.secret_client.get_secret("sql-connection-string")
                return secret.value
            
            raise ValueError("No SQL connection string available")
        except Exception as e:
            logger.error(f"Error getting SQL connection string: {str(e)}")
            raise

    def get_sales_data(self, days: int = 30) -> pd.DataFrame:
        """Get sales data for the specified number of days"""
        try:
            connection_string = self.get_sql_connection_string()
            query = f"""
                SELECT 
                    s.CustomerID,
                    s.ProductCode,
                    s.SalesDate,
                    s.SalesAmount,
                    s.SalesQuantity,
                    s.UnitPrice,
                    s.Region,
                    s.Channel,
                    s.SalesRep,
                    s.DataSource,
                    c.CustomerSegment,
                    p.ProductCategory
                FROM Sales s
                LEFT JOIN Customers c ON s.CustomerID = c.CustomerID
                LEFT JOIN Products p ON s.ProductCode = p.ProductCode
                WHERE s.IsActive = 1
                AND s.SalesDate >= DATEADD(day, -{days}, GETUTCDATE())
                ORDER BY s.SalesDate DESC
            """
            
            with pyodbc.connect(connection_string) as conn:
                df = pd.read_sql(query, conn)
            
            logger.info(f"Retrieved {len(df)} sales records for insights generation")
            return df
            
        except Exception as e:
            logger.error(f"Error getting sales data: {str(e)}")
            return pd.DataFrame()

    def generate_sales_trends(self, sales_data: pd.DataFrame) -> Dict[str, Any]:
        """Generate sales trend insights"""
        try:
            if sales_data.empty:
                return {"error": "No sales data available"}
            
            # Convert SalesDate to datetime
            sales_data['SalesDate'] = pd.to_datetime(sales_data['SalesDate'])
            
            # Daily sales trends
            daily_sales = sales_data.groupby(sales_data['SalesDate'].dt.date).agg({
                'SalesAmount': 'sum',
                'SalesQuantity': 'sum',
                'CustomerID': 'nunique'
            }).reset_index()
            
            daily_sales.columns = ['Date', 'TotalSales', 'TotalQuantity', 'UniqueCustomers']
            
            # Calculate trends
            total_sales = daily_sales['TotalSales'].sum()
            avg_daily_sales = daily_sales['TotalSales'].mean()
            sales_growth = self.calculate_growth_rate(daily_sales['TotalSales'])
            
            # Top performing days
            top_days = daily_sales.nlargest(5, 'TotalSales')[['Date', 'TotalSales']].to_dict('records')
            
            return {
                "total_sales": float(total_sales),
                "average_daily_sales": float(avg_daily_sales),
                "sales_growth_rate": float(sales_growth),
                "top_performing_days": top_days,
                "total_unique_customers": int(daily_sales['UniqueCustomers'].sum()),
                "average_daily_customers": float(daily_sales['UniqueCustomers'].mean())
            }
            
        except Exception as e:
            logger.error(f"Error generating sales trends: {str(e)}")
            return {"error": str(e)}

    def generate_customer_insights(self, sales_data: pd.DataFrame) -> Dict[str, Any]:
        """Generate customer insights"""
        try:
            if sales_data.empty:
                return {"error": "No sales data available"}
            
            # Customer analysis
            customer_analysis = sales_data.groupby('CustomerID').agg({
                'SalesAmount': ['sum', 'count', 'mean'],
                'SalesQuantity': 'sum',
                'SalesDate': ['min', 'max'],
                'CustomerSegment': 'first',
                'Region': 'first'
            }).round(2)
            
            customer_analysis.columns = ['TotalSales', 'OrderCount', 'AvgOrderValue', 'TotalQuantity', 'FirstOrder', 'LastOrder', 'Segment', 'Region']
            customer_analysis = customer_analysis.reset_index()
            
            # Top customers
            top_customers = customer_analysis.nlargest(10, 'TotalSales')[['CustomerID', 'TotalSales', 'OrderCount', 'AvgOrderValue', 'Segment', 'Region']].to_dict('records')
            
            # Customer segments analysis
            segment_analysis = customer_analysis.groupby('Segment').agg({
                'CustomerID': 'count',
                'TotalSales': 'sum',
                'AvgOrderValue': 'mean'
            }).round(2)
            segment_analysis.columns = ['CustomerCount', 'TotalSales', 'AvgOrderValue']
            segment_analysis = segment_analysis.reset_index()
            
            # Customer retention analysis
            recent_customers = customer_analysis[customer_analysis['LastOrder'] >= (datetime.now() - timedelta(days=7)).date()]
            returning_customers = customer_analysis[customer_analysis['OrderCount'] > 1]
            
            return {
                "total_customers": len(customer_analysis),
                "top_customers": top_customers,
                "segment_analysis": segment_analysis.to_dict('records'),
                "recent_customers": len(recent_customers),
                "returning_customers": len(returning_customers),
                "customer_retention_rate": float(len(returning_customers) / len(customer_analysis) * 100) if len(customer_analysis) > 0 else 0
            }
            
        except Exception as e:
            logger.error(f"Error generating customer insights: {str(e)}")
            return {"error": str(e)}

    def generate_product_insights(self, sales_data: pd.DataFrame) -> Dict[str, Any]:
        """Generate product performance insights"""
        try:
            if sales_data.empty:
                return {"error": "No sales data available"}
            
            # Product analysis
            product_analysis = sales_data.groupby('ProductCode').agg({
                'SalesAmount': ['sum', 'count', 'mean'],
                'SalesQuantity': 'sum',
                'UnitPrice': 'mean',
                'ProductCategory': 'first'
            }).round(2)
            
            product_analysis.columns = ['TotalSales', 'OrderCount', 'AvgOrderValue', 'TotalQuantity', 'AvgUnitPrice', 'Category']
            product_analysis = product_analysis.reset_index()
            
            # Top products
            top_products = product_analysis.nlargest(10, 'TotalSales')[['ProductCode', 'TotalSales', 'TotalQuantity', 'AvgUnitPrice', 'Category']].to_dict('records')
            
            # Category analysis
            category_analysis = product_analysis.groupby('Category').agg({
                'ProductCode': 'count',
                'TotalSales': 'sum',
                'TotalQuantity': 'sum',
                'AvgUnitPrice': 'mean'
            }).round(2)
            category_analysis.columns = ['ProductCount', 'TotalSales', 'TotalQuantity', 'AvgUnitPrice']
            category_analysis = category_analysis.reset_index()
            
            # Product performance metrics
            total_products = len(product_analysis)
            high_performing_products = len(product_analysis[product_analysis['TotalSales'] > product_analysis['TotalSales'].quantile(0.8)])
            
            return {
                "total_products": total_products,
                "top_products": top_products,
                "category_analysis": category_analysis.to_dict('records'),
                "high_performing_products": high_performing_products,
                "product_diversity_score": float(high_performing_products / total_products * 100) if total_products > 0 else 0
            }
            
        except Exception as e:
            logger.error(f"Error generating product insights: {str(e)}")
            return {"error": str(e)}

    def generate_regional_insights(self, sales_data: pd.DataFrame) -> Dict[str, Any]:
        """Generate regional performance insights"""
        try:
            if sales_data.empty:
                return {"error": "No sales data available"}
            
            # Regional analysis
            regional_analysis = sales_data.groupby('Region').agg({
                'SalesAmount': ['sum', 'count', 'mean'],
                'SalesQuantity': 'sum',
                'CustomerID': 'nunique',
                'SalesRep': 'nunique'
            }).round(2)
            
            regional_analysis.columns = ['TotalSales', 'OrderCount', 'AvgOrderValue', 'TotalQuantity', 'UniqueCustomers', 'SalesReps']
            regional_analysis = regional_analysis.reset_index()
            
            # Top regions
            top_regions = regional_analysis.nlargest(5, 'TotalSales')[['Region', 'TotalSales', 'OrderCount', 'UniqueCustomers', 'SalesReps']].to_dict('records')
            
            # Regional performance metrics
            total_regions = len(regional_analysis)
            avg_sales_per_region = regional_analysis['TotalSales'].mean()
            best_region = regional_analysis.loc[regional_analysis['TotalSales'].idxmax(), 'Region']
            best_region_sales = regional_analysis['TotalSales'].max()
            
            return {
                "total_regions": total_regions,
                "top_regions": top_regions,
                "average_sales_per_region": float(avg_sales_per_region),
                "best_performing_region": best_region,
                "best_region_sales": float(best_region_sales),
                "regional_distribution": regional_analysis[['Region', 'TotalSales']].to_dict('records')
            }
            
        except Exception as e:
            logger.error(f"Error generating regional insights: {str(e)}")
            return {"error": str(e)}

    def generate_sales_rep_insights(self, sales_data: pd.DataFrame) -> Dict[str, Any]:
        """Generate sales rep performance insights"""
        try:
            if sales_data.empty:
                return {"error": "No sales data available"}
            
            # Filter out records without sales rep
            sales_with_rep = sales_data[sales_data['SalesRep'].notna()]
            
            if sales_with_rep.empty:
                return {"error": "No sales rep data available"}
            
            # Sales rep analysis
            rep_analysis = sales_with_rep.groupby('SalesRep').agg({
                'SalesAmount': ['sum', 'count', 'mean'],
                'SalesQuantity': 'sum',
                'CustomerID': 'nunique',
                'Region': 'nunique'
            }).round(2)
            
            rep_analysis.columns = ['TotalSales', 'OrderCount', 'AvgOrderValue', 'TotalQuantity', 'UniqueCustomers', 'Regions']
            rep_analysis = rep_analysis.reset_index()
            
            # Top sales reps
            top_reps = rep_analysis.nlargest(5, 'TotalSales')[['SalesRep', 'TotalSales', 'OrderCount', 'UniqueCustomers', 'Regions']].to_dict('records')
            
            # Performance metrics
            total_reps = len(rep_analysis)
            avg_sales_per_rep = rep_analysis['TotalSales'].mean()
            top_rep = rep_analysis.loc[rep_analysis['TotalSales'].idxmax(), 'SalesRep']
            top_rep_sales = rep_analysis['TotalSales'].max()
            
            return {
                "total_sales_reps": total_reps,
                "top_sales_reps": top_reps,
                "average_sales_per_rep": float(avg_sales_per_rep),
                "top_performing_rep": top_rep,
                "top_rep_sales": float(top_rep_sales),
                "rep_performance_distribution": rep_analysis[['SalesRep', 'TotalSales']].to_dict('records')
            }
            
        except Exception as e:
            logger.error(f"Error generating sales rep insights: {str(e)}")
            return {"error": str(e)}

    def calculate_growth_rate(self, values: pd.Series) -> float:
        """Calculate growth rate for a series of values"""
        try:
            if len(values) < 2:
                return 0.0
            
            first_half = values[:len(values)//2].mean()
            second_half = values[len(values)//2:].mean()
            
            if first_half == 0:
                return 0.0
            
            return ((second_half - first_half) / first_half) * 100
        except Exception as e:
            logger.error(f"Error calculating growth rate: {str(e)}")
            return 0.0

    def save_insights(self, insights: Dict[str, Any]) -> bool:
        """Save insights to database"""
        try:
            connection_string = self.get_sql_connection_string()
            
            with pyodbc.connect(connection_string) as conn:
                cursor = conn.cursor()
                
                # Create insights table if it doesn't exist
                cursor.execute("""
                    IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='BusinessInsights' AND xtype='U')
                    CREATE TABLE BusinessInsights (
                        Id uniqueidentifier PRIMARY KEY DEFAULT NEWID(),
                        InsightType nvarchar(100) NOT NULL,
                        InsightData nvarchar(max) NOT NULL,
                        GeneratedDate datetime2 NOT NULL DEFAULT GETUTCDATE(),
                        IsActive bit NOT NULL DEFAULT 1
                    )
                """)
                
                # Insert insights
                for insight_type, insight_data in insights.items():
                    cursor.execute("""
                        INSERT INTO BusinessInsights (InsightType, InsightData)
                        VALUES (?, ?)
                    """, insight_type, str(insight_data))
                
                conn.commit()
                logger.info("Successfully saved insights to database")
                return True
                
        except Exception as e:
            logger.error(f"Error saving insights: {str(e)}")
            return False

    def generate_all_insights(self) -> str:
        """Generate all business insights"""
        try:
            logger.info("Starting insights generation...")
            
            # Get sales data for the last 30 days
            sales_data = self.get_sales_data(30)
            
            if sales_data.empty:
                return "No sales data available for insights generation"
            
            # Generate insights
            insights = {
                "sales_trends": self.generate_sales_trends(sales_data),
                "customer_insights": self.generate_customer_insights(sales_data),
                "product_insights": self.generate_product_insights(sales_data),
                "regional_insights": self.generate_regional_insights(sales_data),
                "sales_rep_insights": self.generate_sales_rep_insights(sales_data)
            }
            
            # Save insights
            if self.save_insights(insights):
                return f"Successfully generated and saved insights for {len(sales_data)} sales records"
            else:
                return "Generated insights but failed to save to database"
                
        except Exception as e:
            logger.error(f"Error generating insights: {str(e)}")
            return f"Error generating insights: {str(e)}"

def generate_insights() -> str:
    """Azure Function entry point for generating insights"""
    generator = InsightsGenerator()
    return generator.generate_all_insights()
