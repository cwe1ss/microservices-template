// Contains the main entry point for deploying all Azure resources required by one service.

targetScope = 'subscription'

param now string = utcNow()
param environment string
param serviceName string
param buildNumber string


///////////////////////////////////
// Configuration

var config = loadJsonContent('./_config.json')
var env = config.environments[environment]
var serviceDefaults = config.services[serviceName]

var tags = {
  product: config.platformResourcePrefix
  environment: env.environmentResourcePrefix
  service: serviceName
}


///////////////////////////////////
// Resource names

// Platform
var platformGroupName = '${config.platformResourcePrefix}-platform'
var containerRegistryName = replace('${config.platformResourcePrefix}-registry', '-', '')
var storageAccountName = replace('${config.platformResourcePrefix}sa', '-', '')
var sqlMigrationContainerName = 'sql-migration'

// Environment: SQL
var sqlGroupName = '${env.environmentResourcePrefix}-sql'
var sqlServerAdminUserName = '${env.environmentResourcePrefix}-sql-admin'
var sqlServerName = '${env.environmentResourcePrefix}-sql'

// Environment: Container Apps
var envGroupName = '${env.environmentResourcePrefix}-env'
var appInsightsName = '${env.environmentResourcePrefix}-appinsights'
var appEnvName = '${env.environmentResourcePrefix}-env'

// Environment: Service Bus
var serviceBusGroupName = '${env.environmentResourcePrefix}-bus'
var serviceBusName = '${env.environmentResourcePrefix}-bus'

// Service
var svcGroupName = '${env.environmentResourcePrefix}-svc-${serviceName}'
var svcUserName = '${env.environmentResourcePrefix}-svc-${serviceName}'
var appName = '${env.environmentResourcePrefix}-svc-${serviceName}'

// Service: SQL
var sqlDatabaseName = '${env.environmentResourcePrefix}-sql-${serviceName}'
var sqlDeployUserScriptName = '${sqlDatabaseName}-deploy-user'
var sqlDeployMigrationScriptName = '${sqlDatabaseName}-deploy-migration'
var sqlMigrationFile = '${config.platformResourcePrefix}-svc-${serviceName}-${buildNumber}.sql'

// Service: Service Bus
var serviceBusIncomingQueueName = serviceName


///////////////////////////////////
// Existing resources

var platformGroup = resourceGroup(platformGroupName)
var envGroup = resourceGroup(envGroupName)
var serviceBusGroup = resourceGroup(serviceBusGroupName)
var sqlGroup = resourceGroup(sqlGroupName)


///////////////////////////////////
// New resources

resource svcGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: svcGroupName
  location: config.location
  tags: tags
}

// Create the user assigned identity first, so that we can assign permissions to it before the rest of the service resources is created
module svcIdentity 'service-identity.bicep' = {
  name: 'svc-identity-${now}'
  scope: svcGroup
  params: {
    location: config.location
    tags: tags

    // Resource names
    svcUserName: svcUserName
  }
}

// Allow the identity to access the platform container registry.
// This must be done before we can create the actual container app, as the deployment would fail otherwise.
module svcPlatform 'service-platform.bicep' = {
  name: 'svc-platform-${now}'
  scope: platformGroup
  dependsOn: [
    svcIdentity
  ]
  params: {
    // Resource names
    containerRegistryName: containerRegistryName
    svcGroupName: svcGroupName
    svcUserName: svcUserName
  }
}

module svcServiceBus 'service-servicebus.bicep' = if (serviceDefaults.serviceBusEnabled) {
  name: 'svc-bus-${now}'
  scope: serviceBusGroup
  dependsOn: [
    svcIdentity
  ]
  params: {
    // Resource names
    serviceBusName: serviceBusName
    svcGroupName: svcGroupName
    svcUserName: svcUserName
    serviceBusIncomingQueueName: serviceBusIncomingQueueName
  }
}

module svcSql 'service-sql.bicep' = if (serviceDefaults.sqlDatabaseEnabled) {
  name: 'svc-sql-${now}'
  scope: sqlGroup
  params: {
    location: config.location
    environment: environment
    serviceName: serviceName
    buildNumber: buildNumber
    tags: tags

    // Resource names
    platformGroupName: platformGroupName
    storageAccountName: storageAccountName
    sqlMigrationContainerName: sqlMigrationContainerName
    sqlMigrationFile: sqlMigrationFile
    sqlServerName: sqlServerName
    sqlServerAdminUserName: sqlServerAdminUserName
    sqlDatabaseName: sqlDatabaseName
    svcGroupName: svcGroupName
    svcUserName: svcUserName
    sqlDeployUserScriptName: sqlDeployUserScriptName
    sqlDeployMigrationScriptName: sqlDeployMigrationScriptName
  }
}

module svcEnv 'service-environment.bicep' = {
  name: 'svc-env-${now}'
  scope: envGroup
  dependsOn: [
    svcIdentity
    svcServiceBus
  ]
  params: {
    serviceName: serviceName

    // Resource names
    appEnvName: appEnvName
    serviceBusGroupName: serviceBusGroupName
    serviceBusName: serviceBusName
    svcGroupName: svcGroupName
    svcUserName: svcUserName
    serviceBusIncomingQueueName: serviceBusIncomingQueueName
  }
}

module svcResources 'service-resources.bicep' = {
  name: 'svc-resources-${now}'
  scope: svcGroup
  dependsOn: [
    svcPlatform
    svcServiceBus
    svcSql
    svcEnv
  ]
  params: {
    location: config.location
    environment: environment
    serviceName: serviceName
    buildNumber: buildNumber
    tags: tags

    // Resource names
    platformGroupName: platformGroupName
    containerRegistryName: containerRegistryName
    envGroupName: envGroupName
    appEnvName: appEnvName
    sqlGroupName: sqlGroupName
    sqlServerName: sqlServerName
    appInsightsName: appInsightsName
    svcUserName: svcUserName
    appName: appName
    sqlDatabaseName: sqlDatabaseName
  }
}
