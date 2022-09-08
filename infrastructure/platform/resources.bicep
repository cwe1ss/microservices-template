param location string
param githubServicePrincipalId string
param tags object


///////////////////////////////////
// Resource names

param containerRegistryName string
param logsName string
param storageAccountName string
param sqlMigrationContainerName string


///////////////////////////////////
// Existing resources

@description('This is the built-in Storage Blob Data Contributor role. See https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor ')
resource storageBlobDataContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}


///////////////////////////////////
// New resources

resource storage 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: storageAccountName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
  }
}

@description('A blob container that will be used to store any SQL migration scripts for all services')
resource sqlMigrationContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  name: '${storage.name}/default/${sqlMigrationContainerName}'
}

@description('Allows GitHub to upload artifacts to the storage account')
resource saAccessForGitHub 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('githubStorageContributor', storage.id, githubServicePrincipalId)
  scope: storage
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleDefinition.id
    principalId: githubServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

@description('The container registry will store all container images for all services')
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: containerRegistryName
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
resource logs 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logsName
  location: location
  tags: tags
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
}
