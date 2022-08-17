param location string = resourceGroup().location
param platformResourcePrefix string

resource acr 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: replace('${platformResourcePrefix}-registry', '-', '')
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
}

resource logs 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: '${platformResourcePrefix}-logs'
  location: location
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}
