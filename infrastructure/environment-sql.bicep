param location string = resourceGroup().location
param platformResourcePrefix string
param environmentResourcePrefix string
param sqlAdminAdGroup string
param sqlAdminAdGroupId string

resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: '${environmentResourcePrefix}-vnet'
  scope: resourceGroup('${environmentResourcePrefix}-env')
}

resource acaInfrastructureSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  name: '${environmentResourcePrefix}-infrastructure'
  parent: vnet
}

resource acaRuntimeSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  name: '${environmentResourcePrefix}-apps'
  parent: vnet
}

resource sqlUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: '${environmentResourcePrefix}-sql'
  location: location
  tags: {
    product: platformResourcePrefix
    environment: environmentResourcePrefix
  }
}

resource sqlServer 'Microsoft.Sql/servers@2022-02-01-preview' = {
  name: '${environmentResourcePrefix}-sql'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${sqlUser.id}': {}
    }
  }
  properties: {
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      principalType: 'Group'
      login: sqlAdminAdGroup
      sid: sqlAdminAdGroupId
      tenantId: subscription().tenantId
    }
    minimalTlsVersion: '1.2'
    primaryUserAssignedIdentityId: sqlUser.id
    publicNetworkAccess: 'Enabled'
  }
  tags: {
    product: platformResourcePrefix
    environment: environmentResourcePrefix
  }
}

resource infrastructureVnetRule 'Microsoft.Sql/servers/virtualNetworkRules@2022-02-01-preview' = {
  name: 'aca-infrastructure'
  parent: sqlServer
  properties: {
    ignoreMissingVnetServiceEndpoint: false
    virtualNetworkSubnetId: acaInfrastructureSubnet.id
  }
}

resource appsVnetRule 'Microsoft.Sql/servers/virtualNetworkRules@2022-02-01-preview' = {
  name: 'aca-apps'
  parent: sqlServer
  properties: {
    ignoreMissingVnetServiceEndpoint: false
    virtualNetworkSubnetId: acaRuntimeSubnet.id
  }
}


resource database 'Microsoft.Sql/servers/databases@2022-02-01-preview' = {
  name: 'customers'
  parent: sqlServer
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  }
  properties: {

  }
  tags: {
    product: platformResourcePrefix
    environment: environmentResourcePrefix
  }
}
