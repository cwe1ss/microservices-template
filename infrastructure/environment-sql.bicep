// The entire environment uses one shared SQL server instance.
// The necessary databases are added by the service deployments.

param environment string
param tags object
param sqlAdminAdGroupName string
param sqlAdminAdGroupId string

// Configuration

var config = loadJsonContent('./_config.json')
var env = config.environments[environment]

// Naming conventions

var networkGroupName = '${env.environmentResourcePrefix}-network'
var vnetName = '${env.environmentResourcePrefix}-vnet'
var appsSubnetName = 'apps'

var sqlServerAdminUserName = '${env.environmentResourcePrefix}-sql-admin'
var sqlServerName = '${env.environmentResourcePrefix}-sql'

// Existing resources

var networkGroup = resourceGroup(networkGroupName)

resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: vnetName
  scope: networkGroup
}

resource appsSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  name: appsSubnetName
  parent: vnet
}

// New resources

resource sqlServerAdminUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: sqlServerAdminUserName
  location: config.location
  tags: tags
}

resource sqlServer 'Microsoft.Sql/servers@2022-02-01-preview' = {
  name: sqlServerName
  location: config.location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${sqlServerAdminUser.id}': {}
    }
  }
  properties: {
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      principalType: 'Group'
      login: sqlAdminAdGroupName
      sid: sqlAdminAdGroupId
      tenantId: subscription().tenantId
    }
    minimalTlsVersion: '1.2'
    primaryUserAssignedIdentityId: sqlServerAdminUser.id
    publicNetworkAccess: 'Enabled'
  }
}

resource appsVnetRule 'Microsoft.Sql/servers/virtualNetworkRules@2022-02-01-preview' = {
  name: appsSubnetName
  parent: sqlServer
  properties: {
    ignoreMissingVnetServiceEndpoint: false
    virtualNetworkSubnetId: appsSubnet.id
  }
}

resource allowAllWindowsAzureIps 'Microsoft.Sql/servers/firewallRules@2020-11-01-preview' = {
  name: 'AllowAllWindowsAzureIps'
  parent: sqlServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}
