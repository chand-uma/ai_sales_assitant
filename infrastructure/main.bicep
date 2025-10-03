// RIA Infrastructure - Main Bicep template
// Deploys all Azure resources for the RIA system

@description('The name of the resource group')
param resourceGroupName string = 'rg-ria-prod'

@description('The location for all resources')
param location string = resourceGroup().location

@description('Environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'prod'

@description('SAP SFTP server details')
param sapSftpServer string = ''
param sapSftpUsername string = ''
param sapSftpPassword string = ''

@description('OpenAI API details')
param openAiEndpoint string = ''
param openAiApiKey string = ''

// Variables
var resourcePrefix = 'ria-${environment}'
var tags = {
  Environment: environment
  Project: 'RIA'
  Owner: 'Riddell'
}

// Storage Account for Data Lake
module storage 'modules/storage.bicep' = {
  name: 'storage-${environment}'
  params: {
    resourcePrefix: resourcePrefix
    location: location
    tags: tags
  }
}

// SQL Database
module database 'modules/database.bicep' = {
  name: 'database-${environment}'
  params: {
    resourcePrefix: resourcePrefix
    location: location
    tags: tags
  }
}

// Key Vault
module keyVault 'modules/keyvault.bicep' = {
  name: 'keyvault-${environment}'
  params: {
    resourcePrefix: resourcePrefix
    location: location
    tags: tags
  }
}

// Virtual Network
module network 'modules/network.bicep' = {
  name: 'network-${environment}'
  params: {
    resourcePrefix: resourcePrefix
    location: location
    tags: tags
  }
}

// Data Factory
module dataFactory 'modules/datafactory.bicep' = {
  name: 'datafactory-${environment}'
  params: {
    resourcePrefix: resourcePrefix
    location: location
    tags: tags
    storageAccountName: storage.outputs.storageAccountName
    sqlServerName: database.outputs.sqlServerName
    keyVaultName: keyVault.outputs.keyVaultName
    sapSftpServer: sapSftpServer
    sapSftpUsername: sapSftpUsername
    sapSftpPassword: sapSftpPassword
  }
}

// AI Services
module aiServices 'modules/aiservices.bicep' = {
  name: 'aiservices-${environment}'
  params: {
    resourcePrefix: resourcePrefix
    location: location
    tags: tags
    keyVaultName: keyVault.outputs.keyVaultName
    openAiEndpoint: openAiEndpoint
    openAiApiKey: openAiApiKey
  }
}

// Bot Service
module botService 'modules/botservice.bicep' = {
  name: 'botservice-${environment}'
  params: {
    resourcePrefix: resourcePrefix
    location: location
    tags: tags
    keyVaultName: keyVault.outputs.keyVaultName
    sqlServerName: database.outputs.sqlServerName
    aiSearchName: aiServices.outputs.aiSearchName
    openAiEndpoint: openAiEndpoint
  }
}

// Function Apps
module functions 'modules/functions.bicep' = {
  name: 'functions-${environment}'
  params: {
    resourcePrefix: resourcePrefix
    location: location
    tags: tags
    keyVaultName: keyVault.outputs.keyVaultName
    sqlServerName: database.outputs.sqlServerName
    storageAccountName: storage.outputs.storageAccountName
  }
}

// Monitoring
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring-${environment}'
  params: {
    resourcePrefix: resourcePrefix
    location: location
    tags: tags
  }
}

// Outputs
output resourceGroupName string = resourceGroupName
output storageAccountName string = storage.outputs.storageAccountName
output sqlServerName string = database.outputs.sqlServerName
output keyVaultName string = keyVault.outputs.keyVaultName
output botServiceName string = botService.outputs.botServiceName
output aiSearchName string = aiServices.outputs.aiSearchName
