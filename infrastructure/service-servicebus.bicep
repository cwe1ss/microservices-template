///////////////////////////////////
// Resource names

param serviceBusName string
param svcGroupName string
param svcUserName string
param serviceBusIncomingQueueName string


///////////////////////////////////
// Existing resources

var svcGroup = resourceGroup(svcGroupName)

resource svcUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: svcUserName
  scope: svcGroup
}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' existing = {
  name: serviceBusName
}


///////////////////////////////////
// New resources

resource incomingQueue 'Microsoft.ServiceBus/namespaces/queues@2022-01-01-preview' = {
  name: serviceBusIncomingQueueName
  parent: serviceBusNamespace
  properties: {
  }
}

resource svcUserIncomingQueueReceiver 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(serviceBusIncomingQueueName, 'receiver', svcUser.id)
  scope: incomingQueue
  properties: {
    // https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#azure-service-bus-data-receiver
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0' /* Azure Service Bus Data Receiver */)
    principalId: svcUser.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// TODO remove this once ACA supports MI in Dapr
resource incomingQueueReceiverSas 'Microsoft.ServiceBus/namespaces/queues/authorizationRules@2022-01-01-preview' = {
  name: 'receive'
  parent: incomingQueue
  properties: {
    rights: [
      'Listen'
    ]
  }
}

// TODO remove this once ACA supports MI in Dapr
resource incomingQueueSenderSas 'Microsoft.ServiceBus/namespaces/queues/authorizationRules@2022-01-01-preview' = {
  name: 'send'
  parent: incomingQueue
  properties: {
    rights: [
      'Listen'
      'Send'
      'Manage'
    ]
  }
}
