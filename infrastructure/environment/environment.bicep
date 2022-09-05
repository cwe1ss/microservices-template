// The main entry point for deploying all environment-specific infrastructure resources.

targetScope = 'subscription'

param now string = utcNow()
param environment string
param sqlAdminAdGroupName string
param sqlAdminAdGroupId string


///////////////////////////////////
// Configuration

var config = loadJsonContent('./../config.json')
var envConfig = config.environments[environment]

var tags = {
  product: config.platformResourcePrefix
  environment: envConfig.environmentResourcePrefix
}


///////////////////////////////////
// Resource names

var platformGroupName = '${config.platformResourcePrefix}-platform'
var logsName = '${config.platformResourcePrefix}-logs'

var networkGroupName = '${envConfig.environmentResourcePrefix}-network'
var vnetName = '${envConfig.environmentResourcePrefix}-vnet'
var appsSubnetName = 'apps'

var sqlGroupName = '${envConfig.environmentResourcePrefix}-sql'
var sqlServerAdminUserName = '${envConfig.environmentResourcePrefix}-sql-admin'
var sqlServerName = '${envConfig.environmentResourcePrefix}-sql'

var envGroupName = '${envConfig.environmentResourcePrefix}-env'
var appInsightsName = '${envConfig.environmentResourcePrefix}-appinsights'
var appEnvName = '${envConfig.environmentResourcePrefix}-env'

var serviceBusGroupName = '${envConfig.environmentResourcePrefix}-bus'
var serviceBusName = '${envConfig.environmentResourcePrefix}-bus'


///////////////////////////////////
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
    location: config.location
    environment: environment
    tags: tags

    // Resource names
    vnetName: vnetName
    appsSubnetName: appsSubnetName
  }
}

module sqlResources 'environment-sql.bicep' = {
  name: 'env-sql-${now}'
  scope: sqlGroup
  dependsOn: [
    networkResources
  ]
  params: {
    location: config.location
    tags: tags
    sqlAdminAdGroupId: sqlAdminAdGroupId
    sqlAdminAdGroupName: sqlAdminAdGroupName

    // Resource names
    networkGroupName: networkGroupName
    vnetName: vnetName
    appsSubnetName: appsSubnetName
    sqlServerName: sqlServerName
    sqlServerAdminUserName: sqlServerAdminUserName
  }
}

module serviceBusResources 'environment-servicebus.bicep' = {
  name: 'env-bus-${now}'
  scope: serviceBusGroup
  params: {
    location: config.location
    tags: tags

    // Resource names
    serviceBusName: serviceBusName
  }
}

module envResources 'environment-resources.bicep' = {
  name: 'env-${now}'
  scope: envGroup
  dependsOn: [
    networkResources
    serviceBusResources
  ]
  params: {
    location: config.location
    tags: tags

    // Resource names
    platformGroupName: platformGroupName
    logsName: logsName
    networkGroupName: networkGroupName
    vnetName: vnetName
    appsSubnetName: appsSubnetName
    serviceBusGroupName: serviceBusGroupName
    serviceBusName: serviceBusName
    appInsightsName: appInsightsName
    appEnvName: appEnvName
  }
}
