// Bot Service module

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

@description('AI Search name')
param aiSearchName string

@description('OpenAI endpoint')
param openAiEndpoint string

// Bot Service
resource botService 'Microsoft.BotService/botServices@2022-09-15' = {
  name: '${resourcePrefix}bot'
  location: 'global'
  tags: tags
  sku: {
    name: 'S1'
  }
  kind: 'sdk'
  properties: {
    displayName: 'RIA Bot'
    description: 'Riddell Information Assistant Bot'
    iconUrl: 'https://via.placeholder.com/150'
    endpoint: 'https://${resourcePrefix}bot.azurewebsites.net/api/messages'
    msaAppId: 'your-msa-app-id'
    msaAppPassword: 'your-msa-app-password'
    developerAppInsightsKey: 'your-app-insights-key'
    developerAppInsightsApplicationId: 'your-app-insights-app-id'
    developerAppInsightsApiKey: 'your-app-insights-api-key'
    isStreamingSupported: true
    disableLocalAuth: false
    schemaVersion: '2.1'
    storageResourceId: '${resourcePrefix}storage'
    publicNetworkAccess: 'Enabled'
  }
}

// App Service Plan for Bot
resource botAppServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: '${resourcePrefix}bot-plan'
  location: location
  tags: tags
  sku: {
    name: 'S1'
    tier: 'Standard'
  }
  properties: {
    reserved: false
  }
}

// App Service for Bot
resource botAppService 'Microsoft.Web/sites@2023-01-01' = {
  name: '${resourcePrefix}bot'
  location: location
  tags: tags
  kind: 'app'
  properties: {
    serverFarmId: botAppServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${resourcePrefix}storage;EndpointSuffix=core.windows.net;'
        }
        {
          name: 'BOT_ID'
          value: '${resourcePrefix}bot'
        }
        {
          name: 'BOT_PASSWORD'
          value: 'your-bot-password'
        }
        {
          name: 'SQL_CONNECTION_STRING'
          value: 'Server=tcp:${sqlServerName}.database.windows.net,1433;Initial Catalog=${resourcePrefix}processeddata;Authentication=Active Directory Default;'
        }
        {
          name: 'AI_SEARCH_ENDPOINT'
          value: 'https://${aiSearchName}.search.windows.net'
        }
        {
          name: 'AI_SEARCH_KEY'
          value: 'your-ai-search-key'
        }
        {
          name: 'OPENAI_ENDPOINT'
          value: openAiEndpoint
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
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      use32BitWorkerProcess: false
      webSocketsEnabled: true
      managedPipelineMode: 'Integrated'
      virtualApplications: [
        {
          virtualPath: '/'
          physicalPath: 'site\\wwwroot'
          preloadEnabled: true
        }
      ]
      loadBalancing: 'LeastRequests'
      experiments: {
        rampUpRules: []
      }
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
      publishingUsername: '$${resourcePrefix}bot'
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

// Function App for Bot Logic
resource botFunctionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: '${resourcePrefix}bot-functions'
  location: location
  tags: tags
  kind: 'functionapp'
  properties: {
    serverFarmId: botAppServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${resourcePrefix}storage;EndpointSuffix=core.windows.net;'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${resourcePrefix}storage;EndpointSuffix=core.windows.net;'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: '${resourcePrefix}bot-functions'
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
          value: 'https://${aiSearchName}.search.windows.net'
        }
        {
          name: 'AI_SEARCH_KEY'
          value: 'your-ai-search-key'
        }
        {
          name: 'OPENAI_ENDPOINT'
          value: openAiEndpoint
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
      alwaysOn: true
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
      publishingUsername: '$${resourcePrefix}bot-functions'
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

output botServiceName string = botService.name
output botServiceId string = botService.id
output botAppServiceName string = botAppService.name
output botFunctionAppName string = botFunctionApp.name
