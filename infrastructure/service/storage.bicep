param location string
param tags object


///////////////////////////////////
// Resource names

param networkGroupName string
param networkVnetName string
param networkSubnetAppsName string
param svcGroupName string
param svcUserName string
param svcStorageAccountName string
param svcStorageDataProtectionContainerName string


///////////////////////////////////
// Existing resources

var networkGroup = resourceGroup(networkGroupName)
var svcGroup = resourceGroup(svcGroupName)

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

@description('This is the built-in Storage Blob Data Contributor role. See https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor ')
resource storageBlobDataContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}


///////////////////////////////////
// New resources

resource svcStorageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: svcStorageAccountName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_ZRS'
  }
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'None'
      virtualNetworkRules: [
        {
          id: networkSubnetApps.id
        }
      ]
    }
  }

  resource blobServices 'blobServices' = {
    name: 'default'
    properties: {
      deleteRetentionPolicy: {
        enabled: true
        allowPermanentDelete: true
        days: 7
      }
    }
  }
}

@description('A blob container that will be used to store the ASP.NET Core Data Protection keys')
resource dataProtectionContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  name: '${svcStorageAccount.name}/default/${svcStorageDataProtectionContainerName}'
  properties: {
    publicAccess: 'None'
  }
}

@description('Allows the service user to manage the Data Protection keys and any other blobs the service might require')
resource svcUserblobContributer 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('svcUserBlobContributor', svcStorageAccount.id, svcUser.id)
  scope: svcStorageAccount
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleDefinition.id
    principalId: svcUser.properties.principalId
    principalType: 'ServicePrincipal'
  }
}


output storageBlobPrimaryEndpoint string = svcStorageAccount.properties.primaryEndpoints.blob
output dataProtectionBlobUri string = '${svcStorageAccount.properties.primaryEndpoints.blob}${svcStorageDataProtectionContainerName}/keys.xml'
