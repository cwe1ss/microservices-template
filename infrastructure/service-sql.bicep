param environment string
param serviceName string
param tags object

// Configuration

var config = loadJsonContent('./_config.json')
var env = config.environments[environment]
var svcConfig = env.services[serviceName]

// Naming conventions

var sqlServerName = '${env.environmentResourcePrefix}-sql'
var sqlDatabaseName = serviceName

// Existing resources

resource sqlServer 'Microsoft.Sql/servers@2022-02-01-preview' existing = {
  name: sqlServerName
}

// New resources

resource database 'Microsoft.Sql/servers/databases@2022-02-01-preview' = if (svcConfig.sqlDatabase.enabled) {
  name: sqlDatabaseName
  parent: sqlServer
  location: config.location
  sku: {
    name: svcConfig.sqlDatabase.skuName
    tier: svcConfig.sqlDatabase.skuTier
    capacity: svcConfig.sqlDatabase.skuCapacity
  }
  properties: {
  }
  tags: tags
}
