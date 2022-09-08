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

// Platform
var platformGroupName = '${config.platformResourcePrefix}-platform'
var logsName = '${config.platformResourcePrefix}-logs'

// Network
var networkGroupName = '${envConfig.environmentResourcePrefix}-network'
var vnetName = '${envConfig.environmentResourcePrefix}-vnet'
var appsSubnetName = 'apps'

// Monitoring
var monitoringGroupName = '${envConfig.environmentResourcePrefix}-monitoring'
var appInsightsName = '${envConfig.environmentResourcePrefix}-appinsights'
var dashboardName = '${envConfig.environmentResourcePrefix}-dashboard'

// SQL
var sqlGroupName = '${envConfig.environmentResourcePrefix}-sql'
var sqlServerAdminUserName = '${envConfig.environmentResourcePrefix}-sql-admin'
var sqlServerName = '${envConfig.environmentResourcePrefix}-sql'

// Service Bus
var serviceBusGroupName = '${envConfig.environmentResourcePrefix}-bus'
var serviceBusName = '${envConfig.environmentResourcePrefix}-bus'

// Container Apps Environment
var envGroupName = '${envConfig.environmentResourcePrefix}-env'
var appEnvName = '${envConfig.environmentResourcePrefix}-env'


///////////////////////////////////
// New resources

resource networkGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: networkGroupName
  location: config.location
  tags: tags
}

resource monitoringkGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: monitoringGroupName
  location: config.location
  tags: tags
}

resource serviceBusGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: serviceBusGroupName
  location: config.location
  tags: tags
}

resource appsGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: envGroupName
  location: config.location
  tags: tags
}

resource sqlGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: sqlGroupName
  location: config.location
  tags: tags
}

module networkResources 'network.bicep' = {
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

module monitoringResources 'monitoring.bicep' = {
  name: 'env-${now}'
  scope: monitoringkGroup
  params: {
    location: config.location
    environment: environment
    tags: tags

    // Resource names
    platformGroupName: platformGroupName
    logsName: logsName
    appInsightsName: appInsightsName
    dashboardName: dashboardName
  }
}


module sqlResources 'sql.bicep' = {
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

module serviceBusResources 'servicebus.bicep' = {
  name: 'env-bus-${now}'
  scope: serviceBusGroup
  params: {
    location: config.location
    tags: tags

    // Resource names
    serviceBusName: serviceBusName
  }
}

module appsResources 'app-environment.bicep' = {
  name: 'env-${now}'
  scope: appsGroup
  dependsOn: [
    networkResources
    monitoringResources
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
    monitoringGroupName: monitoringGroupName
    appInsightsName: appInsightsName
    appEnvName: appEnvName
  }
}
