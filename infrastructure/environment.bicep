targetScope = 'subscription'

param now string = utcNow()
param environment string
param sqlAdminAdGroupName string
param sqlAdminAdGroupId string

// Configuration

var config = loadJsonContent('./_config.json')
var env = config.environments[environment]

// Naming conventions

var envGroupName = '${env.environmentResourcePrefix}-env'
var sqlGroupName = '${env.environmentResourcePrefix}-sql'

var tags = {
  product: config.platformResourcePrefix
  environment: env.environmentResourcePrefix
}

// New resources

resource envGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: envGroupName
  location: config.location
  tags: tags
}

module envResources 'environment-resources.bicep' = {
  name: 'envResources-${now}'
  scope: envGroup
  params: {
    environment: environment
    tags: tags
  }
}

resource sqlGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: sqlGroupName
  location: config.location
  tags: tags
}

module sqlResources 'environment-sql.bicep' = {
  name: 'sql-${now}'
  scope: sqlGroup
  dependsOn: [
    envResources
  ]
  params: {
    environment: environment
    tags: tags
    sqlAdminAdGroupId: sqlAdminAdGroupId
    sqlAdminAdGroupName: sqlAdminAdGroupName
  }
}
