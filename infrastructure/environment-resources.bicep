param environment string
param tags object

// Configuration

var config = loadJsonContent('./_config.json')
var env = config.environments[environment]

// Naming conventions

var platformGroupName = '${config.platformResourcePrefix}-platform'
var logsName = '${config.platformResourcePrefix}-logs'
var serviceBusGroupName = '${env.environmentResourcePrefix}-bus'
var serviceBusName = '${env.environmentResourcePrefix}-bus'

var vnetName = '${env.environmentResourcePrefix}-vnet'
var appInsightsName = '${env.environmentResourcePrefix}-appinsights'
var appEnvName = '${env.environmentResourcePrefix}-env'

// Existing resources

var platformGroup = resourceGroup(platformGroupName)
var serviceBusGroup = resourceGroup(serviceBusGroupName)

resource logs 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logsName
  scope: platformGroup
}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' existing = {
  name: serviceBusName
  scope: serviceBusGroup
}


// New resources

resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: vnetName
  location: config.location
  tags: tags
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
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: config.location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logs.id
  }
}

resource appEnv 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: appEnvName
  location: config.location
  tags: tags
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
}

resource pubsubComponent 'Microsoft.App/managedEnvironments/daprComponents@2022-03-01' = {
  name: 'pubsub'
  parent: appEnv
  properties: {
    // https://docs.dapr.io/reference/components-reference/supported-pubsub/setup-azure-servicebus/
    componentType: 'pubsub.azure.servicebus'
    version: 'v1'
    secrets: [
      {
        name: 'pubsub-connection-string'
        value: listKeys('${serviceBusNamespace.id}/AuthorizationRules/RootManageSharedAccessKey', serviceBusNamespace.apiVersion).primaryConnectionString
      }
    ]
    metadata: [
      {
        name: 'connectionString'
        secretRef: 'pubsub-connection-string'
      }
    ]
  }
}
