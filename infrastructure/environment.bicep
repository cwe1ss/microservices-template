// The main entry point for deploying all environment-specific infrastructure resources.

targetScope = 'subscription'

param now string = utcNow()
param environment string
param sqlAdminAdGroupName string
param sqlAdminAdGroupId string

// Configuration

var config = loadJsonContent('./_config.json')
var env = config.environments[environment]

// Naming conventions

var networkGroupName = '${env.environmentResourcePrefix}-network'
var envGroupName = '${env.environmentResourcePrefix}-env'
var serviceBusGroupName = '${env.environmentResourcePrefix}-bus'
var sqlGroupName = '${env.environmentResourcePrefix}-sql'

var tags = {
  product: config.platformResourcePrefix
  environment: env.environmentResourcePrefix
}

// New resources

resource networkGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: networkGroupName
  location: config.location
  tags: tags
}

resource serviceBusGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: serviceBusGroupName
  location: config.location
  tags: tags
}

resource envGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: envGroupName
  location: config.location
  tags: tags
}

resource sqlGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: sqlGroupName
  location: config.location
  tags: tags
}

module networkResources 'environment-network.bicep' = {
  name: 'env-network-${now}'
  scope: networkGroup
  params: {
    environment: environment
    tags: tags
  }
}

module sqlResources 'environment-sql.bicep' = {
  name: 'env-sql-${now}'
  scope: sqlGroup
  dependsOn: [
    networkResources
  ]
  params: {
    environment: environment
    tags: tags
    sqlAdminAdGroupId: sqlAdminAdGroupId
    sqlAdminAdGroupName: sqlAdminAdGroupName
  }
}

module serviceBusResources 'environment-servicebus.bicep' = {
  name: 'env-bus-${now}'
  scope: serviceBusGroup
  params: {
    environment: environment
    tags: tags
  }
}

module envResources 'environment-resources.bicep' = {
  name: 'env-${now}'
  scope: envGroup
  dependsOn: [
    networkResources
    sqlResources
    serviceBusResources
  ]
  params: {
    environment: environment
    tags: tags
  }
}
