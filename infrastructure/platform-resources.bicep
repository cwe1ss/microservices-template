param location string = resourceGroup().location
param tags object

var config = loadJsonContent('./_config.json')

// Resource names

var acrName = replace('${config.platformResourcePrefix}-registry', '-', '')
var logsName = '${config.platformResourcePrefix}-logs'

// New resources

resource acr 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
  tags: tags
}

resource logs 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logsName
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
  tags: tags
}
