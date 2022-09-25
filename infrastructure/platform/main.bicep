targetScope = 'subscription'

param now string = utcNow()
param deployGitHubIdentity bool
param githubRepoNameWithOwner string = ''
param githubDefaultBranchName string = ''


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
var platformStorageAccountName = toLower(replace(replace(names.platformStorageAccountName, '{platform}', config.platformAbbreviation), '-', ''))


///////////////////////////////////
// New resources

resource platformGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: platformGroupName
  location: config.location
  tags: tags
}

@description('The managed identity that will be used by GitHub to deploy Azure resources')
module githubIdentity 'github-identity.bicep' = if (deployGitHubIdentity) {
  name: 'platform-github-${now}'
  params: {
    tags: tags
    githubRepoNameWithOwner: githubRepoNameWithOwner
    githubDefaultBranchName: githubDefaultBranchName

    // Resource names
    githubIdentityName: githubIdentityName
    platformGroupName: platformGroup.name
  }
}

module platformResources 'resources.bicep' = {
  name: 'platform-${now}'
  scope: platformGroup
  dependsOn: [
    githubIdentity
  ]
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


output githubIdentityClientId string = deployGitHubIdentity ? githubIdentity.outputs.githubIdentityClientId : ''
output githubIdentityPrincipalId string = deployGitHubIdentity ? githubIdentity.outputs.githubIdentityPrincipalId : ''
output platformContainerRegistryUrl string = platformResources.outputs.platformContainerRegistryUrl
