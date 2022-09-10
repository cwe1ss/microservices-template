param location string
param tags object


///////////////////////////////////
// Resource names

param networkGroupName string
param vnetName string
param appsSubnetName string
param svcGroupName string
param svcUserName string
param svcStorageAccountName string
param svcStorageDataProtectionContainerName string


///////////////////////////////////
// Existing resources

var networkGroup = resourceGroup(networkGroupName)
var svcGroup = resourceGroup(svcGroupName)

resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: vnetName
  scope: networkGroup
}

resource appsSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  name: appsSubnetName
  parent: vnet
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

resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: svcStorageAccountName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'None'
      virtualNetworkRules: [
        {
          id: appsSubnet.id
        }
      ]
    }
  }
}

@description('A blob container that will be used to store the ASP.NET Core Data Protection keys')
resource dataProtectionContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  name: '${storage.name}/default/${svcStorageDataProtectionContainerName}'
  properties: {
    publicAccess: 'None'
  }
}

@description('Allows the service user to manage the Data Protection keys and any other blobs the service might require')
resource svcUserblobContributer 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('svcUserBlobContributor', storage.id, svcUser.id)
  scope: storage
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleDefinition.id
    principalId: svcUser.properties.principalId
    principalType: 'ServicePrincipal'
  }
}


output storageBlobPrimaryEndpoint string = storage.properties.primaryEndpoints.blob
output dataProtectionBlobUri string = '${storage.properties.primaryEndpoints.blob}${svcStorageDataProtectionContainerName}/keys.xml'
