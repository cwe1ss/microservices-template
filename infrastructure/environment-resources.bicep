param location string = resourceGroup().location
param platformResourcePrefix string
param environmentResourcePrefix string
param tags object


resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: '${environmentResourcePrefix}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.130.0.0/16'
      ]
    }
    subnets: [
      {
        name: '${environmentResourcePrefix}-infrastructure'
        properties: {
          addressPrefix: '10.130.0.0/23'
          serviceEndpoints: [ // TODO: Can this be removed once apps actually use the other subnet?
            {
              service: 'Microsoft.Sql'
              locations: [
                '${location}'
              ]
            }
          ]
        }
      }
      {
        name: '${environmentResourcePrefix}-apps'
        properties: {
          addressPrefix: '10.130.8.0/21'
          serviceEndpoints: [
            {
              service: 'Microsoft.Sql'
              locations: [
                '${location}'
              ]
            }
          ]
        }
      }
    ]
  }
  tags: tags
}

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
  tags: tags
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
    vnetConfiguration: {
      internal: false
      infrastructureSubnetId: vnet.properties.subnets[0].id
      runtimeSubnetId: vnet.properties.subnets[1].id
    }
  }
  tags: tags
}
