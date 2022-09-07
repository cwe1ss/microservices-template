targetScope = 'subscription'

param now string = utcNow()
param githubServicePrincipalId string


///////////////////////////////////
// Configuration

var config = loadJsonContent('./../config.json')

var tags = {
  product: config.platformResourcePrefix
}


///////////////////////////////////
// Resource names

var platformGroupName = '${config.platformResourcePrefix}-platform'
var containerRegistryName = replace('${config.platformResourcePrefix}-registry', '-', '')
var logsName = '${config.platformResourcePrefix}-logs'
var storageAccountName = replace('${config.platformResourcePrefix}sa', '-', '')
var sqlMigrationContainerName = 'sql-migration'


///////////////////////////////////
// Existing resources

@description('The platform resource group - must be created by using the `init-platform.ps1`-script before an automated platform-deployment can be run.')
resource platformGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: platformGroupName
}


///////////////////////////////////
// New resources

module platformResources 'platform-resources.bicep' = {
  name: 'platform-${now}'
  scope: platformGroup
  params: {
    location: config.location
    githubServicePrincipalId: githubServicePrincipalId
    tags: tags

    // Resource names
    containerRegistryName: containerRegistryName
    logsName: logsName
    storageAccountName: storageAccountName
    sqlMigrationContainerName: sqlMigrationContainerName
  }
}
