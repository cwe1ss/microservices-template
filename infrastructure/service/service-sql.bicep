param now string = utcNow()
param location string
param environment string
param serviceName string
param buildNumber string
param tags object


///////////////////////////////////
// Resource names

param platformGroupName string
param storageAccountName string
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

resource storage 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: storageAccountName
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

resource database 'Microsoft.Sql/servers/databases@2022-02-01-preview' = {
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

resource deploySqlUserScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
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
    azPowerShellVersion: '8.2.0'
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
    scriptContent: loadTextContent('service-sql-user.ps1')
    arguments: '-ServerName ${sqlServer.properties.fullyQualifiedDomainName} -DatabaseName ${database.name} -UserName ${svcUser.name}'
    timeout: 'PT10M'
  }
}

var containerSas = storage.listServiceSAS(storage.apiVersion, {
  canonicalizedResource: '/blob/${storage.name}/${sqlMigrationContainerName}/${sqlMigrationFile}'
  signedProtocol: 'https'
  signedResource: 'b'
  signedPermission: 'r'
  signedExpiry: dateTimeAdd(now, 'PT1H')
})
var sqlMigrationBlobUrl = '${storage.properties.primaryEndpoints.blob}${sqlMigrationContainerName}/${sqlMigrationFile}?${containerSas.serviceSasToken}'

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
    azPowerShellVersion: '8.2.0'
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
    scriptContent: loadTextContent('service-sql-migration.ps1')
    arguments: '-ServerName ${sqlServer.properties.fullyQualifiedDomainName} -DatabaseName ${database.name} -SqlMigrationBlobUrl \\"${sqlMigrationBlobUrl}\\"'
    timeout: 'PT10M'
  }
}
