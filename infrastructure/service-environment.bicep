//param environment string
param serviceName string


///////////////////////////////////
// Resource names

param appEnvName string
param serviceBusGroupName string
param serviceBusName string
param svcGroupName string
param svcUserName string
param serviceBusIncomingQueueName string


///////////////////////////////////
// Configuration

//var config = loadJsonContent('./_config.json')
//var env = config.environments[environment]
//var svcConfig = env.services[serviceName]


///////////////////////////////////
// Existing resources

//var svcGroup = resourceGroup(svcGroupName)
var serviceBusGroup = resourceGroup(serviceBusGroupName)

// resource svcUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
//   name: svcUserName
//   scope: svcGroup
// }

resource appEnv 'Microsoft.App/managedEnvironments@2022-03-01' existing = {
  name: appEnvName
}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' existing = {
  name: serviceBusName
  scope: serviceBusGroup
}

resource incomingQueue 'Microsoft.ServiceBus/namespaces/queues@2022-01-01-preview' existing = {
  name: serviceBusIncomingQueueName
  parent: serviceBusNamespace
}


///////////////////////////////////
// New resources

// resource incomingQueueComponent 'Microsoft.App/managedEnvironments/daprComponents@2022-03-01' = {
//   name: '${serviceName}-queue'
//   parent: appEnv
//   properties: {
//     // https://docs.dapr.io/reference/components-reference/supported-pubsub/setup-azure-servicebus/
//     componentType: 'pubsub.azure.servicebus'
//     version: 'v1'
//     metadata: [
//       {
//         name: 'namespaceName'
//         value: serviceBusNamespace.properties.serviceBusEndpoint
//       }
//       // {
//       //   name: 'azureClientId'
//       //   value: svcUser.properties.clientId
//       // }
//     ]
//     scopes: [
//       serviceName
//     ]
//   }
// }

var sbConnectionString = listKeys('${incomingQueue.id}/AuthorizationRules/send', incomingQueue.apiVersion).primaryConnectionString

resource testQueueComponent 'Microsoft.App/managedEnvironments/daprComponents@2022-03-01' = {
  name: '${serviceName}-test'
  parent: appEnv
  properties: {
    // https://docs.dapr.io/reference/components-reference/supported-bindings/servicebusqueues/
    componentType: 'bindings.azure.servicebusqueues'
    version: 'v1'
    secrets: [
      {
        name: 'queue-connection-string'
        value: sbConnectionString
      }
    ]
    metadata: [
      {
        name: 'connectionString'
        secretRef: 'queue-connection-string'
      }
      // TODO switch to this once ACA supports managed identities for dapr components.
      // {
      //   name: 'namespaceName'
      //   value: serviceBusNamespace.properties.serviceBusEndpoint
      // }
      // {
      //   name: 'azureClientId'
      //   value: svcUser.properties.clientId
      // }
      {
        name: 'queueName'
        value: serviceBusIncomingQueueName
      }
    ]
    scopes: [
      serviceName
    ]
  }
}
