param location string
param tags object


///////////////////////////////////
// Resource names

param platformGroupName string
param platformLogsName string
param diagnosticSettingsName string
param networkGroupName string
param networkVnetName string
param networkSubnetAppsName string
param svcGroupName string
param svcUserName string
param svcVaultName string
param svcVaultDataProtectionKeyName string


///////////////////////////////////
// Existing resources

var platformGroup = resourceGroup(platformGroupName)
var networkGroup = resourceGroup(networkGroupName)
var svcGroup = resourceGroup(svcGroupName)

resource platformLogs 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: platformLogsName
  scope: platformGroup
}

resource networkVnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: networkVnetName
  scope: networkGroup
}

resource networkSubnetApps 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  name: networkSubnetAppsName
  parent: networkVnet
}

resource svcUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: svcUserName
  scope: svcGroup
}

@description('This is the built-in "Key Vault Crypto User" role. See https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-crypto-user ')
resource keyVaultCryptoUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '12338af0-0e69-4776-bea7-57ae8d297424'
}

@description('This is the built-in "Key Vault Secrets User" role. See https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-secrets-user ')
resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}


///////////////////////////////////
// New resources

resource vault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: svcVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 30
    publicNetworkAccess: 'enabled'   // TODO disable public network access
    networkAcls: {
      bypass: 'None'
      virtualNetworkRules: [
        {
          id: networkSubnetApps.id
        }
      ]
    }
  }
}

// https://learn.microsoft.com/en-us/azure/key-vault/key-vault-insights-overview
// Persists all Key Vault logs for auditing and enables the logs-based visualizations for Key Vault Insights.
resource vaultDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagnosticSettingsName
  scope: vault
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

resource dataProtectionKey 'Microsoft.KeyVault/vaults/keys@2022-07-01' = {
  name: svcVaultDataProtectionKeyName
  parent: vault
  tags: tags
  properties: {
    kty: 'RSA'
    keySize: 2048
  }
}

@description('Allows the service user to READ secrets')
resource svcUserKeyVaultUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('keyVaultSecretUser', svcUser.id)
  scope: vault
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: svcUser.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('Allows the service user to USE the keys')
resource svcUserCryptoUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('keyVaultCryptoUser', svcUser.id)
  scope: vault
  properties: {
    roleDefinitionId: keyVaultCryptoUserRole.id
    principalId: svcUser.properties.principalId
    principalType: 'ServicePrincipal'
  }
}


output keyVaultUri string = vault.properties.vaultUri
output dataProtectionKeyUri string = dataProtectionKey.properties.keyUri
