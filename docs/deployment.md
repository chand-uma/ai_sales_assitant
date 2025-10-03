# RIA Deployment Guide

This guide provides step-by-step instructions for deploying the Riddell Information Assistant (RIA) system.

## Prerequisites

### Required Software
- **Azure CLI** (latest version)
- **Node.js** (18.x or later)
- **Python** (3.9 or later)
- **PowerShell** (5.1 or later, or PowerShell Core 7.x)
- **Azure Functions Core Tools** (v4)
- **Git** (for cloning the repository)

### Required Azure Resources
- Azure subscription with appropriate permissions
- Resource group creation permissions
- Key Vault access
- AI Search service creation permissions
- Bot Service registration permissions

### Required External Services
- **SAP System** with SFTP export capability
- **Microsoft Teams** admin access
- **OpenAI API Key** or Azure OpenAI Service

## Deployment Steps

### Step 1: Clone and Prepare

```bash
# Clone the repository
git clone <repository-url>
cd voltagrid

# Set up environment variables
cp .env.example .env
# Edit .env with your configuration
```

### Step 2: Infrastructure Deployment

1. **Login to Azure**:
   ```bash
   az login
   az account set --subscription "your-subscription-id"
   ```

2. **Deploy Infrastructure**:
   ```powershell
   .\deployment\deploy-infrastructure.ps1 -ResourceGroupName "rg-ria-prod" -Location "East US" -Environment "prod"
   ```

   This creates:
   - Resource Group
   - Storage Account and Data Lake Storage
   - SQL Database with tables
   - Key Vault for secrets
   - Virtual Network with security groups
   - Data Factory for SAP data ingestion
   - AI Search Service
   - Bot Service
   - Function Apps
   - Application Insights

### Step 3: Configure Secrets

After infrastructure deployment, configure secrets in Key Vault:

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

### Step 4: Deploy Bot Service

```powershell
.\deployment\deploy-bot.ps1 -ResourceGroupName "rg-ria-prod" -Environment "prod"
```

This deploys:
- Teams bot application
- Bot Framework configuration
- Semantic Kernel integration
- API endpoints for data access

### Step 5: Deploy Azure Functions

```powershell
.\deployment\deploy-functions.ps1 -ResourceGroupName "rg-ria-prod" -Environment "prod"
```

This deploys:
- Data processing functions
- API services functions
- AI Search indexing functions
- Business insights generation

### Step 6: Configure Data Factory

1. **Go to Azure Data Factory** in the Azure portal
2. **Create linked services**:
   - SAP SFTP connection
   - Azure Data Lake Storage
   - Azure SQL Database
3. **Import pipelines** from `data-pipeline/` directory
4. **Test connections** and run test pipelines

### Step 7: Configure SAP Data Export

Set up your SAP system to export data:

1. **Create scheduled jobs** in SAP:
   - Customer data export (daily)
   - Sales data export (daily)
   - Product data export (weekly)

2. **Configure export format**:
   - CSV format with headers
   - UTF-8 encoding
   - Specific field mappings

### Step 8: Register Bot with Teams

1. **Go to Azure Bot Service** in the Azure portal
2. **Add Microsoft Teams channel**
3. **Follow Teams registration process**
4. **Test bot in Teams**

### Step 9: Deploy ML Models

1. **Open Azure ML Studio**
2. **Upload the notebook** from `ml-models/sap-data-analysis.ipynb`
3. **Run the notebook** to train models
4. **Deploy models** to Azure Blob Storage

### Step 10: Configure Monitoring

1. **Set up Application Insights** dashboards
2. **Configure alert rules** for:
   - Bot service errors
   - Data processing failures
   - High resource usage
3. **Set up log analytics** queries

## Post-Deployment Configuration

### 1. Test the System

```bash
# Test bot health
curl https://ria-prod-bot.azurewebsites.net/health

# Test API endpoints
curl https://ria-prod-api-services.azurewebsites.net/api/health

# Test data processing
curl -X POST https://ria-prod-data-processing.azurewebsites.net/api/process-sap-data
```

### 2. Configure Teams Integration

1. **Add bot to Teams channels**
2. **Configure bot permissions**
3. **Test conversation flows**
4. **Train users on bot capabilities**

### 3. Set Up Data Pipeline

1. **Configure SAP export schedules**
2. **Test data ingestion**
3. **Verify data quality**
4. **Set up error handling**

### 4. Monitor Performance

1. **Check Application Insights** for errors
2. **Monitor resource usage** in Azure portal
3. **Review bot conversation logs**
4. **Analyze data processing metrics**

## Troubleshooting

### Common Issues

#### Bot Not Responding
- Check bot service logs in Application Insights
- Verify bot registration in Azure portal
- Check Teams channel configuration
- Verify Key Vault access

#### Data Pipeline Failures
- Check Data Factory pipeline runs
- Verify SAP SFTP connection
- Check SQL database connectivity
- Review error logs in Data Factory

#### API Errors
- Check Function App logs
- Verify Key Vault access
- Check database connection strings
- Review network security groups

#### Performance Issues
- Check resource utilization
- Review database query performance
- Analyze function execution times
- Check network latency

### Debugging Steps

1. **Check logs** in Application Insights
2. **Review Azure portal** for error messages
3. **Test individual components** separately
4. **Verify configuration** in Key Vault
5. **Check network connectivity**

### Getting Help

- Check the logs in Application Insights
- Review the Azure portal for error messages
- Check the GitHub issues for known problems
- Contact the development team for support

## Security Configuration

### 1. Network Security

- **Private Link** for all Azure services
- **Network Security Groups** for access control
- **Azure Firewall** for perimeter security
- **VPN/ExpressRoute** for on-premises connectivity

### 2. Identity and Access

- **Azure Active Directory** for authentication
- **Managed Identities** for service-to-service auth
- **Role-based access control** (RBAC)
- **Multi-factor authentication** for admin accounts

### 3. Data Protection

- **Encryption at rest** for all storage
- **Encryption in transit** for all communication
- **Key Vault** for secrets management
- **Audit logging** for compliance

## Cost Optimization

### 1. Resource Management

- **Right-size resources** based on usage
- **Use reserved instances** for predictable workloads
- **Implement auto-scaling** for variable workloads
- **Monitor costs** regularly

### 2. Storage Optimization

- **Use appropriate storage tiers**
- **Implement lifecycle policies**
- **Compress data** where possible
- **Archive old data**

### 3. Compute Optimization

- **Use Azure Functions** for serverless workloads
- **Implement caching** for frequently accessed data
- **Optimize database queries**
- **Use CDN** for static content

## Maintenance

### 1. Regular Tasks

- **Monitor system health** daily
- **Review logs** weekly
- **Update dependencies** monthly
- **Backup data** regularly

### 2. Updates

- **Keep Azure services** up to date
- **Update bot dependencies** regularly
- **Apply security patches** promptly
- **Test updates** in staging environment

### 3. Scaling

- **Monitor resource usage** trends
- **Plan for growth** in advance
- **Implement auto-scaling** policies
- **Review costs** regularly

## Disaster Recovery

### 1. Backup Strategy

- **Automated database backups**
- **Configuration backups** in version control
- **Cross-region replication** for critical data
- **Regular backup testing**

### 2. Recovery Procedures

- **Document recovery steps**
- **Test recovery procedures** regularly
- **Maintain runbooks** for common issues
- **Train support team** on procedures

### 3. Business Continuity

- **Define RTO/RPO** requirements
- **Implement failover** procedures
- **Maintain communication** plans
- **Regular disaster recovery** drills

## Support and Maintenance

### 1. Monitoring

- **24/7 monitoring** of critical components
- **Automated alerting** for issues
- **Regular health checks**
- **Performance monitoring**

### 2. Support

- **Tier 1 support** for basic issues
- **Tier 2 support** for complex issues
- **Escalation procedures** for critical issues
- **Regular support reviews**

### 3. Documentation

- **Keep documentation** up to date
- **Maintain runbooks** for common tasks
- **Document changes** and updates
- **Share knowledge** with team

## Conclusion

The RIA system is now deployed and ready for use. Follow the post-deployment configuration steps to ensure everything is working correctly, and refer to the troubleshooting section if you encounter any issues.

For ongoing maintenance and support, refer to the monitoring and maintenance sections of this guide.
