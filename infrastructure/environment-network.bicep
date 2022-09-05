param environment string
param tags object

// Configuration

var config = loadJsonContent('./_config.json')
var env = config.environments[environment]

// Naming conventions

var vnetName = '${env.environmentResourcePrefix}-vnet'
var appsSubnetName = 'apps'

// New resources

resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: vnetName
  location: config.location
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
                '${config.location}'
              ]
            }
          ]
        }
      }
    ]
  }
}
