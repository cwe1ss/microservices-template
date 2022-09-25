param location string
param tags object
param githubRepoNameWithOwner string
param githubDefaultBranchName string


///////////////////////////////////
// Resource names

param githubIdentityName string


///////////////////////////////////
// Configuration

var config = loadJsonContent('./../config.json')

// All credentials must be in one list as concurrent writes to /federatedIdentityCredentials are not allowed.
var ghBranchCredentials = [{
  name: 'github-branch-${githubDefaultBranchName}'
  subject: 'repo:${githubRepoNameWithOwner}:ref:refs/heads/${githubDefaultBranchName}'
}]
var ghPlatformCredentials = [{
  name: 'github-env-platform'
  subject: 'repo:${githubRepoNameWithOwner}:environment:platform'
}]
var ghEnvironmentCredentials = [for item in items(config.environments): {
  name: 'github-env-${item.key}'
  subject: 'repo:${githubRepoNameWithOwner}:environment:${item.key}'
}]
var githubCredentials = concat(ghBranchCredentials, ghPlatformCredentials, ghEnvironmentCredentials)


///////////////////////////////////
// New resources

resource githubIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: githubIdentityName
  location: location
  tags: tags
}

// Writing more than one credential concurrently fails with the following error:
// "Concurrent Federated Identity Credentials writes under the same managed identity are not supported"
// ErrorCode: "ConcurrentFederatedIdentityCredentialsWritesForSingleManagedIdentity"
@batchSize(1)
@description('Allows GitHub Actions to deploy from any of the configured environments')
resource federatedCredentials 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2022-01-31-preview' = [for item in githubCredentials: {
  name: item.name
  parent: githubIdentity
  properties: {
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: 'https://token.actions.githubusercontent.com'
    subject: item.subject
  }
}]


///////////////////////////////////
// Outputs

output githubIdentityClientId string = githubIdentity.properties.clientId
output githubIdentityPrincipalId string = githubIdentity.properties.principalId
