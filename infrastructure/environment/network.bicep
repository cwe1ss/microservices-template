param location string
param environment string
param tags object


///////////////////////////////////
// Resource names

param networkVnetName string
param networkSubnetAppsName string


///////////////////////////////////
// Configuration

var config = loadJsonContent('./../config.json')
var envConfig = config.environments[environment]


///////////////////////////////////
// New resources

resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: networkVnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        envConfig.vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: networkSubnetAppsName
        properties: {
          addressPrefix: envConfig.appsSubnetAddressPrefix
          serviceEndpoints: [
            // TODO: Add any other service endpoints you require
            {
              service: 'Microsoft.KeyVault'
              locations: [
                '${location}'
              ]
            }
            {
              service: 'Microsoft.Storage'
              locations: [
                '${location}'
              ]
            }
            {
              service: 'Microsoft.Sql'
              locations: [
                '${location}'
              ]
            }
          ]
        }
      }
    ]
  }
}
