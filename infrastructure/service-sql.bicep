param environment string
param serviceName string
param tags object

var config = loadJsonContent('./_config.json')
var env = config.environments[environment]

// Resource names

var sqlServerName = '${env.environmentResourcePrefix}-sql'
var sqlDatabaseName = serviceName

// Configuration values

var databaseSkuName = 'Basic'
var databaseSkuTier = 'Basic'
var databaseSkuCapacity = 5

// Existing resources

resource sqlServer 'Microsoft.Sql/servers@2022-02-01-preview' existing = {
  name: sqlServerName
}

// New resources

resource database 'Microsoft.Sql/servers/databases@2022-02-01-preview' = {
  name: sqlDatabaseName
  parent: sqlServer
  location: config.location
  sku: {
    name: databaseSkuName
    tier: databaseSkuTier
    capacity: databaseSkuCapacity
  }
  properties: {
  }
  tags: tags
}
