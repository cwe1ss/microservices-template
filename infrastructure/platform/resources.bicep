param location string
param tags object


///////////////////////////////////
// Resource names

param githubIdentityName string
param platformContainerRegistryName string
param platformLogsName string
param platformStorageAccountName string
param sqlMigrationContainerName string


///////////////////////////////////
// Existing resources

resource githubIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: githubIdentityName
}

@description('This is the built-in Storage Blob Data Contributor role. See https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor ')
resource storageBlobDataContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}


///////////////////////////////////
// New resources

resource platformStorageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: platformStorageAccountName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_ZRS'
  }
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
  }

  resource blobServices 'blobServices' = {
    name: 'default'
    properties: {
      deleteRetentionPolicy: {
        enabled: true
        allowPermanentDelete: true
        days: 7
      }
    }
  }
}

@description('A blob container that will be used to store any SQL migration scripts for all services')
resource sqlMigrationContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  name: '${platformStorageAccount.name}/default/${sqlMigrationContainerName}'
}

@description('Allows GitHub to upload artifacts to the storage account')
resource saAccessForGitHub 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('githubStorageContributor', platformStorageAccount.id, githubIdentity.id)
  scope: platformStorageAccount
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleDefinition.id
    principalId: githubIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('The container registry will store all container images for all services')
resource platformContainerRegistry 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: platformContainerRegistryName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
}

@description('One global log analytics workspace is used to simplify the operations and querying')
resource platformLogs 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: platformLogsName
  location: location
  tags: tags
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
}

output platformContainerRegistryUrl string = platformContainerRegistry.properties.loginServer
