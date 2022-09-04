param location string = resourceGroup().location
param githubServicePrincipalId string
param tags object

// Configuration

var config = loadJsonContent('./_config.json')

// Naming conventions

var acrName = replace('${config.platformResourcePrefix}-registry', '-', '')
var logsName = '${config.platformResourcePrefix}-logs'

var storageAccountName = replace('${config.platformResourcePrefix}sa', '-', '')
var sqlMigrationContainerName = 'sql-migration'

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

resource sqlMigrationContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  name: '${storage.name}/default/${sqlMigrationContainerName}'
}

// Allows GitHub to upload artifacts to the storage account
resource saAccessForGitHub 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('githubStorageContributor', storage.id)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' /* Storage Blob Data Contributor */)
    principalId: githubServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
}

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
