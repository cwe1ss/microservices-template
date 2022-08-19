targetScope = 'subscription'

param location string
param platformResourcePrefix string
param environmentResourcePrefix string
param serviceName string
param imageTag string

// Existing resources

resource platformGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: '${platformResourcePrefix}-platform'
}

// New resources

resource svcGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${environmentResourcePrefix}-svc-${serviceName}'
  location: location
  tags: {
    product: platformResourcePrefix
    environment: environmentResourcePrefix
  }
}

module svcResources 'service-resources.bicep' = {
  name: 'svcResources'
  scope: svcGroup
  params: {
    location: location
    platformResourcePrefix: platformResourcePrefix
    environmentResourcePrefix: environmentResourcePrefix
    serviceName: serviceName
    imageTag: imageTag
  }
}

module svcIdentityAssignment 'service-platform-assignments.bicep' = {
  name: 'svcIdentityAssignment'
  scope: platformGroup
  dependsOn: [
    svcResources
  ]
  params: {
    platformResourcePrefix: platformResourcePrefix
    environmentResourcePrefix: environmentResourcePrefix
    serviceName: serviceName
  }
}
