// Key Vault module

@description('Resource prefix for naming')
param resourcePrefix string

@description('Location for resources')
param location string

@description('Tags to apply to resources')
param tags object

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: '${resourcePrefix}keyvault'
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: []
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enableRbacAuthorization: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

// Secret for SAP SFTP password
resource sapSftpPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'sap-sftp-password'
  properties: {
    value: 'TempPassword123!'
    contentType: 'text/plain'
  }
}

// Secret for OpenAI API key
resource openAiApiKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'openai-api-key'
  properties: {
    value: 'your-openai-api-key-here'
    contentType: 'text/plain'
  }
}

// Secret for SQL connection string
resource sqlConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'sql-connection-string'
  properties: {
    value: 'Server=${resourcePrefix}sqlserver.database.windows.net;Database=${resourcePrefix}processeddata;Authentication=Active Directory Default;'
    contentType: 'text/plain'
  }
}

// Secret for storage account key
resource storageAccountKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'storage-account-key'
  properties: {
    value: 'your-storage-account-key-here'
    contentType: 'text/plain'
  }
}

output keyVaultName string = keyVault.name
output keyVaultId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri
