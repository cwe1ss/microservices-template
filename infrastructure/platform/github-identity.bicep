targetScope = 'subscription'

param now string = utcNow()
param tags object
param githubRepoNameWithOwner string
param githubDefaultBranchName string

// Resource names
param platformGroupName string
param githubIdentityName string


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

resource platformGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: platformGroupName
}


///////////////////////////////////
// New resources

@description('The managed identity that will be used by GitHub to deploy Azure resources')
module githubIdentity 'github-identity-resources.bicep' = {
  name: 'platform-github-${now}'
  scope: platformGroup
  params: {
    location: platformGroup.location
    tags: tags
    githubRepoNameWithOwner: githubRepoNameWithOwner
    githubDefaultBranchName: githubDefaultBranchName

    // Resource names
    githubIdentityName: githubIdentityName
  }
}

@description('The managed identity must be able to create & modify Azure resources in the subscription')
resource githubIdentityContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, 'github', 'Contributor')
  properties: {
    roleDefinitionId: contributorRoleDefinition.id
    principalId: githubIdentity.outputs.githubIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

@description('The managed identity must be able to assign roles to other managed identities')
resource githubIdentityUserAccessAdministrator 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
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
