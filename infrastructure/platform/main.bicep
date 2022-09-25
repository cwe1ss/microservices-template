targetScope = 'subscription'

param now string = utcNow()


///////////////////////////////////
// Configuration

var names = loadJsonContent('./../names.json')
var config = loadJsonContent('./../config.json')

var tags = {
  product: config.platformAbbreviation
}


///////////////////////////////////
// Resource names

var githubIdentityName = replace(names.githubIdentityName, '{platform}', config.platformAbbreviation)
var platformGroupName = replace(names.platformGroupName, '{platform}', config.platformAbbreviation)
var platformContainerRegistryName = replace(replace(names.platformContainerRegistryName, '{platform}', config.platformAbbreviation), '-', '')
var platformLogsName = replace(names.platformLogsName, '{platform}', config.platformAbbreviation)
var platformStorageAccountName = replace(names.platformStorageAccountName, '{platform}', config.platformAbbreviation)


///////////////////////////////////
// Existing resources

@description('The platform resource group - must be created by using the `init-platform.ps1`-script before an automated platform-deployment can be run.')
resource platformGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: platformGroupName
}


///////////////////////////////////
// New resources

module platformResources 'resources.bicep' = {
  name: 'platform-${now}'
  scope: platformGroup
  params: {
    location: config.location
    tags: tags

    // Resource names
    githubIdentityName: githubIdentityName
    platformContainerRegistryName: platformContainerRegistryName
    platformLogsName: platformLogsName
    platformStorageAccountName: platformStorageAccountName
    sqlMigrationContainerName: names.platformSqlMigrationStorageContainerName
  }
}
