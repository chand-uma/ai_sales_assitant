"""
Data Query Module
Provides functions to query processed SAP data
"""

import logging
import json
import pandas as pd
import pyodbc
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
import os

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class DataQueryService:
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

    def get_connection_string(self) -> str:
        """Get SQL connection string from environment or Key Vault"""
        if self.sql_connection_string:
            return self.sql_connection_string
        elif self.secret_client:
            secret = self.secret_client.get_secret("sql-connection-string")
            return secret.value
        else:
            raise ValueError("No SQL connection string available")

    def get_customer_data(self, customer_id: str) -> Optional[Dict[str, Any]]:
        """Get detailed customer data by customer ID"""
        try:
            connection_string = self.get_connection_string()
            query = """
                SELECT 
                    c.CustomerID,
                    c.CustomerSegment,
                    c.Region,
                    c.SalesRep,
                    c.TotalOrders,
                    c.TotalSalesAmount,
                    c.LastOrderDate,
                    c.CreatedDate,
                    c.UpdatedDate
                FROM Customers c
                WHERE c.CustomerID = ? AND c.IsActive = 1
            """
            
            with pyodbc.connect(connection_string) as conn:
                cursor = conn.cursor()
                cursor.execute(query, customer_id)
                row = cursor.fetchone()
                
                if row:
                    return {
                        'customer_id': row[0],
                        'customer_segment': row[1],
                        'region': row[2],
                        'sales_rep': row[3],
                        'total_orders': row[4],
                        'total_sales_amount': float(row[5]) if row[5] else 0,
                        'last_order_date': row[6].isoformat() if row[6] else None,
                        'created_date': row[7].isoformat() if row[7] else None,
                        'updated_date': row[8].isoformat() if row[8] else None
                    }
                else:
                    return None
                    
        except Exception as e:
            logger.error(f"Error getting customer data: {str(e)}")
            raise

    def get_sales_data(self, start_date: Optional[str] = None, end_date: Optional[str] = None,
                      region: Optional[str] = None, customer_id: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get sales data with optional filters"""
        try:
            connection_string = self.get_connection_string()
            
            # Build dynamic query
            where_conditions = ["s.IsActive = 1"]
            params = []
            
            if start_date:
                where_conditions.append("s.SalesDate >= ?")
                params.append(start_date)
            
            if end_date:
                where_conditions.append("s.SalesDate <= ?")
                params.append(end_date)
            
            if region:
                where_conditions.append("s.Region = ?")
                params.append(region)
            
            if customer_id:
                where_conditions.append("s.CustomerID = ?")
                params.append(customer_id)
            
            where_clause = " AND ".join(where_conditions)
            
            query = f"""
                SELECT 
                    s.CustomerID,
                    s.ProductCode,
                    s.OrderNumber,
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
                WHERE {where_clause}
                ORDER BY s.SalesDate DESC
            """
            
            with pyodbc.connect(connection_string) as conn:
                df = pd.read_sql(query, conn, params=params)
                
                return df.to_dict('records')
                
        except Exception as e:
            logger.error(f"Error getting sales data: {str(e)}")
            raise

    def get_customer_orders(self, customer_id: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Get recent orders for a specific customer"""
        try:
            connection_string = self.get_connection_string()
            query = """
                SELECT 
                    s.OrderNumber,
                    s.SalesDate,
                    s.ProductCode,
                    s.SalesAmount,
                    s.SalesQuantity,
                    s.UnitPrice,
                    s.Region,
                    s.Channel,
                    s.SalesRep,
                    p.ProductCategory
                FROM Sales s
                LEFT JOIN Products p ON s.ProductCode = p.ProductCode
                WHERE s.CustomerID = ? AND s.IsActive = 1
                ORDER BY s.SalesDate DESC
                OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
            """
            
            with pyodbc.connect(connection_string) as conn:
                df = pd.read_sql(query, conn, params=[customer_id, limit])
                
                return df.to_dict('records')
                
        except Exception as e:
            logger.error(f"Error getting customer orders: {str(e)}")
            raise

    def get_product_performance(self, product_code: Optional[str] = None, 
                              start_date: Optional[str] = None, 
                              end_date: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get product performance data"""
        try:
            connection_string = self.get_connection_string()
            
            where_conditions = ["s.IsActive = 1"]
            params = []
            
            if product_code:
                where_conditions.append("s.ProductCode = ?")
                params.append(product_code)
            
            if start_date:
                where_conditions.append("s.SalesDate >= ?")
                params.append(start_date)
            
            if end_date:
                where_conditions.append("s.SalesDate <= ?")
                params.append(end_date)
            
            where_clause = " AND ".join(where_conditions)
            
            query = f"""
                SELECT 
                    s.ProductCode,
                    p.ProductCategory,
                    COUNT(*) as TotalSales,
                    SUM(s.SalesQuantity) as TotalQuantitySold,
                    SUM(s.SalesAmount) as TotalSalesAmount,
                    AVG(s.UnitPrice) as AverageUnitPrice,
                    MIN(s.SalesDate) as FirstSaleDate,
                    MAX(s.SalesDate) as LastSaleDate
                FROM Sales s
                LEFT JOIN Products p ON s.ProductCode = p.ProductCode
                WHERE {where_clause}
                GROUP BY s.ProductCode, p.ProductCategory
                ORDER BY TotalSalesAmount DESC
            """
            
            with pyodbc.connect(connection_string) as conn:
                df = pd.read_sql(query, conn, params=params)
                
                return df.to_dict('records')
                
        except Exception as e:
            logger.error(f"Error getting product performance: {str(e)}")
            raise

    def get_regional_sales(self, start_date: Optional[str] = None, 
                          end_date: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get sales data by region"""
        try:
            connection_string = self.get_connection_string()
            
            where_conditions = ["s.IsActive = 1"]
            params = []
            
            if start_date:
                where_conditions.append("s.SalesDate >= ?")
                params.append(start_date)
            
            if end_date:
                where_conditions.append("s.SalesDate <= ?")
                params.append(end_date)
            
            where_clause = " AND ".join(where_conditions)
            
            query = f"""
                SELECT 
                    s.Region,
                    COUNT(*) as TotalSales,
                    COUNT(DISTINCT s.CustomerID) as UniqueCustomers,
                    SUM(s.SalesQuantity) as TotalQuantitySold,
                    SUM(s.SalesAmount) as TotalSalesAmount,
                    AVG(s.SalesAmount) as AverageSaleAmount
                FROM Sales s
                WHERE {where_clause}
                GROUP BY s.Region
                ORDER BY TotalSalesAmount DESC
            """
            
            with pyodbc.connect(connection_string) as conn:
                df = pd.read_sql(query, conn, params=params)
                
                return df.to_dict('records')
                
        except Exception as e:
            logger.error(f"Error getting regional sales: {str(e)}")
            raise

    def get_sales_rep_performance(self, start_date: Optional[str] = None, 
                                 end_date: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get sales rep performance data"""
        try:
            connection_string = self.get_connection_string()
            
            where_conditions = ["s.IsActive = 1", "s.SalesRep IS NOT NULL"]
            params = []
            
            if start_date:
                where_conditions.append("s.SalesDate >= ?")
                params.append(start_date)
            
            if end_date:
                where_conditions.append("s.SalesDate <= ?")
                params.append(end_date)
            
            where_clause = " AND ".join(where_conditions)
            
            query = f"""
                SELECT 
                    s.SalesRep,
                    COUNT(*) as TotalSales,
                    COUNT(DISTINCT s.CustomerID) as UniqueCustomers,
                    SUM(s.SalesQuantity) as TotalQuantitySold,
                    SUM(s.SalesAmount) as TotalSalesAmount,
                    AVG(s.SalesAmount) as AverageSaleAmount
                FROM Sales s
                WHERE {where_clause}
                GROUP BY s.SalesRep
                ORDER BY TotalSalesAmount DESC
            """
            
            with pyodbc.connect(connection_string) as conn:
                df = pd.read_sql(query, conn, params=params)
                
                return df.to_dict('records')
                
        except Exception as e:
            logger.error(f"Error getting sales rep performance: {str(e)}")
            raise

    def get_top_customers(self, limit: int = 10, start_date: Optional[str] = None, 
                         end_date: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get top customers by sales amount"""
        try:
            connection_string = self.get_connection_string()
            
            where_conditions = ["s.IsActive = 1"]
            params = []
            
            if start_date:
                where_conditions.append("s.SalesDate >= ?")
                params.append(start_date)
            
            if end_date:
                where_conditions.append("s.SalesDate <= ?")
                params.append(end_date)
            
            where_clause = " AND ".join(where_conditions)
            
            query = f"""
                SELECT 
                    s.CustomerID,
                    c.CustomerSegment,
                    c.Region,
                    c.SalesRep,
                    COUNT(*) as TotalOrders,
                    SUM(s.SalesQuantity) as TotalQuantityPurchased,
                    SUM(s.SalesAmount) as TotalSalesAmount,
                    AVG(s.SalesAmount) as AverageOrderValue,
                    MAX(s.SalesDate) as LastOrderDate
                FROM Sales s
                LEFT JOIN Customers c ON s.CustomerID = c.CustomerID
                WHERE {where_clause}
                GROUP BY s.CustomerID, c.CustomerSegment, c.Region, c.SalesRep
                ORDER BY TotalSalesAmount DESC
                OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
            """
            
            params.append(limit)
            
            with pyodbc.connect(connection_string) as conn:
                df = pd.read_sql(query, conn, params=params)
                
                return df.to_dict('records')
                
        except Exception as e:
            logger.error(f"Error getting top customers: {str(e)}")
            raise

# Convenience functions for Azure Functions
def get_customer_data(customer_id: str) -> Optional[Dict[str, Any]]:
    """Get customer data by ID"""
    service = DataQueryService()
    return service.get_customer_data(customer_id)

def get_sales_data(start_date: Optional[str] = None, end_date: Optional[str] = None,
                  region: Optional[str] = None, customer_id: Optional[str] = None) -> str:
    """Get sales data as JSON string"""
    service = DataQueryService()
    data = service.get_sales_data(start_date, end_date, region, customer_id)
    return json.dumps(data, default=str)

def get_customer_orders(customer_id: str, limit: int = 50) -> str:
    """Get customer orders as JSON string"""
    service = DataQueryService()
    data = service.get_customer_orders(customer_id, limit)
    return json.dumps(data, default=str)

def get_product_performance(product_code: Optional[str] = None, 
                          start_date: Optional[str] = None, 
                          end_date: Optional[str] = None) -> str:
    """Get product performance as JSON string"""
    service = DataQueryService()
    data = service.get_product_performance(product_code, start_date, end_date)
    return json.dumps(data, default=str)

def get_regional_sales(start_date: Optional[str] = None, 
                      end_date: Optional[str] = None) -> str:
    """Get regional sales as JSON string"""
    service = DataQueryService()
    data = service.get_regional_sales(start_date, end_date)
    return json.dumps(data, default=str)

def get_sales_rep_performance(start_date: Optional[str] = None, 
                             end_date: Optional[str] = None) -> str:
    """Get sales rep performance as JSON string"""
    service = DataQueryService()
    data = service.get_sales_rep_performance(start_date, end_date)
    return json.dumps(data, default=str)

def get_top_customers(limit: int = 10, start_date: Optional[str] = None, 
                     end_date: Optional[str] = None) -> str:
    """Get top customers as JSON string"""
    service = DataQueryService()
    data = service.get_top_customers(limit, start_date, end_date)
    return json.dumps(data, default=str)
