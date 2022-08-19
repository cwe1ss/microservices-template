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

// Create the user assigned identity first, so that we can assign permissions to it before the rest of the service resources is created
module svcIdentity 'service-identity.bicep' = {
  name: 'svcIdentity'
  scope: svcGroup
  params: {
    location: location
    platformResourcePrefix: platformResourcePrefix
    environmentResourcePrefix: environmentResourcePrefix
    serviceName: serviceName
  }
}

// Allow the identity to access the platform container registry
module svcIdentityAssignment 'service-platform-assignments.bicep' = {
  name: 'svcIdentityAssignment'
  scope: platformGroup
  dependsOn: [
    svcIdentity
  ]
  params: {
    platformResourcePrefix: platformResourcePrefix
    environmentResourcePrefix: environmentResourcePrefix
    serviceName: serviceName
  }
}

module svcResources 'service-resources.bicep' = {
  name: 'svcResources'
  scope: svcGroup
  dependsOn: [
    svcIdentityAssignment
  ]
  params: {
    location: location
    platformResourcePrefix: platformResourcePrefix
    environmentResourcePrefix: environmentResourcePrefix
    serviceName: serviceName
    imageTag: imageTag
  }
}
