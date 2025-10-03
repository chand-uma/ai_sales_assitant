# SIA (sales Information Assistant)

A secure, AI-powered digital assistant deployed via Microsoft Teams that integrates SAP data to provide intelligent business insights.

## Architecture Overview

The RIA system follows a comprehensive Azure-centric architecture with the following key components:

- **Data Ingestion**: SAP ECC/BW → SFTP → Azure Data Factory → ADLS/SQL Database
- **AI Processing**: Azure ML Studio, AI Search, OpenAI Models
- **Bot Interface**: Microsoft Teams Bot with Semantic Kernel
- **Security**: Private Link, Key Vault, Virtual Networks

## Project Structure

```
voltagrid/
├── infrastructure/          # Azure infrastructure as code
├── data-pipeline/          # Data Factory and processing
├── ml-models/             # Azure ML Studio notebooks and models
├── bot-service/           # Teams bot application
├── api-services/          # Azure Functions and APIs
├── search-service/        # Azure AI Search configuration
├── monitoring/            # Application Insights and monitoring
└── deployment/            # CI/CD and deployment scripts
```

## Quick Start

1. **Prerequisites**
   - Azure subscription with appropriate permissions
   - SAP system access for data export
   - Microsoft Teams admin access
   - Python 3.8+ and Node.js 16+

2. **Deploy Infrastructure**
   ```bash
   cd infrastructure
   az deployment group create --resource-group <your-rg> --template-file main.bicep
   ```

3. **Configure Data Pipeline**
   ```bash
   cd data-pipeline
   # Configure SAP connection and ADF pipelines
   ```

4. **Deploy Bot Service**
   ```bash
   cd bot-service
   npm install
   npm run build
   npm run deploy
   ```

## Key Features

- **SAP Data Integration**: Automated data ingestion from SAP ECC and BW
- **AI-Powered Insights**: Natural language queries with OpenAI integration
- **Teams Native**: Seamless integration with Microsoft Teams
- **Secure Architecture**: Private Link and enterprise security
- **Real-time Processing**: Azure Functions for dynamic data processing

## Documentation

- [Setup Guide](docs/setup.md)
- [Architecture Details](docs/architecture.md)
- [API Reference](docs/api.md)
- [Deployment Guide](docs/deployment.md)
"# ai_sales_assistant" 
