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

// Environment: Network
var networkGroupName = '${envConfig.environmentResourcePrefix}-network'
var vnetName = '${envConfig.environmentResourcePrefix}-vnet'
var appsSubnetName = 'apps'

// Environment: Monitoring
var monitoringGroupName = '${envConfig.environmentResourcePrefix}-monitoring'
var appInsightsName = '${envConfig.environmentResourcePrefix}-appinsights'

// Environment: SQL
var sqlGroupName = '${envConfig.environmentResourcePrefix}-sql'
var sqlServerAdminUserName = '${envConfig.environmentResourcePrefix}-sql-admin'
var sqlServerName = '${envConfig.environmentResourcePrefix}-sql'

// Environment: Service Bus
// var serviceBusGroupName = '${envConfig.environmentResourcePrefix}-bus'
// var serviceBusName = '${envConfig.environmentResourcePrefix}-bus'

// Environment: Container Apps
var envGroupName = '${envConfig.environmentResourcePrefix}-env'
var appEnvName = '${envConfig.environmentResourcePrefix}-env'

// Service
var svcGroupName = '${envConfig.environmentResourcePrefix}-svc-${serviceName}'
var svcUserName = '${envConfig.environmentResourcePrefix}-${serviceName}'
var appName = take('${envConfig.environmentResourcePrefix}-${serviceName}', 32 /* max allowed length */)

// Service: Storage
var svcStorageAccountName = take(replace('${envConfig.environmentResourcePrefix}-${serviceName}', '-', ''), 24 /* max allowed length */)
var svcStorageDataProtectionContainerName = 'data-protection'

// Service: Key Vault
var svcVaultName = take(replace('${envConfig.environmentResourcePrefix}-${serviceName}', '-', ''), 24 /* max allowed length */)
var svcVaultDataProtectionKeyName = 'data-protection'

// Service: SQL
var sqlDatabaseName = '${envConfig.environmentResourcePrefix}-${serviceName}'
var sqlDeployUserScriptName = '${sqlDatabaseName}-deploy-user'
var sqlDeployMigrationScriptName = '${sqlDatabaseName}-deploy-migration'
var sqlMigrationFile = '${config.platformResourcePrefix}-${serviceName}-${buildNumber}.sql'


///////////////////////////////////
// Existing resources

var platformGroup = resourceGroup(platformGroupName)
var sqlGroup = resourceGroup(sqlGroupName)
//var serviceBusGroup = resourceGroup(serviceBusGroupName)


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
module svcPlatform 'platform.bicep' = {
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

module svcStorage 'storage.bicep' = {
  name: 'svc-storage-${now}'
  scope: svcGroup
  dependsOn: [
    svcIdentity
  ]
  params: {
    location: config.location
    tags: tags

    // Resource names
    networkGroupName: networkGroupName
    vnetName: vnetName
    appsSubnetName: appsSubnetName
    svcGroupName: svcGroupName
    svcUserName: svcUserName
    svcStorageAccountName: svcStorageAccountName
    svcStorageDataProtectionContainerName: svcStorageDataProtectionContainerName
  }
}

module svcVault 'keyvault.bicep' = {
  name: 'svc-vault-${now}'
  scope: svcGroup
  dependsOn: [
    svcIdentity
  ]
  params: {
    location: config.location
    tags: tags

    // Resource names
    networkGroupName: networkGroupName
    vnetName: vnetName
    appsSubnetName: appsSubnetName
    svcGroupName: svcGroupName
    svcUserName: svcUserName
    svcVaultName: svcVaultName
    svcVaultDataProtectionKeyName: svcVaultDataProtectionKeyName
  }
}

var sqlDatabaseEnabled = contains(serviceDefaults, 'sqlDatabaseEnabled') ? serviceDefaults.sqlDatabaseEnabled : false

module svcSql 'sql.bicep' = if (sqlDatabaseEnabled) {
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

// module svcServiceBus 'servicebus.bicep' = if (serviceDefaults.serviceBus.enabled) {
//   name: 'svc-bus-${now}'
//   scope: serviceBusGroup
//   params: {
//     location: config.location
//     environment: environment
//     serviceName: serviceName

//     // Resource names
//     serviceBusGroupName: serviceBusGroupName
//     serviceBusName: serviceBusName
//   }
// }

module svcAppGrpc 'app-grpc.bicep' = if (serviceDefaults.appType == 'grpc') {
  name: 'svc-app-grpc-${now}'
  scope: svcGroup
  dependsOn: [
    svcPlatform
    svcVault
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
    monitoringGroupName: monitoringGroupName
    appInsightsName: appInsightsName
    svcUserName: svcUserName
    appName: appName
    sqlDatabaseName: sqlDatabaseName
  }
}

module svcAppHttp 'app-http.bicep' = if (serviceDefaults.appType == 'http') {
  name: 'svc-app-http-${now}'
  scope: svcGroup
  dependsOn: [
    svcPlatform
    svcVault
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
    monitoringGroupName: monitoringGroupName
    appInsightsName: appInsightsName
    svcUserName: svcUserName
    appName: appName
    sqlDatabaseName: sqlDatabaseName
  }
}

module svcAppPublic 'app-public.bicep' = if (serviceDefaults.appType == 'public') {
  name: 'svc-app-public-${now}'
  scope: svcGroup
  dependsOn: [
    svcPlatform
    svcVault
    svcSql
  ]
  params: {
    location: config.location
    environment: environment
    serviceName: serviceName
    buildNumber: buildNumber
    tags: tags
    dataProtectionKeyUri: svcVault.outputs.dataProtectionKeyUri
    dataProtectionBlobUri: svcStorage.outputs.dataProtectionBlobUri

    // Resource names
    platformGroupName: platformGroupName
    containerRegistryName: containerRegistryName
    envGroupName: envGroupName
    appEnvName: appEnvName
    sqlGroupName: sqlGroupName
    sqlServerName: sqlServerName
    monitoringGroupName: monitoringGroupName
    appInsightsName: appInsightsName
    svcUserName: svcUserName
    appName: appName
    sqlDatabaseName: sqlDatabaseName
  }
}
