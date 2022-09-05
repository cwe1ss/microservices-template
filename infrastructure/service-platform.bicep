///////////////////////////////////
// Resource names

param containerRegistryName string
param svcGroupName string
param svcUserName string


///////////////////////////////////
// Existing resources

var svcGroup = resourceGroup(svcGroupName)

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-09-01' existing = {
  name: containerRegistryName
}

resource svcUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: svcUserName
  scope: svcGroup
}


///////////////////////////////////
// New resources

// Allows the service to pull images from the Azure Container Registry
resource svcUserAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('acrPull', svcUser.id)
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d' /* acrPull */)
    principalId: svcUser.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
