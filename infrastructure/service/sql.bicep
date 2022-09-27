param now string = utcNow()
param location string
param environment string
param serviceName string
param buildNumber string
param tags object


///////////////////////////////////
// Resource names

param platformGroupName string
param platformStorageAccountName string
param sqlMigrationContainerName string
param sqlMigrationFile string
param sqlServerName string
param sqlServerAdminUserName string
param sqlDatabaseName string
param svcGroupName string
param svcUserName string
param sqlDeployUserScriptName string
param sqlDeployMigrationScriptName string


///////////////////////////////////
// Configuration

var config = loadJsonContent('./../config.json')
var envConfig = config.environments[environment]
var serviceConfig = envConfig.services[serviceName]


///////////////////////////////////
// Existing resources

var platformGroup = resourceGroup(platformGroupName)
var svcGroup = resourceGroup(svcGroupName)

resource platformStorage 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: platformStorageAccountName
  scope: platformGroup
}

resource sqlServer 'Microsoft.Sql/servers@2022-02-01-preview' existing = {
  name: sqlServerName
}

resource sqlServerAdminUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: sqlServerAdminUserName
}

resource svcUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: svcUserName
  scope: svcGroup
}


///////////////////////////////////
// New resources

resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-02-01-preview' = {
  name: sqlDatabaseName
  parent: sqlServer
  location: location
  tags: tags
  sku: {
    name: serviceConfig.sqlDatabase.skuName
    tier: serviceConfig.sqlDatabase.skuTier
    capacity: serviceConfig.sqlDatabase.skuCapacity
  }
  properties: {
  }
}

resource sqlDeployUserScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: sqlDeployUserScriptName
  location: location
  tags: tags
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${sqlServerAdminUser.id}': {}
    }
  }
  properties: {
    forceUpdateTag: '0' // This script must only execute once, so we can always use the same update tag!
    containerSettings: {
      containerGroupName: sqlDeployUserScriptName
    }
    azPowerShellVersion: '8.2.0'
    retentionInterval: 'P1D'
    cleanupPreference: 'Always'
    scriptContent: loadTextContent('sql-user.ps1')
    arguments: '-ServerName ${sqlServer.properties.fullyQualifiedDomainName} -DatabaseName ${sqlDatabase.name} -UserName ${svcUser.name}'
    timeout: 'PT10M'
  }
}

var containerSas = platformStorage.listServiceSAS(platformStorage.apiVersion, {
  canonicalizedResource: '/blob/${platformStorage.name}/${sqlMigrationContainerName}/${sqlMigrationFile}'
  signedProtocol: 'https'
  signedResource: 'b'
  signedPermission: 'r'
  signedExpiry: dateTimeAdd(now, 'PT1H')
})
var sqlMigrationBlobUrl = '${platformStorage.properties.primaryEndpoints.blob}${sqlMigrationContainerName}/${sqlMigrationFile}?${containerSas.serviceSasToken}'

resource deploySqlMigrationScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: sqlDeployMigrationScriptName
  location: location
  tags: tags
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${sqlServerAdminUser.id}': {}
    }
  }
  properties: {
    forceUpdateTag: buildNumber // The migration only needs to be applied once per build
    containerSettings: {
      containerGroupName: sqlDeployMigrationScriptName
    }
    azPowerShellVersion: '8.2.0'
    retentionInterval: 'P1D'
    cleanupPreference: 'Always'
    scriptContent: loadTextContent('sql-migration.ps1')
    arguments: '-ServerName ${sqlServer.properties.fullyQualifiedDomainName} -DatabaseName ${sqlDatabase.name} -SqlMigrationBlobUrl \\"${sqlMigrationBlobUrl}\\"'
    timeout: 'PT10M'
  }
}
