param location string
param environment string
param tags object


///////////////////////////////////
// Resource names

param vnetName string
param appsSubnetName string


///////////////////////////////////
// Configuration

var config = loadJsonContent('./_config.json')
var env = config.environments[environment]


///////////////////////////////////
// New resources

resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        env.vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: appsSubnetName
        properties: {
          addressPrefix: env.appsSubnetAddressPrefix
          serviceEndpoints: [
            // TODO: Add any other service endpoints you require
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
