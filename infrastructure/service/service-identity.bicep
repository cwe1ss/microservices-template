param location string
param tags object


///////////////////////////////////
// Resource names

param svcUserName string


///////////////////////////////////
// New resources

resource svcUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: svcUserName
  location: location
  tags: tags
}
