param now string = utcNow()
param location string
param environment string
param serviceName string


///////////////////////////////////
// Resource names

param serviceBusGroupName string
param serviceBusName string


///////////////////////////////////
// Configuration

var config = loadJsonContent('./../config.json')
var envConfig = config.environments[environment]
var serviceConfig = envConfig.services[serviceName]
var serviceDefaults = config.services[serviceName]


///////////////////////////////////
// Existing resources

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' existing = {
  name: serviceBusName
}

// resource subscribedTopics 'Microsoft.ServiceBus/namespaces/topics@2022-01-01-preview' existing = [for item in serviceDefaults.serviceBus.subscriptions: {
//   name: item
//   parent: serviceBusNamespace
// }]

///////////////////////////////////
// New resources

resource topics 'Microsoft.ServiceBus/namespaces/topics@2022-01-01-preview' = [for item in serviceDefaults.serviceBus.topics: {
  name: item
  parent: serviceBusNamespace
  properties: {
  }
}]

resource subscriptions 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-01-01-preview' = [for item in serviceDefaults.serviceBus.subscriptions: {
  name: '${serviceBusName}/${item}/${serviceName}'
  dependsOn: [
    //subscribedTopics
    topics // In case there's a subscription to one of its own topics
  ]
  properties: {
  }
}]
