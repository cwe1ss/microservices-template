param serviceName string


///////////////////////////////////
// Resource names

param appConfigStoreName string
param svcGroupName string
param svcUserName string


///////////////////////////////////
// Existing resources

var svcGroup = resourceGroup(svcGroupName)

resource appConfigStore 'Microsoft.AppConfiguration/configurationStores@2022-05-01' existing = {
  name: appConfigStoreName
}

resource svcUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: svcUserName
  scope: svcGroup
}

@description('This is the built-in "App Configuration Data Reader" role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#app-configuration-data-reader ')
resource dataReaderRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '516239f1-63e1-4d78-a4de-a74fb236a071'
}


///////////////////////////////////
// New resources

resource dataReaderRole 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().id, serviceName, 'Reader')
  scope: appConfigStore
  properties: {
    roleDefinitionId: dataReaderRoleDefinition.id
    principalId: svcUser.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
