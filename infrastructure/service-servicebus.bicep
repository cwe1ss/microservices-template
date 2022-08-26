param environment string
param serviceName string

// Configuration

var config = loadJsonContent('./_config.json')
var env = config.environments[environment]
//var svcConfig = env.services[serviceName]

// Naming conventions

var serviceBusName = '${env.environmentResourcePrefix}-bus'
var svcGroupName = '${env.environmentResourcePrefix}-svc-${serviceName}'
var svcUserName = '${env.environmentResourcePrefix}-svc-${serviceName}'
var incomingQueueName = serviceName

// Existing resources

var svcGroup = resourceGroup(svcGroupName)

resource svcUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: svcUserName
  scope: svcGroup
}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' existing = {
  name: serviceBusName
}

// New resources

resource incomingQueue 'Microsoft.ServiceBus/namespaces/queues@2022-01-01-preview' = {
  name: incomingQueueName
  parent: serviceBusNamespace
  properties: {
  }
}

resource svcUserIncomingQueueRead 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(incomingQueueName, 'receiver', svcUser.id)
  scope: incomingQueue
  properties: {
    // https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#azure-service-bus-data-receiver
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0' /* Azure Service Bus Data Receiver */)
    principalId: svcUser.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
