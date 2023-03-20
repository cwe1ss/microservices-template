param serviceName string


///////////////////////////////////
// Resource names

param appEnvironmentName string
param serviceBusGroupName string
param serviceBusNamespaceName string
param svcGroupName string
param svcUserName string
param svcDaprPubSubName string


///////////////////////////////////
// Existing resources

var serviceBusGroup = resourceGroup(serviceBusGroupName)
var svcGroup = resourceGroup(svcGroupName)

resource appEnv 'Microsoft.App/managedEnvironments@2022-10-01' existing = {
  name: appEnvironmentName
}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' existing = {
  name: serviceBusNamespaceName
  scope: serviceBusGroup
}

resource svcUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: svcUserName
  scope: svcGroup
}


///////////////////////////////////
// New resources

resource pubsubComponent 'Microsoft.App/managedEnvironments/daprComponents@2022-10-01' = {
  name: svcDaprPubSubName
  parent: appEnv
  properties: {
    // https://docs.dapr.io/reference/components-reference/supported-pubsub/setup-azure-servicebus/
    componentType: 'pubsub.azure.servicebus'
    version: 'v1'
    metadata: [
      {
        name: 'azureClientId'
        value: svcUser.properties.clientId
      }
      {
        name: 'namespaceName'
        // NOTE: Dapr expects just the domain name.
        value: replace(replace(serviceBusNamespace.properties.serviceBusEndpoint, 'https://', ''), ':443/', '')
      }
      {
        // Topics and subscriptions for the service are created during deployment by 'servicebus.bicep' (as configured in 'config.json')
        name: 'disableEntityManagement'
        value: 'true'
      }
    ]
    scopes: [
      serviceName
    ]
  }
}
