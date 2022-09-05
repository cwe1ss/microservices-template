targetScope = 'subscription'

param now string = utcNow()
param githubServicePrincipalId string


///////////////////////////////////
// Configuration

var config = loadJsonContent('./_config.json')

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
// New resources

resource platformGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: platformGroupName
  location: config.location
  tags: tags
}

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
