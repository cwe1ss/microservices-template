// The main entry point for deploying all environment-specific infrastructure resources.

targetScope = 'subscription'

param now string = utcNow()
param environment string
param sqlAdminAdGroupId string


///////////////////////////////////
// Configuration

var names = loadJsonContent('./../names.json')
var config = loadJsonContent('./../config.json')
var envConfig = config.environments[environment]

var tags = {
  product: config.platformAbbreviation
  environment: envConfig.environmentAbbreviation
}


///////////////////////////////////
// Resource names

// Platform
var platformGroupName = replace(names.platformGroupName, '{platform}', config.platformAbbreviation)
var platformLogsName = replace(names.platformLogsName, '{platform}', config.platformAbbreviation)

// Environment: Network
var networkGroupName = replace(names.networkGroupName, '{environment}', envConfig.environmentAbbreviation)
var networkVnetName = replace(names.networkVnetName, '{environment}', envConfig.environmentAbbreviation)
var networkSubnetAppsName = replace(names.networkSubnetAppsName, '{environment}', envConfig.environmentAbbreviation)
var networkNsgAppsName = replace(names.networkNsgAppsName, '{environment}', envConfig.environmentAbbreviation)

// Environment: Monitoring
var monitoringGroupName = replace(names.monitoringGroupName, '{environment}', envConfig.environmentAbbreviation)
var monitoringAppInsightsName = replace(names.monitoringAppInsightsName, '{environment}', envConfig.environmentAbbreviation)
var monitoringDashboardName = replace(names.monitoringDashboardName, '{environment}', envConfig.environmentAbbreviation)

// Environment: SQL
var sqlGroupName = replace(names.sqlGroupName, '{environment}', envConfig.environmentAbbreviation)
var sqlServerAdminUserName = replace(names.sqlServerAdminName, '{environment}', envConfig.environmentAbbreviation)
var sqlServerName = replace(names.sqlServerName, '{environment}', envConfig.environmentAbbreviation)
var sqlAdminAdGroupName = replace(names.sqlAdminAdGroupName, '{environment}', envConfig.environmentAbbreviation)

// Environment: Service Bus
var serviceBusGroupName = replace(names.serviceBusGroupName, '{environment}', envConfig.environmentAbbreviation)
var serviceBusNamespaceName = replace(names.serviceBusNamespaceName, '{environment}', envConfig.environmentAbbreviation)

// Environment: Container Apps Environment
var appEnvironmentGroupName = replace(names.appEnvironmentGroupName, '{environment}', envConfig.environmentAbbreviation)
var appEnvironmentName = replace(names.appEnvironmentName, '{environment}', envConfig.environmentAbbreviation)


///////////////////////////////////
// New resources

resource networkGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: networkGroupName
  location: config.location
  tags: tags
}

resource monitoringGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: monitoringGroupName
  location: config.location
  tags: tags
}

resource serviceBusGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: serviceBusGroupName
  location: config.location
  tags: tags
}

resource appEnvGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: appEnvironmentGroupName
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
    platformGroupName: platformGroupName
    platformLogsName: platformLogsName
    diagnosticSettingsName: names.diagnosticSettingsName
    networkVnetName: networkVnetName
    networkSubnetAppsName: networkSubnetAppsName
    networkNsgAppsName: networkNsgAppsName
  }
}

module monitoringResources 'monitoring.bicep' = {
  name: 'env-${now}'
  scope: monitoringGroup
  params: {
    location: config.location
    environment: environment
    tags: tags

    // Resource names
    platformGroupName: platformGroupName
    platformLogsName: platformLogsName
    monitoringAppInsightsName: monitoringAppInsightsName
    monitoringDashboardName: monitoringDashboardName
    serviceBusGroupName: serviceBusGroupName
    serviceBusNamespaceName: serviceBusNamespaceName
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

    // Resource names
    networkGroupName: networkGroupName
    networkVnetName: networkVnetName
    networkSubnetAppsName: networkSubnetAppsName
    sqlServerName: sqlServerName
    sqlServerAdminUserName: sqlServerAdminUserName
    sqlAdminAdGroupName: sqlAdminAdGroupName
  }
}

module serviceBusResources 'servicebus.bicep' = {
  name: 'env-bus-${now}'
  scope: serviceBusGroup
  params: {
    location: config.location
    tags: tags

    // Resource names
    serviceBusNamespaceName: serviceBusNamespaceName
  }
}

module appsResources 'app-environment.bicep' = {
  name: 'env-${now}'
  scope: appEnvGroup
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
    platformLogsName: platformLogsName
    networkGroupName: networkGroupName
    networkVnetName: networkVnetName
    networkSubnetAppsName: networkSubnetAppsName
    serviceBusGroupName: serviceBusGroupName
    serviceBusNamespaceName: serviceBusNamespaceName
    monitoringGroupName: monitoringGroupName
    monitoringAppInsightsName: monitoringAppInsightsName
    appEnvName: appEnvironmentName
  }
}
