// Storage Account and Data Lake Storage module

@description('Resource prefix for naming')
param resourcePrefix string

@description('Location for resources')
param location string

@description('Tags to apply to resources')
param tags object

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${resourcePrefix}storage'
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

// Data Lake Storage Gen2
resource dataLakeStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${resourcePrefix}datalake'
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    isHnsEnabled: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

// Container for raw SAP data
resource rawDataContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: dataLakeStorage::storageAccount::blobServices
  name: 'raw-sap-data'
  properties: {
    publicAccess: 'None'
  }
}

// Container for processed data
resource processedDataContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: dataLakeStorage::storageAccount::blobServices
  name: 'processed-data'
  properties: {
    publicAccess: 'None'
  }
}

// Container for ML models
resource mlModelsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: dataLakeStorage::storageAccount::blobServices
  name: 'ml-models'
  properties: {
    publicAccess: 'None'
  }
}

output storageAccountName string = storageAccount.name
output dataLakeStorageName string = dataLakeStorage.name
output storageAccountId string = storageAccount.id
output dataLakeStorageId string = dataLakeStorage.id
