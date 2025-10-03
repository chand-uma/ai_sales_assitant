// Azure Data Factory module

@description('Resource prefix for naming')
param resourcePrefix string

@description('Location for resources')
param location string

@description('Tags to apply to resources')
param tags object

@description('Storage account name')
param storageAccountName string

@description('SQL server name')
param sqlServerName string

@description('Key Vault name')
param keyVaultName string

@description('SAP SFTP server')
param sapSftpServer string

@description('SAP SFTP username')
param sapSftpUsername string

@description('SAP SFTP password')
param sapSftpPassword string

// Data Factory
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: '${resourcePrefix}datafactory'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Disabled'
    repoConfiguration: {
      type: 'FactoryVSTSConfiguration'
      accountName: 'your-devops-account'
      repositoryName: 'voltagrid'
      collaborationBranch: 'main'
      rootFolder: '/data-pipeline'
      projectName: 'RIA'
      tenantId: subscription().tenantId
    }
  }
}

// Linked Service for SFTP
resource sftpLinkedService 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  parent: dataFactory
  name: 'SftpLinkedService'
  properties: {
    type: 'Sftp'
    typeProperties: {
      host: sapSftpServer
      port: 22
      authenticationType: 'Basic'
      userName: sapSftpUsername
      password: {
        type: 'SecureString'
        value: sapSftpPassword
      }
      enableSsl: true
      enableServerCertificateValidation: true
    }
  }
}

// Linked Service for Azure Data Lake Storage
resource adlsLinkedService 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  parent: dataFactory
  name: 'AzureDataLakeStorageLinkedService'
  properties: {
    type: 'AzureBlobFS'
    typeProperties: {
      url: 'https://${resourcePrefix}datalake.dfs.core.windows.net'
      accountKey: {
        type: 'SecureString'
        value: 'your-storage-account-key'
      }
    }
  }
}

// Linked Service for Azure SQL Database
resource sqlLinkedService 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  parent: dataFactory
  name: 'AzureSqlLinkedService'
  properties: {
    type: 'AzureSqlDatabase'
    typeProperties: {
      connectionString: {
        type: 'SecureString'
        value: 'Server=tcp:${sqlServerName}.database.windows.net,1433;Initial Catalog=${resourcePrefix}rawdata;Persist Security Info=False;User ID=sqladmin;Password=TempPassword123!;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
      }
    }
  }
}

// Dataset for SAP ECC data
resource sapEccDataset 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  parent: dataFactory
  name: 'SapEccDataset'
  properties: {
    type: 'DelimitedText'
    linkedServiceName: {
      referenceName: 'SftpLinkedService'
      type: 'LinkedServiceReference'
    }
    typeProperties: {
      location: {
        type: 'SftpServerLocation'
        folderPath: '/sap/ecc'
        fileName: '*.csv'
      }
      columnDelimiter: ','
      rowDelimiter: '\n'
      encodingName: 'UTF-8'
      firstRowAsHeader: true
    }
  }
}

// Dataset for SAP BW data
resource sapBwDataset 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  parent: dataFactory
  name: 'SapBwDataset'
  properties: {
    type: 'DelimitedText'
    linkedServiceName: {
      referenceName: 'SftpLinkedService'
      type: 'LinkedServiceReference'
    }
    typeProperties: {
      location: {
        type: 'SftpServerLocation'
        folderPath: '/sap/bw'
        fileName: '*.csv'
      }
      columnDelimiter: ','
      rowDelimiter: '\n'
      encodingName: 'UTF-8'
      firstRowAsHeader: true
    }
  }
}

// Dataset for Azure Data Lake Storage
resource adlsDataset 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  parent: dataFactory
  name: 'AzureDataLakeStorageDataset'
  properties: {
    type: 'DelimitedText'
    linkedServiceName: {
      referenceName: 'AzureDataLakeStorageLinkedService'
      type: 'LinkedServiceReference'
    }
    typeProperties: {
      location: {
        type: 'AzureBlobFSLocation'
        fileSystem: 'raw-sap-data'
        fileName: '@{item().name}'
      }
      columnDelimiter: ','
      rowDelimiter: '\n'
      encodingName: 'UTF-8'
      firstRowAsHeader: true
    }
  }
}

// Dataset for SQL Database
resource sqlDataset 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  parent: dataFactory
  name: 'AzureSqlDataset'
  properties: {
    type: 'AzureSqlTable'
    linkedServiceName: {
      referenceName: 'AzureSqlLinkedService'
      type: 'LinkedServiceReference'
    }
    typeProperties: {
      tableName: 'SapData'
    }
  }
}

// Pipeline for SAP data ingestion
resource sapDataPipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  parent: dataFactory
  name: 'SapDataIngestionPipeline'
  properties: {
    activities: [
      {
        name: 'CopySapEccData'
        type: 'Copy'
        typeProperties: {
          source: {
            type: 'DelimitedTextSource'
            storeSettings: {
              type: 'SftpReadSettings'
              recursive: true
            }
          }
          sink: {
            type: 'DelimitedTextSink'
            storeSettings: {
              type: 'AzureBlobFSWriteSettings'
            }
          }
          enableStaging: false
        }
        inputs: [
          {
            referenceName: 'SapEccDataset'
            type: 'DatasetReference'
          }
        ]
        outputs: [
          {
            referenceName: 'AzureDataLakeStorageDataset'
            type: 'DatasetReference'
          }
        ]
      }
      {
        name: 'CopySapBwData'
        type: 'Copy'
        typeProperties: {
          source: {
            type: 'DelimitedTextSource'
            storeSettings: {
              type: 'SftpReadSettings'
              recursive: true
            }
          }
          sink: {
            type: 'DelimitedTextSink'
            storeSettings: {
              type: 'AzureBlobFSWriteSettings'
            }
          }
          enableStaging: false
        }
        inputs: [
          {
            referenceName: 'SapBwDataset'
            type: 'DatasetReference'
          }
        ]
        outputs: [
          {
            referenceName: 'AzureDataLakeStorageDataset'
            type: 'DatasetReference'
          }
        ]
      }
    ]
  }
}

output dataFactoryName string = dataFactory.name
output dataFactoryId string = dataFactory.id
