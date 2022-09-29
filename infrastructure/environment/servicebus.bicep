// The entire environment uses one shared Service Bus namespace.
// The necessary queues & topics are added by the service deployments.

param location string
param tags object


///////////////////////////////////
// Resource names

param serviceBusNamespaceName string
param serviceBusDaprPubSubKeyName string


///////////////////////////////////
// New resources

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' = {
  name: serviceBusNamespaceName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

resource daprPubSubKey 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2022-01-01-preview' = {
  name: serviceBusDaprPubSubKeyName
  parent: serviceBusNamespace
  properties: {
    rights: [
      'Listen'
      'Send'
      'Manage'
    ]
  }
}
