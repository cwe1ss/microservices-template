targetScope = 'subscription'

param now string = utcNow()
param githubServicePrincipalId string

// Configuration

var config = loadJsonContent('./_config.json')

// Naming conventions

var platformGroupName = '${config.platformResourcePrefix}-platform'

var tags = {
  product: config.platformResourcePrefix
}

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
  }
}
