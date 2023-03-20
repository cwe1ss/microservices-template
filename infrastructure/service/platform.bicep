///////////////////////////////////
// Resource names

param platformContainerRegistryName string
param svcGroupName string
param svcUserName string


///////////////////////////////////
// Existing resources

var svcGroup = resourceGroup(svcGroupName)

resource platformContainerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: platformContainerRegistryName
}

resource svcUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: svcUserName
  scope: svcGroup
}


///////////////////////////////////
// Existing resources

@description('This is the built-in "AcrPull" role. See https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#acrpull ')
resource acrPullRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
}


///////////////////////////////////
// New resources

// Allows the service to pull images from the Azure Container Registry
resource svcUserAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('acrPull', svcUser.id)
  scope: platformContainerRegistry
  properties: {
    roleDefinitionId: acrPullRoleDefinition.id
    principalId: svcUser.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
