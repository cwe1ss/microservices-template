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
param platformLogsName string
param networkGroupName string
param networkVnetName string
param networkSubnetAppsName string
param serviceBusGroupName string
param serviceBusNamespaceName string
param serviceBusDaprPubSubKeyName string
param monitoringGroupName string
param monitoringAppInsightsName string
param appEnvName string


///////////////////////////////////
// Configuration

var config = loadJsonContent('./../config.json')

var servicesWithServiceBusEnabled = map(filter(items(config.services), svc => contains(svc.value, 'serviceBusEnabled') && svc.value.serviceBusEnabled == true), svc => svc.key)
//var servicesWithServiceBusEnabled = []


///////////////////////////////////
// Existing resources

var platformGroup = resourceGroup(platformGroupName)
var networkGroup = resourceGroup(networkGroupName)
var monitoringGroup = resourceGroup(monitoringGroupName)
var serviceBusGroup = resourceGroup(serviceBusGroupName)

resource platformLogs 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: platformLogsName
  scope: platformGroup
}

resource networkVnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: networkVnetName
  scope: networkGroup
}

resource networkSubnetApps 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  name: networkSubnetAppsName
  parent: networkVnet
}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' existing = {
  name: serviceBusNamespaceName
  scope: serviceBusGroup
}

resource monitoringAppInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: monitoringAppInsightsName
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
        customerId: platformLogs.properties.customerId
        sharedKey: platformLogs.listKeys().primarySharedKey
      }
    }
    daprAIConnectionString: monitoringAppInsights.properties.ConnectionString
    daprAIInstrumentationKey: monitoringAppInsights.properties.InstrumentationKey
    vnetConfiguration: {
      internal: false
      infrastructureSubnetId: networkSubnetApps.id
    }
  }
}

// TODO This is one of the few places where we currently need a connection string that doesn't use managed identities.
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
        value: listKeys('${serviceBusNamespace.id}/AuthorizationRules/${serviceBusDaprPubSubKeyName}', serviceBusNamespace.apiVersion).primaryConnectionString
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
