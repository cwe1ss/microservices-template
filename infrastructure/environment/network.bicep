param location string
param environment string
param tags object


///////////////////////////////////
// Resource names

param platformGroupName string
param platformLogsName string
param diagnosticSettingsName string
param networkVnetName string
param networkSubnetAppsName string
param networkNsgAppsName string


///////////////////////////////////
// Configuration

var config = loadJsonContent('./../config.json')
var envConfig = config.environments[environment]


///////////////////////////////////
// Existing resources

var platformGroup = resourceGroup(platformGroupName)

resource platformLogs 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: platformLogsName
  scope: platformGroup
}


///////////////////////////////////
// New resources

// https://learn.microsoft.com/en-us/azure/container-apps/firewall-integration#nsg-allow-rules
resource appsNsg 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: networkNsgAppsName
  location: location
  tags: tags
  properties: {
    securityRules: [
      // Inbound rules
      {
        name: 'AllowInternetHttpInbound'
        properties: {
          priority: 1010
          direction: 'Inbound'
          description: 'Required for public HTTP->HTTPS redirects'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
          protocol: 'TCP'
          access: 'Allow'
        }
      }
      {
        name: 'AllowInternetHttpsInbound'
        properties: {
          priority: 1020
          direction: 'Inbound'
          description: 'Required for public HTTPS ingress'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
          protocol: 'TCP'
          access: 'Allow'
        }
      }
      // Outbound rules
      {
        // https://azure.github.io/PSRule.Rules.Azure/en/rules/Azure.NSG.LateralTraversal/
        name: 'DenyRemoteAccessOutbound'
        properties: {
          priority: 2010
          direction: 'Outbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: [
            '22'
            '3389'
          ]
          protocol: 'TCP'
          access: 'Deny'
        }
      }
    ]
  }
}

resource appsNsgDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagnosticSettingsName
  scope: appsNsg
  properties: {
    workspaceId: platformLogs.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-09-01' = {
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
          networkSecurityGroup: {
            id: appsNsg.id
          }
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
