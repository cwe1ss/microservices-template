// Contains the main entry point for deploying all Azure resources required by one service.

targetScope = 'subscription'

param now string = utcNow()
param environment string
param serviceName string
param buildNumber string


///////////////////////////////////
// Configuration

var names = loadJsonContent('./../names.json')
var config = loadJsonContent('./../config.json')
var envConfig = config.environments[environment]
var serviceDefaults = config.services[serviceName]

var sqlDatabaseEnabled = contains(serviceDefaults, 'sqlDatabaseEnabled') ? serviceDefaults.sqlDatabaseEnabled : false
var serviceBusEnabled = contains(serviceDefaults, 'serviceBusEnabled') ? serviceDefaults.serviceBusEnabled : false

var tags = {
  product: config.platformAbbreviation
  environment: envConfig.environmentAbbreviation
  service: serviceName
}


///////////////////////////////////
// Resource names

// Platform
var platformGroupName = replace(names.platformGroupName, '{platform}', config.platformAbbreviation)
var platformContainerRegistryName = replace(replace(names.platformContainerRegistryName, '{platform}', config.platformAbbreviation), '-', '')
var platformLogsName = replace(names.platformLogsName, '{platform}', config.platformAbbreviation)
var platformStorageAccountName = toLower(replace(replace(names.platformStorageAccountName, '{platform}', config.platformAbbreviation), '-', ''))

// Environment: Network
var networkGroupName = replace(names.networkGroupName, '{environment}', envConfig.environmentAbbreviation)
var networkVnetName = replace(names.networkVnetName, '{environment}', envConfig.environmentAbbreviation)
var networkSubnetAppsName = replace(names.networkSubnetAppsName, '{environment}', envConfig.environmentAbbreviation)

// Environment: Monitoring
var monitoringGroupName = replace(names.monitoringGroupName, '{environment}', envConfig.environmentAbbreviation)
var monitoringAppInsightsName = replace(names.monitoringAppInsightsName, '{environment}', envConfig.environmentAbbreviation)

// Environment: SQL
var sqlGroupName = replace(names.sqlGroupName, '{environment}', envConfig.environmentAbbreviation)
var sqlServerAdminUserName = replace(names.sqlServerAdminName, '{environment}', envConfig.environmentAbbreviation)
var sqlServerName = replace(names.sqlServerName, '{environment}', envConfig.environmentAbbreviation)

// Environment: Service Bus
var serviceBusGroupName = replace(names.serviceBusGroupName, '{environment}', envConfig.environmentAbbreviation)
var serviceBusNamespaceName = replace(names.serviceBusNamespaceName, '{environment}', envConfig.environmentAbbreviation)

// Environment: Container Apps Environment
var appEnvironmentGroupName = replace(names.appEnvironmentGroupName, '{environment}', envConfig.environmentAbbreviation)
var appEnvironmentName = replace(names.appEnvironmentName, '{environment}', envConfig.environmentAbbreviation)

// Service
var svcGroupName = replace(replace(names.svcGroupName, '{environment}', envConfig.environmentAbbreviation), '{service}', serviceName)
var svcUserName = replace(replace(names.svcUserName, '{environment}', envConfig.environmentAbbreviation), '{service}', serviceName)
var svcAppName = take(replace(replace(names.svcAppName, '{environment}', envConfig.environmentAbbreviation), '{service}', serviceName), 32 /* max allowed length */)

// Service: Storage
var svcStorageAccountName = take(replace(replace(replace(names.svcStorageAccountName, '{environment}', envConfig.environmentAbbreviation), '{service}', serviceName), '-', ''), 24 /* max allowed length */)

// Service: Key Vault
var svcKeyVaultName = take(replace(replace(replace(names.svcKeyVaultName, '{environment}', envConfig.environmentAbbreviation), '{service}', serviceName), '-', ''), 24 /* max allowed length */)

// Service: SQL
var sqlDatabaseName = replace(replace(names.svcSqlDatabaseName, '{environment}', envConfig.environmentAbbreviation), '{service}', serviceName)
var sqlDeployUserScriptName = replace(replace(names.svcSqlDeployUserScriptName, '{environment}', envConfig.environmentAbbreviation), '{service}', serviceName)
var sqlDeployMigrationScriptName = replace(replace(names.svcSqlDeployMigrationScriptName, '{environment}', envConfig.environmentAbbreviation), '{service}', serviceName)

// Service: Dapr
var svcDaprPubSubName = replace(names.svcDaprPubSubName, '{service}', serviceName)

// Service: Build artifacts
var svcArtifactContainerImageWithTag = '${replace(replace(names.svcArtifactContainerImageName, '{platform}', config.platformAbbreviation), '{service}', serviceName)}:${buildNumber}'
var svcArtifactSqlMigrationFile = replace(replace(replace(names.svcArtifactSqlMigrationFile, '{platform}', config.platformAbbreviation), '{service}', serviceName), '{buildNumber}', buildNumber)


///////////////////////////////////
// Existing resources

var platformGroup = resourceGroup(platformGroupName)
var appEnvironmentGroup = resourceGroup(appEnvironmentGroupName)
var sqlGroup = resourceGroup(sqlGroupName)
var serviceBusGroup = resourceGroup(serviceBusGroupName)


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
module platform 'platform.bicep' = {
  name: 'svc-platform-${now}'
  scope: platformGroup
  dependsOn: [
    svcIdentity
  ]
  params: {
    // Resource names
    platformContainerRegistryName: platformContainerRegistryName
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
    networkVnetName: networkVnetName
    networkSubnetAppsName: networkSubnetAppsName
    svcGroupName: svcGroupName
    svcUserName: svcUserName
    svcStorageAccountName: svcStorageAccountName
    svcStorageDataProtectionContainerName: names.svcDataProtectionStorageContainerName
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
    platformGroupName: platformGroupName
    platformLogsName: platformLogsName
    diagnosticSettingsName: names.diagnosticSettingsName
    networkGroupName: networkGroupName
    networkVnetName: networkVnetName
    networkSubnetAppsName: networkSubnetAppsName
    svcGroupName: svcGroupName
    svcUserName: svcUserName
    svcVaultName: svcKeyVaultName
    svcVaultDataProtectionKeyName: names.svcDataProtectionKeyName
  }
}

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
    platformStorageAccountName: platformStorageAccountName
    sqlMigrationContainerName: names.platformSqlMigrationStorageContainerName
    sqlMigrationFile: svcArtifactSqlMigrationFile
    sqlServerName: sqlServerName
    sqlServerAdminUserName: sqlServerAdminUserName
    sqlDatabaseName: sqlDatabaseName
    svcGroupName: svcGroupName
    svcUserName: svcUserName
    sqlDeployUserScriptName: sqlDeployUserScriptName
    sqlDeployMigrationScriptName: sqlDeployMigrationScriptName
  }
}

module svcServiceBus 'servicebus.bicep' = if (serviceBusEnabled) {
  name: 'svc-bus-${now}'
  scope: serviceBusGroup
  params: {
    serviceName: serviceName

    // Resource names
    serviceBusNamespaceName: serviceBusNamespaceName
    svcGroupName: svcGroupName
    svcUserName: svcUserName
  }
}

module svcAppEnvPubSub 'app-environment-pubsub.bicep' = if (serviceBusEnabled) {
  name: 'svc-env-${now}'
  scope: appEnvironmentGroup
  dependsOn: [
    svcServiceBus
  ]
  params: {
    serviceName: serviceName

    // Resource names
    appEnvironmentName: appEnvironmentName
    serviceBusGroupName: serviceBusGroupName
    serviceBusNamespaceName: serviceBusNamespaceName
    svcGroupName: svcGroupName
    svcUserName: svcUserName
    svcDaprPubSubName: svcDaprPubSubName
  }
}

module svcAppGrpc 'app-grpc.bicep' = if (serviceDefaults.appType == 'grpc') {
  name: 'svc-app-grpc-${now}'
  scope: svcGroup
  dependsOn: [
    platform
    svcVault
    svcSql
    svcServiceBus
    svcAppEnvPubSub
  ]
  params: {
    location: config.location
    environment: environment
    serviceName: serviceName
    tags: tags

    // Resource names
    platformGroupName: platformGroupName
    platformContainerRegistryName: platformContainerRegistryName
    appEnvGroupName: appEnvironmentGroupName
    appEnvName: appEnvironmentName
    sqlGroupName: sqlGroupName
    sqlServerName: sqlServerName
    sqlDatabaseName: sqlDatabaseName
    monitoringGroupName: monitoringGroupName
    monitoringAppInsightsName: monitoringAppInsightsName
    svcUserName: svcUserName
    svcAppName: svcAppName
    svcArtifactContainerImageWithTag: svcArtifactContainerImageWithTag
  }
}

module svcAppHttp 'app-http.bicep' = if (serviceDefaults.appType == 'http') {
  name: 'svc-app-http-${now}'
  scope: svcGroup
  dependsOn: [
    platform
    svcVault
    svcSql
    svcServiceBus
    svcAppEnvPubSub
  ]
  params: {
    location: config.location
    environment: environment
    serviceName: serviceName
    tags: tags

    // Resource names
    platformGroupName: platformGroupName
    platformContainerRegistryName: platformContainerRegistryName
    appEnvGroupName: appEnvironmentGroupName
    appEnvName: appEnvironmentName
    sqlGroupName: sqlGroupName
    sqlServerName: sqlServerName
    sqlDatabaseName: sqlDatabaseName
    monitoringGroupName: monitoringGroupName
    monitoringAppInsightsName: monitoringAppInsightsName
    svcUserName: svcUserName
    svcAppName: svcAppName
    svcArtifactContainerImageWithTag: svcArtifactContainerImageWithTag
  }
}

module svcAppPublic 'app-public.bicep' = if (serviceDefaults.appType == 'public') {
  name: 'svc-app-public-${now}'
  scope: svcGroup
  dependsOn: [
    platform
    svcVault
    svcSql
    svcServiceBus
    svcAppEnvPubSub
  ]
  params: {
    location: config.location
    environment: environment
    serviceName: serviceName
    tags: tags
    dataProtectionKeyUri: svcVault.outputs.dataProtectionKeyUri
    dataProtectionBlobUri: svcStorage.outputs.dataProtectionBlobUri

    // Resource names
    platformGroupName: platformGroupName
    platformContainerRegistryName: platformContainerRegistryName
    appEnvGroupName: appEnvironmentGroupName
    appEnvName: appEnvironmentName
    sqlGroupName: sqlGroupName
    sqlServerName: sqlServerName
    sqlDatabaseName: sqlDatabaseName
    monitoringGroupName: monitoringGroupName
    monitoringAppInsightsName: monitoringAppInsightsName
    svcUserName: svcUserName
    svcAppName: svcAppName
    svcArtifactContainerImageWithTag: svcArtifactContainerImageWithTag
  }
}
