param location string = resourceGroup().location
param platformResourcePrefix string
param environmentResourcePrefix string
param serviceName string

resource svcUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: '${environmentResourcePrefix}-svc-${serviceName}'
  location: location
  tags: {
    product: platformResourcePrefix
    environment: environmentResourcePrefix
  }
}
