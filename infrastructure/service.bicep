targetScope = 'subscription'

param location string
param environmentResourcePrefix string
param serviceName string

resource svcGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${environmentResourcePrefix}-svc-${serviceName}'
  location: location
}

module svcResources 'service-resources.bicep' = {
  name: 'svcResources'
  scope: svcGroup
  params: {
    location: location
    environmentResourcePrefix: environmentResourcePrefix
    serviceName: serviceName
  }
}
