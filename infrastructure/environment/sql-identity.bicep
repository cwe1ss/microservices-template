targetScope = 'subscription'

param now string = utcNow()
param environment string


///////////////////////////////////
// Configuration

var names = loadJsonContent('./../names.json')
var config = loadJsonContent('./../config.json')
var envConfig = config.environments[environment]

var tags = {
  product: config.platformAbbreviation
  environment: envConfig.environmentAbbreviation
}


///////////////////////////////////
// Resource names

var sqlGroupName = replace(names.sqlGroupName, '{environment}', envConfig.environmentAbbreviation)
var sqlServerAdminUserName = replace(names.sqlServerAdminName, '{environment}', envConfig.environmentAbbreviation)


///////////////////////////////////
// New resources

@description('The SQL group contains the SQL server, its identity and its databases')
resource sqlGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: sqlGroupName
  location: config.location
  tags: tags
}

@description('The managed identity that will be used by the SQL server')
module sqlIdentity 'sql-identity-resources.bicep' = {
  name: 'sql-${now}'
  scope: sqlGroup
  params: {
    location: config.location
    tags: tags

    // Resource names
    sqlServerAdminUserName: sqlServerAdminUserName
  }
}


///////////////////////////////////
// Outputs

output sqlIdentityClientId string = sqlIdentity.outputs.sqlIdentityClientId
output sqlIdentityPrincipalId string = sqlIdentity.outputs.sqlIdentityPrincipalId
