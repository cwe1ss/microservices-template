param location string = resourceGroup().location
param environmentResourcePrefix string
param serviceName string
param tags object

resource svcUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: '${environmentResourcePrefix}-svc-${serviceName}'
  location: location
  tags: tags
}
