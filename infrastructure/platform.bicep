targetScope = 'subscription'

param location string
param platformResourcePrefix string

resource platformGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${platformResourcePrefix}-platform'
  location: location
  tags: {
    product: platformResourcePrefix
  }
}

module platformResources 'platform-resources.bicep' = {
  name: 'platformResources'
  scope: platformGroup
  params: {
    location: location
    platformResourcePrefix: platformResourcePrefix
  }
}
