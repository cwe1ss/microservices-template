param now string = utcNow()
param environment string
param serviceName string
param tags object

// Configuration

var config = loadJsonContent('./_config.json')
var env = config.environments[environment]
var svcConfig = env.services[serviceName]

// Naming conventions

var sqlServerName = '${env.environmentResourcePrefix}-sql'
var sqlServerUserName = '${env.environmentResourcePrefix}-sql'
var sqlDatabaseName = serviceName
var svcGroupName = '${env.environmentResourcePrefix}-svc-${serviceName}'
var svcUserName = '${env.environmentResourcePrefix}-svc-${serviceName}'

// Existing resources

var svcGroup = resourceGroup(svcGroupName)

resource sqlServer 'Microsoft.Sql/servers@2022-02-01-preview' existing = {
  name: sqlServerName
}

resource sqlServerUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: sqlServerUserName
}

resource svcUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: svcUserName
  scope: svcGroup
}

// New resources

resource database 'Microsoft.Sql/servers/databases@2022-02-01-preview' = {
  name: sqlDatabaseName
  parent: sqlServer
  location: config.location
  tags: tags
  sku: {
    name: svcConfig.sqlDatabase.skuName
    tier: svcConfig.sqlDatabase.skuTier
    capacity: svcConfig.sqlDatabase.skuCapacity
  }
  properties: {
  }
}

resource assignUserToDb 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${sqlDatabaseName}-deploy-user'
  location: config.location
  tags: tags
  dependsOn: [
    database
  ]
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${sqlServerUser.id}': {}
    }
  }
  properties: {
    forceUpdateTag: now
    azPowerShellVersion: '8.2.0'
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
    scriptContent: loadTextContent('service-sql-user.ps1')
    arguments: '-ServerName ${sqlServer.properties.fullyQualifiedDomainName} -DatabaseName ${sqlDatabaseName} -UserName ${svcUser.name}'
    timeout: 'PT10M'
  }
}
