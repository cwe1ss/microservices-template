param location string = resourceGroup().location
param platformResourcePrefix string
param tags object

resource acr 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: replace('${platformResourcePrefix}-registry', '-', '')
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
  name: '${platformResourcePrefix}-logs'
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
  tags: tags
}
