param location string = resourceGroup().location
param platformResourcePrefix string
param environmentResourcePrefix string
param serviceName string
param tags object

resource sqlServer 'Microsoft.Sql/servers@2022-02-01-preview' existing = {
  name: '${environmentResourcePrefix}-sql'
}

resource database 'Microsoft.Sql/servers/databases@2022-02-01-preview' = {
  name: serviceName
  parent: sqlServer
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  }
  properties: {

  }
  tags: tags
}
