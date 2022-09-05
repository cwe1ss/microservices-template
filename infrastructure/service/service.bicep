// Contains the main entry point for deploying all Azure resources required by one service.

targetScope = 'subscription'

param now string = utcNow()
param environment string
param serviceName string
param buildNumber string


///////////////////////////////////
// Configuration

var config = loadJsonContent('./../config.json')
var envConfig = config.environments[environment]
var serviceDefaults = config.services[serviceName]

var tags = {
  product: config.platformResourcePrefix
  environment: envConfig.environmentResourcePrefix
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
var sqlGroupName = '${envConfig.environmentResourcePrefix}-sql'
var sqlServerAdminUserName = '${envConfig.environmentResourcePrefix}-sql-admin'
var sqlServerName = '${envConfig.environmentResourcePrefix}-sql'

// Environment: Container Apps
var envGroupName = '${envConfig.environmentResourcePrefix}-env'
var appInsightsName = '${envConfig.environmentResourcePrefix}-appinsights'
var appEnvName = '${envConfig.environmentResourcePrefix}-env'

// Service
var svcGroupName = '${envConfig.environmentResourcePrefix}-svc-${serviceName}'
var svcUserName = '${envConfig.environmentResourcePrefix}-${serviceName}'
var appName = take('${envConfig.environmentResourcePrefix}-${serviceName}', 32 /* max allowed length */)

// Service: SQL
var sqlDatabaseName = '${envConfig.environmentResourcePrefix}-${serviceName}'
var sqlDeployUserScriptName = '${sqlDatabaseName}-deploy-user'
var sqlDeployMigrationScriptName = '${sqlDatabaseName}-deploy-migration'
var sqlMigrationFile = '${config.platformResourcePrefix}-${serviceName}-${buildNumber}.sql'


///////////////////////////////////
// Existing resources

var platformGroup = resourceGroup(platformGroupName)
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

module svcAppGrpc 'service-app-grpc.bicep' = if (serviceDefaults.appType == 'grpc') {
  name: 'svc-app-grpc-${now}'
  scope: svcGroup
  dependsOn: [
    svcPlatform
    svcSql
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

module svcAppHttp 'service-app-http.bicep' = if (serviceDefaults.appType == 'http') {
  name: 'svc-app-http-${now}'
  scope: svcGroup
  dependsOn: [
    svcPlatform
    svcSql
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
