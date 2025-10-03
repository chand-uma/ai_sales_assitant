"""
SAP Data Processing Module
Processes raw SAP data and creates aggregated insights
"""

import logging
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Any
import pyodbc
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
import os

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SapDataProcessor:
    def __init__(self):
        self.credential = DefaultAzureCredential()
        self.key_vault_url = os.environ.get('KEY_VAULT_URL')
        self.sql_connection_string = os.environ.get('SQL_CONNECTION_STRING')
        self.processed_sql_connection_string = os.environ.get('PROCESSED_SQL_CONNECTION_STRING')
        
        if self.key_vault_url:
            self.secret_client = SecretClient(
                vault_url=self.key_vault_url,
                credential=self.credential
            )
        else:
            self.secret_client = None

    def get_connection_string(self, use_processed_db: bool = False) -> str:
        """Get SQL connection string from environment or Key Vault"""
        if use_processed_db and self.processed_sql_connection_string:
            return self.processed_sql_connection_string
        elif self.sql_connection_string:
            return self.sql_connection_string
        elif self.secret_client:
            secret = self.secret_client.get_secret("sql-connection-string")
            return secret.value
        else:
            raise ValueError("No SQL connection string available")

    def get_raw_sap_ecc_data(self) -> pd.DataFrame:
        """Retrieve raw SAP ECC data from database"""
        try:
            connection_string = self.get_connection_string(use_processed_db=False)
            query = """
                SELECT 
                    CustomerID,
                    OrderNumber,
                    OrderDate,
                    ProductCode,
                    Quantity,
                    UnitPrice,
                    TotalAmount,
                    Status,
                    SalesRep,
                    Region,
                    ProcessedDate
                FROM SapEccRawData 
                WHERE IsActive = 1 
                AND IsDeleted = 0
                AND ProcessedDate >= DATEADD(day, -7, GETUTCDATE())
                ORDER BY ProcessedDate DESC
            """
            
            with pyodbc.connect(connection_string) as conn:
                df = pd.read_sql(query, conn)
            
            logger.info(f"Retrieved {len(df)} SAP ECC records")
            return df
            
        except Exception as e:
            logger.error(f"Error retrieving SAP ECC data: {str(e)}")
            raise

    def get_raw_sap_bw_data(self) -> pd.DataFrame:
        """Retrieve raw SAP BW data from database"""
        try:
            connection_string = self.get_connection_string(use_processed_db=False)
            query = """
                SELECT 
                    CustomerID,
                    ProductCode,
                    SalesAmount,
                    SalesQuantity,
                    SalesDate,
                    SalesRep,
                    Region,
                    Channel,
                    ProductCategory,
                    CustomerSegment,
                    ProcessedDate
                FROM SapBwRawData 
                WHERE IsActive = 1 
                AND IsDeleted = 0
                AND ProcessedDate >= DATEADD(day, -7, GETUTCDATE())
                ORDER BY ProcessedDate DESC
            """
            
            with pyodbc.connect(connection_string) as conn:
                df = pd.read_sql(query, conn)
            
            logger.info(f"Retrieved {len(df)} SAP BW records")
            return df
            
        except Exception as e:
            logger.error(f"Error retrieving SAP BW data: {str(e)}")
            raise

    def process_customer_data(self, ecc_data: pd.DataFrame, bw_data: pd.DataFrame) -> pd.DataFrame:
        """Process and aggregate customer data"""
        try:
            # Combine customer data from both sources
            customer_data = []
            
            # Process ECC data
            if not ecc_data.empty:
                ecc_customers = ecc_data.groupby('CustomerID').agg({
                    'OrderNumber': 'count',
                    'TotalAmount': 'sum',
                    'OrderDate': 'max',
                    'Region': 'first',
                    'SalesRep': 'first'
                }).reset_index()
                
                ecc_customers.columns = ['CustomerID', 'TotalOrders', 'TotalSalesAmount', 'LastOrderDate', 'Region', 'SalesRep']
                ecc_customers['DataSource'] = 'SAP_ECC'
                customer_data.append(ecc_customers)
            
            # Process BW data
            if not bw_data.empty:
                bw_customers = bw_data.groupby('CustomerID').agg({
                    'SalesAmount': 'sum',
                    'SalesQuantity': 'sum',
                    'SalesDate': 'max',
                    'Region': 'first',
                    'CustomerSegment': 'first',
                    'SalesRep': 'first'
                }).reset_index()
                
                bw_customers.columns = ['CustomerID', 'TotalSalesAmount', 'TotalQuantity', 'LastOrderDate', 'Region', 'CustomerSegment', 'SalesRep']
                bw_customers['TotalOrders'] = 0  # BW doesn't have order count
                bw_customers['DataSource'] = 'SAP_BW'
                customer_data.append(bw_customers)
            
            if customer_data:
                # Combine and aggregate
                combined_customers = pd.concat(customer_data, ignore_index=True)
                
                # Final aggregation
                final_customers = combined_customers.groupby('CustomerID').agg({
                    'TotalOrders': 'sum',
                    'TotalSalesAmount': 'sum',
                    'LastOrderDate': 'max',
                    'Region': 'first',
                    'SalesRep': 'first',
                    'CustomerSegment': 'first'
                }).reset_index()
                
                # Add metadata
                final_customers['CreatedDate'] = datetime.utcnow()
                final_customers['UpdatedDate'] = datetime.utcnow()
                final_customers['IsActive'] = True
                
                logger.info(f"Processed {len(final_customers)} unique customers")
                return final_customers
            else:
                return pd.DataFrame()
                
        except Exception as e:
            logger.error(f"Error processing customer data: {str(e)}")
            raise

    def process_product_data(self, ecc_data: pd.DataFrame, bw_data: pd.DataFrame) -> pd.DataFrame:
        """Process and aggregate product data"""
        try:
            product_data = []
            
            # Process ECC data
            if not ecc_data.empty:
                ecc_products = ecc_data.groupby('ProductCode').agg({
                    'Quantity': 'sum',
                    'TotalAmount': 'sum',
                    'UnitPrice': 'mean'
                }).reset_index()
                
                ecc_products.columns = ['ProductCode', 'TotalQuantitySold', 'TotalSalesAmount', 'UnitPrice']
                ecc_products['DataSource'] = 'SAP_ECC'
                product_data.append(ecc_products)
            
            # Process BW data
            if not bw_data.empty:
                bw_products = bw_data.groupby('ProductCode').agg({
                    'SalesQuantity': 'sum',
                    'SalesAmount': 'sum',
                    'ProductCategory': 'first'
                }).reset_index()
                
                bw_products.columns = ['ProductCode', 'TotalQuantitySold', 'TotalSalesAmount', 'ProductCategory']
                bw_products['UnitPrice'] = 0  # Calculate from amount/quantity if needed
                bw_products['DataSource'] = 'SAP_BW'
                product_data.append(bw_products)
            
            if product_data:
                # Combine and aggregate
                combined_products = pd.concat(product_data, ignore_index=True)
                
                # Final aggregation
                final_products = combined_products.groupby('ProductCode').agg({
                    'TotalQuantitySold': 'sum',
                    'TotalSalesAmount': 'sum',
                    'UnitPrice': 'mean',
                    'ProductCategory': 'first'
                }).reset_index()
                
                # Add metadata
                final_products['CreatedDate'] = datetime.utcnow()
                final_products['UpdatedDate'] = datetime.utcnow()
                final_products['IsActive'] = True
                
                logger.info(f"Processed {len(final_products)} unique products")
                return final_products
            else:
                return pd.DataFrame()
                
        except Exception as e:
            logger.error(f"Error processing product data: {str(e)}")
            raise

    def process_sales_data(self, ecc_data: pd.DataFrame, bw_data: pd.DataFrame) -> pd.DataFrame:
        """Process and combine sales data"""
        try:
            sales_data = []
            
            # Process ECC data
            if not ecc_data.empty:
                ecc_sales = ecc_data[['CustomerID', 'ProductCode', 'OrderNumber', 'OrderDate', 
                                    'TotalAmount', 'Quantity', 'UnitPrice', 'Region', 'SalesRep']].copy()
                ecc_sales.columns = ['CustomerID', 'ProductCode', 'OrderNumber', 'SalesDate', 
                                   'SalesAmount', 'SalesQuantity', 'UnitPrice', 'Region', 'SalesRep']
                ecc_sales['DataSource'] = 'SAP_ECC'
                ecc_sales['Channel'] = 'Direct'
                sales_data.append(ecc_sales)
            
            # Process BW data
            if not bw_data.empty:
                bw_sales = bw_data[['CustomerID', 'ProductCode', 'SalesDate', 'SalesAmount', 
                                  'SalesQuantity', 'Region', 'Channel', 'SalesRep']].copy()
                bw_sales['OrderNumber'] = None
                bw_sales['UnitPrice'] = bw_sales['SalesAmount'] / bw_sales['SalesQuantity']
                bw_sales['DataSource'] = 'SAP_BW'
                sales_data.append(bw_sales)
            
            if sales_data:
                combined_sales = pd.concat(sales_data, ignore_index=True)
                
                # Add metadata
                combined_sales['CreatedDate'] = datetime.utcnow()
                combined_sales['IsActive'] = True
                
                logger.info(f"Processed {len(combined_sales)} sales records")
                return combined_sales
            else:
                return pd.DataFrame()
                
        except Exception as e:
            logger.error(f"Error processing sales data: {str(e)}")
            raise

    def save_processed_data(self, customers_df: pd.DataFrame, products_df: pd.DataFrame, sales_df: pd.DataFrame):
        """Save processed data to the processed database"""
        try:
            connection_string = self.get_connection_string(use_processed_db=True)
            
            with pyodbc.connect(connection_string) as conn:
                cursor = conn.cursor()
                
                # Clear existing data (optional - you might want to keep historical data)
                # cursor.execute("DELETE FROM Sales WHERE CreatedDate >= DATEADD(day, -1, GETUTCDATE())")
                # cursor.execute("DELETE FROM Customers WHERE UpdatedDate >= DATEADD(day, -1, GETUTCDATE())")
                # cursor.execute("DELETE FROM Products WHERE UpdatedDate >= DATEADD(day, -1, GETUTCDATE())")
                
                # Save customers
                if not customers_df.empty:
                    self._save_customers(cursor, customers_df)
                
                # Save products
                if not products_df.empty:
                    self._save_products(cursor, products_df)
                
                # Save sales
                if not sales_df.empty:
                    self._save_sales(cursor, sales_df)
                
                conn.commit()
                logger.info("Successfully saved processed data")
                
        except Exception as e:
            logger.error(f"Error saving processed data: {str(e)}")
            raise

    def _save_customers(self, cursor, customers_df: pd.DataFrame):
        """Save customer data to database"""
        for _, row in customers_df.iterrows():
            cursor.execute("""
                MERGE Customers AS target
                USING (SELECT ? AS CustomerID, ? AS CustomerSegment, ? AS Region, ? AS SalesRep, 
                              ? AS TotalOrders, ? AS TotalSalesAmount, ? AS LastOrderDate) AS source
                ON target.CustomerID = source.CustomerID
                WHEN MATCHED THEN
                    UPDATE SET CustomerSegment = source.CustomerSegment,
                             Region = source.Region,
                             SalesRep = source.SalesRep,
                             TotalOrders = source.TotalOrders,
                             TotalSalesAmount = source.TotalSalesAmount,
                             LastOrderDate = source.LastOrderDate,
                             UpdatedDate = GETUTCDATE()
                WHEN NOT MATCHED THEN
                    INSERT (CustomerID, CustomerSegment, Region, SalesRep, TotalOrders, 
                           TotalSalesAmount, LastOrderDate, CreatedDate, UpdatedDate, IsActive)
                    VALUES (source.CustomerID, source.CustomerSegment, source.Region, 
                           source.SalesRep, source.TotalOrders, source.TotalSalesAmount, 
                           source.LastOrderDate, GETUTCDATE(), GETUTCDATE(), 1);
            """, row['CustomerID'], row.get('CustomerSegment'), row.get('Region'), 
                 row.get('SalesRep'), row['TotalOrders'], row['TotalSalesAmount'], 
                 row['LastOrderDate'])

    def _save_products(self, cursor, products_df: pd.DataFrame):
        """Save product data to database"""
        for _, row in products_df.iterrows():
            cursor.execute("""
                MERGE Products AS target
                USING (SELECT ? AS ProductCode, ? AS ProductCategory, ? AS UnitPrice,
                              ? AS TotalQuantitySold, ? AS TotalSalesAmount) AS source
                ON target.ProductCode = source.ProductCode
                WHEN MATCHED THEN
                    UPDATE SET ProductCategory = source.ProductCategory,
                             UnitPrice = source.UnitPrice,
                             TotalQuantitySold = source.TotalQuantitySold,
                             TotalSalesAmount = source.TotalSalesAmount,
                             UpdatedDate = GETUTCDATE()
                WHEN NOT MATCHED THEN
                    INSERT (ProductCode, ProductCategory, UnitPrice, TotalQuantitySold, 
                           TotalSalesAmount, CreatedDate, UpdatedDate, IsActive)
                    VALUES (source.ProductCode, source.ProductCategory, source.UnitPrice,
                           source.TotalQuantitySold, source.TotalSalesAmount, 
                           GETUTCDATE(), GETUTCDATE(), 1);
            """, row['ProductCode'], row.get('ProductCategory'), row.get('UnitPrice', 0),
                 row['TotalQuantitySold'], row['TotalSalesAmount'])

    def _save_sales(self, cursor, sales_df: pd.DataFrame):
        """Save sales data to database"""
        for _, row in sales_df.iterrows():
            cursor.execute("""
                INSERT INTO Sales (CustomerID, ProductCode, OrderNumber, SalesDate, 
                                 SalesAmount, SalesQuantity, UnitPrice, Region, Channel, 
                                 SalesRep, DataSource, CreatedDate, IsActive)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, GETUTCDATE(), 1)
            """, row['CustomerID'], row['ProductCode'], row.get('OrderNumber'), 
                 row['SalesDate'], row['SalesAmount'], row['SalesQuantity'], 
                 row.get('UnitPrice', 0), row.get('Region'), row.get('Channel'), 
                 row.get('SalesRep'), row['DataSource'])

def process_sap_data() -> str:
    """Main function to process SAP data"""
    try:
        processor = SapDataProcessor()
        
        # Get raw data
        logger.info("Retrieving raw SAP data...")
        ecc_data = processor.get_raw_sap_ecc_data()
        bw_data = processor.get_raw_sap_bw_data()
        
        # Process data
        logger.info("Processing customer data...")
        customers_df = processor.process_customer_data(ecc_data, bw_data)
        
        logger.info("Processing product data...")
        products_df = processor.process_product_data(ecc_data, bw_data)
        
        logger.info("Processing sales data...")
        sales_df = processor.process_sales_data(ecc_data, bw_data)
        
        # Save processed data
        logger.info("Saving processed data...")
        processor.save_processed_data(customers_df, products_df, sales_df)
        
        return f"Successfully processed {len(customers_df)} customers, {len(products_df)} products, and {len(sales_df)} sales records"
        
    except Exception as e:
        logger.error(f"Error in process_sap_data: {str(e)}")
        raise
