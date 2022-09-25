targetScope = 'subscription'

param now string = utcNow()

param githubRepoNameWithOwner string
param githubDefaultBranchName string


///////////////////////////////////
// Configuration

var config = loadJsonContent('./../config.json')

var tags = {
  product: config.platformAbbreviation
}


///////////////////////////////////
// Resource names

var platformGroupName = '${config.platformAbbreviation}-platform'
var githubIdentityName = '${config.platformAbbreviation}-github'


///////////////////////////////////
// Existing resources

@description('This is the built-in Contributor role. See https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#contributor ')
resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

@description('This is the built-in "User Access Administrator" role. See https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#user-access-administrator ')
resource userAccessAdministratorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9'
}


///////////////////////////////////
// New resources

@description('The platform group contains environment-independent resources')
resource platformGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: platformGroupName
  location: config.location
  tags: tags
}

@description('The managed identity that will be used by GitHub to deploy Azure resources')
module githubIdentity 'github-identity-resources.bicep' = {
  name: 'init-gh-${now}'
  scope: platformGroup
  params: {
    location: config.location
    tags: tags
    githubRepoNameWithOwner: githubRepoNameWithOwner
    githubDefaultBranchName: githubDefaultBranchName

    // Resource names
    githubIdentityName: githubIdentityName
  }
}

@description('The managed identity must be able to create & modify Azure resources in the subscription')
resource githubIdentityContributor 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().id, 'github', 'Contributor')
  properties: {
    roleDefinitionId: contributorRoleDefinition.id
    principalId: githubIdentity.outputs.githubIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

@description('The managed identity must be able to assign roles to other managed identities')
resource githubIdentityUserAccessAdministrator 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().id, 'github', 'UserAccessAdministrator')
  properties: {
    roleDefinitionId: userAccessAdministratorRoleDefinition.id
    principalId: githubIdentity.outputs.githubIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}


///////////////////////////////////
// Outputs

output githubIdentityClientId string = githubIdentity.outputs.githubIdentityClientId
output githubIdentityPrincipalId string = githubIdentity.outputs.githubIdentityPrincipalId
