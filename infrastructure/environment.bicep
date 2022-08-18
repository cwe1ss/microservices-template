targetScope = 'subscription'

param location string
param platformResourcePrefix string
param environmentResourcePrefix string

resource envGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${environmentResourcePrefix}-env'
  location: location
  tags: {
    product: platformResourcePrefix
    environment: environmentResourcePrefix
  }
}

module envResources 'environment-resources.bicep' = {
  name: 'envResources'
  scope: envGroup
  params: {
    location: location
    platformResourcePrefix: platformResourcePrefix
    environmentResourcePrefix: environmentResourcePrefix
  }
}
