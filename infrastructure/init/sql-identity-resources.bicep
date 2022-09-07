param location string
param tags object

///////////////////////////////////
// Resource names

param sqlServerAdminUserName string


///////////////////////////////////
// New resources

resource sqlIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: sqlServerAdminUserName
  location: location
  tags: tags
}


///////////////////////////////////
// Outputs

output sqlIdentityClientId string = sqlIdentity.properties.clientId
output sqlIdentityPrincipalId string = sqlIdentity.properties.principalId
