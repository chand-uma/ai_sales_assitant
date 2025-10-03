# RIA Setup Guide

This guide will walk you through setting up the Riddell Information Assistant (RIA) system.

## Prerequisites

### Required Software
- **Azure CLI** (latest version)
- **Node.js** (18.x or later)
- **Python** (3.9 or later)
- **PowerShell** (5.1 or later, or PowerShell Core 7.x)
- **Git** (for cloning the repository)

### Required Azure Resources
- Azure subscription with appropriate permissions
- Ability to create resource groups, storage accounts, SQL databases, etc.
- Access to Azure Key Vault
- Access to Azure AI Search
- Access to OpenAI API (or Azure OpenAI Service)

### Required External Services
- **SAP System** with SFTP export capability
- **Microsoft Teams** admin access for bot registration
- **OpenAI API Key** or Azure OpenAI Service endpoint

## Step 1: Clone the Repository

```bash
git clone <repository-url>
cd voltagrid
```

## Step 2: Configure Environment Variables

Create a `.env` file in the root directory with the following variables:

```env
# Azure Configuration
AZURE_SUBSCRIPTION_ID=your-subscription-id
AZURE_TENANT_ID=your-tenant-id
AZURE_CLIENT_ID=your-client-id
AZURE_CLIENT_SECRET=your-client-secret

# SAP Configuration
SAP_SFTP_SERVER=your-sap-sftp-server
SAP_SFTP_USERNAME=your-sap-username
SAP_SFTP_PASSWORD=your-sap-password

# OpenAI Configuration
OPENAI_ENDPOINT=your-openai-endpoint
OPENAI_API_KEY=your-openai-api-key

# Bot Configuration
BOT_APP_ID=your-bot-app-id
BOT_APP_PASSWORD=your-bot-app-password
TEAMS_APP_ID=your-teams-app-id
TEAMS_APP_PASSWORD=your-teams-app-password
```

## Step 3: Deploy Infrastructure

1. **Login to Azure**:
   ```bash
   az login
   ```

2. **Set the correct subscription**:
   ```bash
   az account set --subscription "your-subscription-id"
   ```

3. **Run the infrastructure deployment script**:
   ```powershell
   .\deployment\deploy-infrastructure.ps1 -ResourceGroupName "rg-ria-prod" -Location "East US" -Environment "prod"
   ```

   This will create:
   - Resource Group
   - Storage Account and Data Lake Storage
   - SQL Database
   - Key Vault
   - Virtual Network
   - Data Factory
   - AI Search Service
   - Bot Service
   - Function Apps
   - Application Insights

## Step 4: Configure Secrets in Key Vault

After infrastructure deployment, configure the following secrets in Azure Key Vault:

```bash
# SAP SFTP credentials
az keyvault secret set --vault-name "ria-prod-keyvault" --name "sap-sftp-password" --value "your-sap-password"

# OpenAI API key
az keyvault secret set --vault-name "ria-prod-keyvault" --name "openai-api-key" --value "your-openai-api-key"

# SQL connection string
az keyvault secret set --vault-name "ria-prod-keyvault" --name "sql-connection-string" --value "your-sql-connection-string"

# Storage account key
az keyvault secret set --vault-name "ria-prod-keyvault" --name "storage-account-key" --value "your-storage-account-key"
```

## Step 5: Deploy Bot Service

1. **Deploy the Teams bot**:
   ```powershell
   .\deployment\deploy-bot.ps1 -ResourceGroupName "rg-ria-prod" -Environment "prod"
   ```

2. **Register the bot with Microsoft Teams**:
   - Go to the Azure portal
   - Navigate to your Bot Service
   - Go to "Channels" and add "Microsoft Teams"
   - Follow the Teams registration process

## Step 6: Deploy Azure Functions

1. **Deploy the data processing functions**:
   ```powershell
   .\deployment\deploy-functions.ps1 -ResourceGroupName "rg-ria-prod" -Environment "prod"
   ```

## Step 7: Configure Data Factory Pipelines

1. **Go to Azure Data Factory** in the Azure portal
2. **Create linked services** for:
   - SAP SFTP connection
   - Azure Data Lake Storage
   - Azure SQL Database
3. **Import the pipeline definitions** from `data-pipeline/` directory
4. **Test the pipelines** to ensure they can connect to your SAP system

## Step 8: Configure SAP Data Export

Set up your SAP system to export data to the SFTP location:

1. **Create scheduled jobs** in SAP to export:
   - Customer data
   - Sales data
   - Product data
   - Order data

2. **Configure the export format** as CSV with the following structure:
   - Customer ID
   - Order Number
   - Product Code
   - Sales Amount
   - Sales Quantity
   - Sales Date
   - Region
   - Sales Rep

## Step 9: Test the System

1. **Test the bot** using the Bot Framework Emulator
2. **Test the data pipeline** by running a manual trigger
3. **Test the API endpoints** using Postman or curl
4. **Test the Teams integration** by adding the bot to a Teams channel

## Step 10: Monitor and Maintain

1. **Set up monitoring** in Application Insights
2. **Configure alerts** for errors and performance issues
3. **Schedule regular maintenance** tasks
4. **Monitor data quality** and processing times

## Troubleshooting

### Common Issues

1. **Bot not responding**:
   - Check bot service logs in Application Insights
   - Verify bot registration in Azure portal
   - Check Teams channel configuration

2. **Data pipeline failures**:
   - Check Data Factory pipeline runs
   - Verify SAP SFTP connection
   - Check SQL database connectivity

3. **API errors**:
   - Check Function App logs
   - Verify Key Vault access
   - Check database connection strings

### Getting Help

- Check the logs in Application Insights
- Review the Azure portal for error messages
- Check the GitHub issues for known problems
- Contact the development team for support

## Security Considerations

1. **Use managed identities** where possible
2. **Store secrets in Key Vault** and reference them
3. **Enable private endpoints** for sensitive services
4. **Use network security groups** to restrict access
5. **Enable audit logging** for compliance

## Cost Optimization

1. **Use appropriate SKUs** for your workload
2. **Schedule functions** to run only when needed
3. **Monitor usage** and adjust resources accordingly
4. **Use reserved instances** for predictable workloads
