// AI Services module (AI Search, OpenAI, ML Studio)

@description('Resource prefix for naming')
param resourcePrefix string

@description('Location for resources')
param location string

@description('Tags to apply to resources')
param tags object

@description('Key Vault name')
param keyVaultName string

@description('OpenAI endpoint')
param openAiEndpoint string

@description('OpenAI API key')
param openAiApiKey string

// AI Search Service
resource aiSearch 'Microsoft.Search/searchServices@2023-11-01' = {
  name: '${resourcePrefix}aisearch'
  location: location
  tags: tags
  sku: {
    name: 'standard'
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    publicNetworkAccess: 'Disabled'
    networkRuleSet: {
      ipRules: []
    }
  }
}

// AI Search Index for SAP data
resource sapDataIndex 'Microsoft.Search/searchServices/indexes@2023-11-01' = {
  parent: aiSearch
  name: 'sap-data-index'
  properties: {
    fields: [
      {
        name: 'id'
        type: 'Edm.String'
        key: true
        searchable: false
        filterable: false
        sortable: false
        facetable: false
        retrievable: true
      }
      {
        name: 'title'
        type: 'Edm.String'
        key: false
        searchable: true
        filterable: false
        sortable: true
        facetable: false
        retrievable: true
      }
      {
        name: 'content'
        type: 'Edm.String'
        key: false
        searchable: true
        filterable: false
        sortable: false
        facetable: false
        retrievable: true
      }
      {
        name: 'category'
        type: 'Edm.String'
        key: false
        searchable: false
        filterable: true
        sortable: true
        facetable: true
        retrievable: true
      }
      {
        name: 'timestamp'
        type: 'Edm.DateTimeOffset'
        key: false
        searchable: false
        filterable: true
        sortable: true
        facetable: false
        retrievable: true
      }
      {
        name: 'metadata'
        type: 'Edm.String'
        key: false
        searchable: false
        filterable: true
        sortable: false
        facetable: false
        retrievable: true
      }
    ]
    scoringProfiles: []
    defaultScoringProfile: null
    corsOptions: {
      allowedOrigins: ['*']
      maxAgeInSeconds: 300
    }
  }
}

// AI Search Indexer
resource sapDataIndexer 'Microsoft.Search/searchServices/indexers@2023-11-01' = {
  parent: aiSearch
  name: 'sap-data-indexer'
  properties: {
    dataSourceName: 'sap-data-source'
    targetIndexName: 'sap-data-index'
    schedule: {
      interval: 'PT1H'
      startTime: '2024-01-01T00:00:00Z'
    }
    parameters: {
      batchSize: 1000
      maxFailedItems: 10
      maxFailedItemsPerBatch: 5
    }
  }
}

// AI Search Data Source
resource sapDataSource 'Microsoft.Search/searchServices/dataSources@2023-11-01' = {
  parent: aiSearch
  name: 'sap-data-source'
  properties: {
    type: 'azuresql'
    credentials: {
      connectionString: 'Server=tcp:${resourcePrefix}sqlserver.database.windows.net,1433;Initial Catalog=${resourcePrefix}processeddata;Authentication=Active Directory Default;'
    }
    container: {
      name: 'SapData'
      query: 'SELECT * FROM SapData WHERE IsActive = 1'
    }
    dataChangeDetectionPolicy: {
      type: 'SqlIntegratedChangeTrackingPolicy'
    }
    dataDeletionDetectionPolicy: {
      type: 'SoftDeleteColumnDeletionDetectionPolicy'
      softDeleteColumnName: 'IsDeleted'
      softDeleteMarkerValue: '1'
    }
  }
}

// Cognitive Services Account
resource cognitiveServices 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: '${resourcePrefix}cognitiveservices'
  location: location
  tags: tags
  sku: {
    name: 'S0'
  }
  kind: 'CognitiveServices'
  properties: {
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      virtualNetworkRules: []
      ipRules: []
    }
  }
}

// Machine Learning Workspace
resource mlWorkspace 'Microsoft.MachineLearningServices/workspaces@2023-06-01-preview' = {
  name: '${resourcePrefix}mlworkspace'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: 'RIA ML Workspace'
    description: 'Machine Learning workspace for RIA system'
    keyVault: '${keyVaultName}'
    storageAccount: '${resourcePrefix}storage'
    applicationInsights: '${resourcePrefix}appinsights'
    containerRegistry: '${resourcePrefix}acr'
    publicNetworkAccess: 'Disabled'
  }
}

// Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: '${resourcePrefix}acr'
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
  }
}

// Private Endpoint for AI Search
resource aiSearchPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: '${resourcePrefix}aisearch-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: '${resourcePrefix}vnet/subnets/default'
    }
    privateLinkServiceConnections: [
      {
        name: 'aisearch-connection'
        properties: {
          privateLinkServiceId: aiSearch.id
          groupIds: ['searchService']
        }
      }
    ]
  }
}

output aiSearchName string = aiSearch.name
output aiSearchId string = aiSearch.id
output cognitiveServicesName string = cognitiveServices.name
output mlWorkspaceName string = mlWorkspace.name
output containerRegistryName string = containerRegistry.name
