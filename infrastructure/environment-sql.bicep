param environment string
param tags object
param sqlAdminAdGroupName string
param sqlAdminAdGroupId string

// Configuration

var config = loadJsonContent('./_config.json')
var env = config.environments[environment]

// Naming conventions

var envGroupName = '${env.environmentResourcePrefix}-env'
var vnetName = '${env.environmentResourcePrefix}-vnet'
var sqlServerUserId = '${env.environmentResourcePrefix}-sql'
var sqlServerName = '${env.environmentResourcePrefix}-sql'

// Existing resources

var envGroup = resourceGroup(envGroupName)

resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: vnetName
  scope: envGroup
}

resource acaInfrastructureSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  name: 'aca-infrastructure'
  parent: vnet
}

// New resources

resource sqlServerUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: sqlServerUserId
  location: config.location
  tags: tags
}

resource sqlServer 'Microsoft.Sql/servers@2022-02-01-preview' = {
  name: sqlServerName
  location: config.location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${sqlServerUser.id}': {}
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
    primaryUserAssignedIdentityId: sqlServerUser.id
    publicNetworkAccess: 'Enabled'
  }
  tags: tags
}

resource infrastructureVnetRule 'Microsoft.Sql/servers/virtualNetworkRules@2022-02-01-preview' = {
  name: 'aca-infrastructure'
  parent: sqlServer
  properties: {
    ignoreMissingVnetServiceEndpoint: false
    virtualNetworkSubnetId: acaInfrastructureSubnet.id
  }
}
