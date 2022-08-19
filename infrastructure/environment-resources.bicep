param location string = resourceGroup().location
param platformResourcePrefix string
param environmentResourcePrefix string

resource logs 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: '${platformResourcePrefix}-logs'
  scope: resourceGroup('${platformResourcePrefix}-platform')
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${environmentResourcePrefix}-appinsights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logs.id
  }
  tags: {
    product: platformResourcePrefix
    environment: environmentResourcePrefix
  }
}

resource env 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: '${environmentResourcePrefix}-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logs.properties.customerId
        sharedKey: logs.listKeys().primarySharedKey
      }
    }
    daprAIConnectionString: appInsights.properties.ConnectionString
    daprAIInstrumentationKey: appInsights.properties.InstrumentationKey
  }
  tags: {
    product: platformResourcePrefix
    environment: environmentResourcePrefix
  }
}
