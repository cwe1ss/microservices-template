// The entire environment uses one shared Service Bus namespace.
// The necessary queues & topics are added by the service deployments.

param environment string
param tags object

// Configuration

var config = loadJsonContent('./_config.json')
var env = config.environments[environment]

// Naming conventions

var serviceBusName = '${env.environmentResourcePrefix}-bus'

// New resources

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' = {
  name: serviceBusName
  location: config.location
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
