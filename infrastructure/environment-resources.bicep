param environment string
param tags object

// Configuration

var config = loadJsonContent('./_config.json')
var env = config.environments[environment]

// Naming conventions

var platformGroupName = '${config.platformResourcePrefix}-platform'
var logsName = '${config.platformResourcePrefix}-logs'

var vnetName = '${env.environmentResourcePrefix}-vnet'
var appInsightsName = '${env.environmentResourcePrefix}-appinsights'
var appEnvName = '${env.environmentResourcePrefix}-env'

// Existing resources

var platformGroup = resourceGroup(platformGroupName)

resource logs 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logsName
  scope: platformGroup
}

// New resources

resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: vnetName
  location: config.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        env.vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'aca-infrastructure'
        properties: {
          addressPrefix: env.acaInfrastructureAddressPrefix
          serviceEndpoints: [
            // TODO: Add any other service endpoints you require
            {
              service: 'Microsoft.Sql'
              locations: [
                '${config.location}'
              ]
            }
          ]
        }
      }
    ]
  }
  tags: tags
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: config.location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logs.id
  }
  tags: tags
}

resource appEnv 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: appEnvName
  location: config.location
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
    }
  }
  tags: tags
}
