"""
Azure AI Search Index Update Module
Updates the AI Search index with processed SAP data
"""

import logging
import json
import pandas as pd
from datetime import datetime
from typing import Dict, List, Any, Optional
from azure.search.documents import SearchClient
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents.indexes.models import SearchIndex, SimpleField, SearchableField, ComplexField
from azure.core.credentials import AzureKeyCredential
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
import os

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class AISearchService:
    def __init__(self):
        self.credential = DefaultAzureCredential()
        self.key_vault_url = os.environ.get('KEY_VAULT_URL')
        self.ai_search_endpoint = os.environ.get('AI_SEARCH_ENDPOINT')
        self.ai_search_key = os.environ.get('AI_SEARCH_KEY')
        self.sql_connection_string = os.environ.get('SQL_CONNECTION_STRING')
        
        if self.key_vault_url:
            self.secret_client = SecretClient(
                vault_url=self.key_vault_url,
                credential=self.credential
            )
        else:
            self.secret_client = None

    def get_ai_search_credentials(self) -> tuple[str, str]:
        """Get AI Search endpoint and key from environment or Key Vault"""
        try:
            if self.ai_search_endpoint and self.ai_search_key:
                return self.ai_search_endpoint, self.ai_search_key
            
            if self.secret_client:
                endpoint_secret = self.secret_client.get_secret("ai-search-endpoint")
                key_secret = self.secret_client.get_secret("ai-search-key")
                return endpoint_secret.value, key_secret.value
            
            raise ValueError("No AI Search credentials available")
        except Exception as e:
            logger.error(f"Error getting AI Search credentials: {str(e)}")
            raise

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

    def create_search_index(self, index_name: str = "sap-data-index") -> bool:
        """Create or update the search index"""
        try:
            endpoint, key = self.get_ai_search_credentials()
            
            # Create search index client
            search_index_client = SearchIndexClient(
                endpoint=endpoint,
                credential=AzureKeyCredential(key)
            )
            
            # Define the search index
            index = SearchIndex(
                name=index_name,
                fields=[
                    SimpleField(name="id", type="Edm.String", key=True),
                    SearchableField(name="title", type="Edm.String"),
                    SearchableField(name="content", type="Edm.String"),
                    SimpleField(name="category", type="Edm.String", filterable=True, sortable=True, facetable=True),
                    SimpleField(name="timestamp", type="Edm.DateTimeOffset", filterable=True, sortable=True),
                    SimpleField(name="metadata", type="Edm.String", filterable=True),
                    SimpleField(name="customer_id", type="Edm.String", filterable=True),
                    SimpleField(name="product_code", type="Edm.String", filterable=True),
                    SimpleField(name="region", type="Edm.String", filterable=True, facetable=True),
                    SimpleField(name="sales_rep", type="Edm.String", filterable=True),
                    SimpleField(name="data_source", type="Edm.String", filterable=True),
                    SimpleField(name="sales_amount", type="Edm.Double", filterable=True, sortable=True),
                    SimpleField(name="sales_quantity", type="Edm.Double", filterable=True, sortable=True),
                    SimpleField(name="order_number", type="Edm.String", filterable=True),
                    SimpleField(name="sales_date", type="Edm.DateTimeOffset", filterable=True, sortable=True)
                ]
            )
            
            # Create or update the index
            search_index_client.create_or_update_index(index)
            logger.info(f"Successfully created/updated search index: {index_name}")
            return True
            
        except Exception as e:
            logger.error(f"Error creating search index: {str(e)}")
            return False

    def get_customer_documents(self) -> List[Dict[str, Any]]:
        """Get customer data and convert to search documents"""
        try:
            import pyodbc
            
            connection_string = self.get_sql_connection_string()
            query = """
                SELECT 
                    c.CustomerID as id,
                    CONCAT('Customer: ', c.CustomerID) as title,
                    CONCAT('Customer ID: ', c.CustomerID, 
                           CASE WHEN c.CustomerSegment IS NOT NULL THEN CONCAT(', Segment: ', c.CustomerSegment) ELSE '' END,
                           CASE WHEN c.Region IS NOT NULL THEN CONCAT(', Region: ', c.Region) ELSE '' END,
                           CASE WHEN c.SalesRep IS NOT NULL THEN CONCAT(', Sales Rep: ', c.SalesRep) ELSE '' END,
                           ', Total Orders: ', c.TotalOrders,
                           ', Total Sales: $', FORMAT(c.TotalSalesAmount, 'N2'),
                           CASE WHEN c.LastOrderDate IS NOT NULL THEN CONCAT(', Last Order: ', FORMAT(c.LastOrderDate, 'yyyy-MM-dd')) ELSE '' END
                    ) as content,
                    'Customer' as category,
                    c.UpdatedDate as timestamp,
                    CONCAT('CustomerID:', c.CustomerID, '|Segment:', ISNULL(c.CustomerSegment, ''), '|Region:', ISNULL(c.Region, ''), '|SalesRep:', ISNULL(c.SalesRep, '')) as metadata,
                    c.CustomerID as customer_id,
                    NULL as product_code,
                    c.Region as region,
                    c.SalesRep as sales_rep,
                    'Customer' as data_source,
                    c.TotalSalesAmount as sales_amount,
                    NULL as sales_quantity,
                    NULL as order_number,
                    c.LastOrderDate as sales_date
                FROM Customers c
                WHERE c.IsActive = 1
            """
            
            with pyodbc.connect(connection_string) as conn:
                df = pd.read_sql(query, conn)
                
            documents = df.to_dict('records')
            logger.info(f"Retrieved {len(documents)} customer documents")
            return documents
            
        except Exception as e:
            logger.error(f"Error getting customer documents: {str(e)}")
            return []

    def get_sales_documents(self) -> List[Dict[str, Any]]:
        """Get sales data and convert to search documents"""
        try:
            import pyodbc
            
            connection_string = self.get_sql_connection_string()
            query = """
                SELECT 
                    CONCAT(s.CustomerID, '-', s.ProductCode, '-', ISNULL(s.OrderNumber, 'NO-ORDER'), '-', FORMAT(s.SalesDate, 'yyyyMMdd')) as id,
                    CONCAT('Sale: ', s.CustomerID, ' - ', s.ProductCode, 
                           CASE WHEN s.OrderNumber IS NOT NULL THEN CONCAT(' (Order: ', s.OrderNumber, ')') ELSE '' END
                    ) as title,
                    CONCAT('Customer: ', s.CustomerID,
                           ', Product: ', s.ProductCode,
                           CASE WHEN s.OrderNumber IS NOT NULL THEN CONCAT(', Order: ', s.OrderNumber) ELSE '' END,
                           ', Date: ', FORMAT(s.SalesDate, 'yyyy-MM-dd'),
                           ', Amount: $', FORMAT(s.SalesAmount, 'N2'),
                           ', Quantity: ', s.SalesQuantity,
                           CASE WHEN s.Region IS NOT NULL THEN CONCAT(', Region: ', s.Region) ELSE '' END,
                           CASE WHEN s.SalesRep IS NOT NULL THEN CONCAT(', Sales Rep: ', s.SalesRep) ELSE '' END,
                           ', Source: ', s.DataSource
                    ) as content,
                    'Sales' as category,
                    s.CreatedDate as timestamp,
                    CONCAT('CustomerID:', s.CustomerID, '|ProductCode:', s.ProductCode, '|OrderNumber:', ISNULL(s.OrderNumber, ''), '|Region:', ISNULL(s.Region, ''), '|SalesRep:', ISNULL(s.SalesRep, ''), '|DataSource:', s.DataSource) as metadata,
                    s.CustomerID as customer_id,
                    s.ProductCode as product_code,
                    s.Region as region,
                    s.SalesRep as sales_rep,
                    s.DataSource as data_source,
                    s.SalesAmount as sales_amount,
                    s.SalesQuantity as sales_quantity,
                    s.OrderNumber as order_number,
                    s.SalesDate as sales_date
                FROM Sales s
                WHERE s.IsActive = 1
                AND s.CreatedDate >= DATEADD(day, -30, GETUTCDATE())
            """
            
            with pyodbc.connect(connection_string) as conn:
                df = pd.read_sql(query, conn)
                
            documents = df.to_dict('records')
            logger.info(f"Retrieved {len(documents)} sales documents")
            return documents
            
        except Exception as e:
            logger.error(f"Error getting sales documents: {str(e)}")
            return []

    def get_product_documents(self) -> List[Dict[str, Any]]:
        """Get product data and convert to search documents"""
        try:
            import pyodbc
            
            connection_string = self.get_sql_connection_string()
            query = """
                SELECT 
                    CONCAT('PROD-', p.ProductCode) as id,
                    CONCAT('Product: ', p.ProductCode) as title,
                    CONCAT('Product Code: ', p.ProductCode,
                           CASE WHEN p.ProductCategory IS NOT NULL THEN CONCAT(', Category: ', p.ProductCategory) ELSE '' END,
                           ', Total Quantity Sold: ', p.TotalQuantitySold,
                           ', Total Sales: $', FORMAT(p.TotalSalesAmount, 'N2'),
                           CASE WHEN p.UnitPrice IS NOT NULL THEN CONCAT(', Unit Price: $', FORMAT(p.UnitPrice, 'N2')) ELSE '' END
                    ) as content,
                    'Product' as category,
                    p.UpdatedDate as timestamp,
                    CONCAT('ProductCode:', p.ProductCode, '|Category:', ISNULL(p.ProductCategory, ''), '|UnitPrice:', ISNULL(CAST(p.UnitPrice AS VARCHAR), '')) as metadata,
                    NULL as customer_id,
                    p.ProductCode as product_code,
                    NULL as region,
                    NULL as sales_rep,
                    'Product' as data_source,
                    p.TotalSalesAmount as sales_amount,
                    p.TotalQuantitySold as sales_quantity,
                    NULL as order_number,
                    NULL as sales_date
                FROM Products p
                WHERE p.IsActive = 1
            """
            
            with pyodbc.connect(connection_string) as conn:
                df = pd.read_sql(query, conn)
                
            documents = df.to_dict('records')
            logger.info(f"Retrieved {len(documents)} product documents")
            return documents
            
        except Exception as e:
            logger.error(f"Error getting product documents: {str(e)}")
            return []

    def upload_documents(self, documents: List[Dict[str, Any]], index_name: str = "sap-data-index") -> bool:
        """Upload documents to the search index"""
        try:
            endpoint, key = self.get_ai_search_credentials()
            
            # Create search client
            search_client = SearchClient(
                endpoint=endpoint,
                index_name=index_name,
                credential=AzureKeyCredential(key)
            )
            
            # Upload documents in batches
            batch_size = 1000
            for i in range(0, len(documents), batch_size):
                batch = documents[i:i + batch_size]
                
                # Convert datetime objects to strings for JSON serialization
                for doc in batch:
                    for key, value in doc.items():
                        if isinstance(value, datetime):
                            doc[key] = value.isoformat()
                        elif pd.isna(value):
                            doc[key] = None
                
                # Upload batch
                result = search_client.upload_documents(batch)
                
                # Check for errors
                failed_docs = [doc for doc in result if not doc.succeeded]
                if failed_docs:
                    logger.warning(f"Failed to upload {len(failed_docs)} documents in batch {i//batch_size + 1}")
                    for doc in failed_docs:
                        logger.warning(f"Failed document: {doc.key}, Error: {doc.error_message}")
                
                logger.info(f"Uploaded batch {i//batch_size + 1} ({len(batch)} documents)")
            
            logger.info(f"Successfully uploaded {len(documents)} documents to index {index_name}")
            return True
            
        except Exception as e:
            logger.error(f"Error uploading documents: {str(e)}")
            return False

    def clear_index(self, index_name: str = "sap-data-index") -> bool:
        """Clear all documents from the search index"""
        try:
            endpoint, key = self.get_ai_search_credentials()
            
            # Create search client
            search_client = SearchClient(
                endpoint=endpoint,
                index_name=index_name,
                credential=AzureKeyCredential(key)
            )
            
            # Get all documents and delete them
            search_results = search_client.search("*", select=["id"])
            documents_to_delete = []
            
            for result in search_results:
                documents_to_delete.append({"id": result["id"]})
            
            if documents_to_delete:
                # Delete in batches
                batch_size = 1000
                for i in range(0, len(documents_to_delete), batch_size):
                    batch = documents_to_delete[i:i + batch_size]
                    search_client.delete_documents(batch)
                    logger.info(f"Deleted batch {i//batch_size + 1} ({len(batch)} documents)")
                
                logger.info(f"Successfully cleared {len(documents_to_delete)} documents from index")
            else:
                logger.info("Index is already empty")
            
            return True
            
        except Exception as e:
            logger.error(f"Error clearing index: {str(e)}")
            return False

    def update_search_index(self) -> str:
        """Main function to update the search index with latest data"""
        try:
            logger.info("Starting AI Search index update...")
            
            # Create or update the index
            if not self.create_search_index():
                return "Failed to create/update search index"
            
            # Clear existing documents
            if not self.clear_index():
                return "Failed to clear existing documents"
            
            # Get all documents
            all_documents = []
            
            # Get customer documents
            customer_docs = self.get_customer_documents()
            all_documents.extend(customer_docs)
            
            # Get sales documents
            sales_docs = self.get_sales_documents()
            all_documents.extend(sales_docs)
            
            # Get product documents
            product_docs = self.get_product_documents()
            all_documents.extend(product_docs)
            
            # Upload all documents
            if all_documents:
                if self.upload_documents(all_documents):
                    return f"Successfully updated search index with {len(all_documents)} documents"
                else:
                    return "Failed to upload documents to search index"
            else:
                return "No documents found to upload"
                
        except Exception as e:
            logger.error(f"Error updating search index: {str(e)}")
            return f"Error updating search index: {str(e)}"

def update_ai_search() -> str:
    """Azure Function entry point for updating AI Search index"""
    service = AISearchService()
    return service.update_search_index()
