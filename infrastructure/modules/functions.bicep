// Azure Functions module

@description('Resource prefix for naming')
param resourcePrefix string

@description('Location for resources')
param location string

@description('Tags to apply to resources')
param tags object

@description('Key Vault name')
param keyVaultName string

@description('SQL server name')
param sqlServerName string

@description('Storage account name')
param storageAccountName string

// App Service Plan for Functions
resource functionsAppServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: '${resourcePrefix}functions-plan'
  location: location
  tags: tags
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: false
  }
}

// Function App for Data Processing
resource dataProcessingFunction 'Microsoft.Web/sites@2023-01-01' = {
  name: '${resourcePrefix}data-processing'
  location: location
  tags: tags
  kind: 'functionapp'
  properties: {
    serverFarmId: functionsAppServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=core.windows.net;'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=core.windows.net;'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: '${resourcePrefix}data-processing'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'WEBSITE_PYTHON_DEFAULT_VERSION'
          value: '3.9'
        }
        {
          name: 'SQL_CONNECTION_STRING'
          value: 'Server=tcp:${sqlServerName}.database.windows.net,1433;Initial Catalog=${resourcePrefix}rawdata;Authentication=Active Directory Default;'
        }
        {
          name: 'PROCESSED_SQL_CONNECTION_STRING'
          value: 'Server=tcp:${sqlServerName}.database.windows.net,1433;Initial Catalog=${resourcePrefix}processeddata;Authentication=Active Directory Default;'
        }
        {
          name: 'STORAGE_ACCOUNT_NAME'
          value: storageAccountName
        }
        {
          name: 'KEY_VAULT_URL'
          value: 'https://${keyVaultName}.vault.azure.net/'
        }
        {
          name: 'PYTHONPATH'
          value: '/home/site/wwwroot'
        }
      ]
      alwaysOn: false
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      use32BitWorkerProcess: false
      webSocketsEnabled: true
      managedPipelineMode: 'Integrated'
      loadBalancing: 'LeastRequests'
      autoHealEnabled: false
      vnetRouteAllEnabled: false
      vnetPrivatePortsCount: 0
      publicNetworkAccess: 'Enabled'
      keyVaultReferenceIdentity: 'SystemAssigned'
      scmMinTlsVersion: '1.2'
      requestTracingEnabled: false
      remoteDebuggingEnabled: false
      useManagedIdentity: true
      logsDirectorySizeLimit: 35
      detailedErrorLoggingEnabled: false
      publishingUsername: '$${resourcePrefix}data-processing'
      appCommandLine: ''
      managedServiceIdentityId: 0
      virtualNetworkName: ''
      vnetRouteAllEnabled: false
      vnetPrivatePortsCount: 0
      siteLoadBalancing: 'LeastRequests'
      remoteDebuggingVersion: 'VS2019'
      useManagedIdentity: true
      keyVaultReferenceIdentity: 'SystemAssigned'
      publicNetworkAccess: 'Enabled'
    }
    httpsOnly: true
    redundancyMode: 'None'
    storageAccountRequired: false
    keyVaultReferenceIdentity: 'SystemAssigned'
    publicNetworkAccess: 'Enabled'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Function App for API Services
resource apiServicesFunction 'Microsoft.Web/sites@2023-01-01' = {
  name: '${resourcePrefix}api-services'
  location: location
  tags: tags
  kind: 'functionapp'
  properties: {
    serverFarmId: functionsAppServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=core.windows.net;'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=core.windows.net;'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: '${resourcePrefix}api-services'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~18'
        }
        {
          name: 'SQL_CONNECTION_STRING'
          value: 'Server=tcp:${sqlServerName}.database.windows.net,1433;Initial Catalog=${resourcePrefix}processeddata;Authentication=Active Directory Default;'
        }
        {
          name: 'AI_SEARCH_ENDPOINT'
          value: 'https://${resourcePrefix}aisearch.search.windows.net'
        }
        {
          name: 'AI_SEARCH_KEY'
          value: 'your-ai-search-key'
        }
        {
          name: 'OPENAI_ENDPOINT'
          value: 'your-openai-endpoint'
        }
        {
          name: 'OPENAI_API_KEY'
          value: 'your-openai-api-key'
        }
        {
          name: 'KEY_VAULT_URL'
          value: 'https://${keyVaultName}.vault.azure.net/'
        }
      ]
      alwaysOn: false
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      use32BitWorkerProcess: false
      webSocketsEnabled: true
      managedPipelineMode: 'Integrated'
      loadBalancing: 'LeastRequests'
      autoHealEnabled: false
      vnetRouteAllEnabled: false
      vnetPrivatePortsCount: 0
      publicNetworkAccess: 'Enabled'
      keyVaultReferenceIdentity: 'SystemAssigned'
      scmMinTlsVersion: '1.2'
      requestTracingEnabled: false
      remoteDebuggingEnabled: false
      useManagedIdentity: true
      logsDirectorySizeLimit: 35
      detailedErrorLoggingEnabled: false
      publishingUsername: '$${resourcePrefix}api-services'
      appCommandLine: ''
      managedServiceIdentityId: 0
      virtualNetworkName: ''
      vnetRouteAllEnabled: false
      vnetPrivatePortsCount: 0
      siteLoadBalancing: 'LeastRequests'
      remoteDebuggingVersion: 'VS2019'
      useManagedIdentity: true
      keyVaultReferenceIdentity: 'SystemAssigned'
      publicNetworkAccess: 'Enabled'
    }
    httpsOnly: true
    redundancyMode: 'None'
    storageAccountRequired: false
    keyVaultReferenceIdentity: 'SystemAssigned'
    publicNetworkAccess: 'Enabled'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

output dataProcessingFunctionName string = dataProcessingFunction.name
output apiServicesFunctionName string = apiServicesFunction.name
