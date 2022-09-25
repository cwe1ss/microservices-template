targetScope = 'subscription'

param now string = utcNow()
param environment string


///////////////////////////////////
// Configuration

var config = loadJsonContent('./../config.json')
var envConfig = config.environments[environment]

var tags = {
  product: config.platformAbbreviation
  environment: envConfig.environmentAbbreviation
}


///////////////////////////////////
// Resource names

var sqlGroupName = '${envConfig.environmentAbbreviation}-sql'
var sqlServerAdminUserName = '${envConfig.environmentAbbreviation}-sql-admin'


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
  name: 'init-sql-${now}'
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
