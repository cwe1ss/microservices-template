param serviceName string


///////////////////////////////////
// Resource names

param serviceBusNamespaceName string
param svcGroupName string
param svcUserName string


///////////////////////////////////
// Configuration

var config = loadJsonContent('./../config.json')
var serviceDefaults = config.services[serviceName]

var serviceBusTopics = contains(serviceDefaults, 'serviceBusTopics') ? serviceDefaults.serviceBusTopics : []
var serviceBusSubscriptions = contains(serviceDefaults, 'serviceBusSubscriptions') ? serviceDefaults.serviceBusSubscriptions : []

// If the service subscribes to a topic that hasn't been deployed yet, its deployment would fail.
// We therefore also create the topic when a subscriber-service is deployed.
var allTopics = union(serviceBusTopics, serviceBusSubscriptions)


///////////////////////////////////
// Existing resources

var svcGroup = resourceGroup(svcGroupName)

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' existing = {
  name: serviceBusNamespaceName
}

resource svcUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: svcUserName
  scope: svcGroup
}

@description('This is the built-in "Azure Service Bus Data Receiver" role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#azure-service-bus-data-receiver ')
resource dataReceiverRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'
}

@description('This is the built-in "Azure Service Bus Data Sender" role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#azure-service-bus-data-sender ')
resource dataSenderRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'
}


///////////////////////////////////
// New resources

resource topics 'Microsoft.ServiceBus/namespaces/topics@2022-01-01-preview' = [for item in allTopics: {
  name: item
  parent: serviceBusNamespace
  properties: {
  }
}]

resource subscriptions 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-01-01-preview' = [for item in serviceBusSubscriptions: {
  name: '${serviceBusNamespaceName}/${item}/${serviceName}'
  dependsOn: [
    topics
  ]
  properties: {
  }
}]

resource topicSenderRole 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [for (topic, i) in serviceBusTopics: {
  name: guid(subscription().id, topic, serviceName, 'Sender')
  scope: topics[i]
  properties: {
    roleDefinitionId: dataSenderRoleDefinition.id
    principalId: svcUser.properties.principalId
    principalType: 'ServicePrincipal'
  }
}]

resource subscriptionReceiverRole 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [for (subscription, i) in serviceBusSubscriptions: {
  name: guid(subscription().id, subscription, serviceName, 'Receive')
  scope: subscriptions[i]
  properties: {
    roleDefinitionId: dataReceiverRoleDefinition.id
    principalId: svcUser.properties.principalId
    principalType: 'ServicePrincipal'
  }
}]
