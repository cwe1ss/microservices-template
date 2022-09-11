// Deploys the "Container Apps Environment".
// The "container app" for each service will be deployed into its own resource group by the service.
//
// The following resources will be deployed:
// * An "Azure Container Apps environment", used to store all service apps.
// * A Dapr "pubsub"-component for Azure Service Bus.

param location string
param tags object


///////////////////////////////////
// Resource names

param platformGroupName string
param logsName string
param networkGroupName string
param vnetName string
param appsSubnetName string
param serviceBusGroupName string
param serviceBusName string
param monitoringGroupName string
param appInsightsName string
param appEnvName string


///////////////////////////////////
// Configuration

var config = loadJsonContent('./../config.json')

var servicesWithServiceBusEnabled = map(filter(items(config.services), svc => contains(svc.value, 'serviceBusEnabled') && svc.value.serviceBusEnabled == true), svc => svc.key)

output servicesWithServiceBusEnabled array = servicesWithServiceBusEnabled


///////////////////////////////////
// Existing resources

var platformGroup = resourceGroup(platformGroupName)
var networkGroup = resourceGroup(networkGroupName)
var monitoringGroup = resourceGroup(monitoringGroupName)
var serviceBusGroup = resourceGroup(serviceBusGroupName)

resource logs 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logsName
  scope: platformGroup
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: vnetName
  scope: networkGroup
}

resource appsSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  name: appsSubnetName
  parent: vnet
}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' existing = {
  name: serviceBusName
  scope: serviceBusGroup
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
  scope: monitoringGroup
}


///////////////////////////////////
// New resources

resource appEnv 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: appEnvName
  location: location
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
      infrastructureSubnetId: appsSubnet.id
    }
  }
}

// TODO Remove this?
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
    scopes: servicesWithServiceBusEnabled
  }
}
