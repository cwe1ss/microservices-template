param location string
param tags object
param githubRepoNameWithOwner string


///////////////////////////////////
// Resource names

param githubIdentityName string


///////////////////////////////////
// Configuration

var config = loadJsonContent('./../config.json')

var environmentArray = items(config.environments)
var githubEnvironments = concat(environmentArray, [ { key: 'platform', value: {}}])


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
resource environmentCredentials 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2022-01-31-preview' = [for environment in githubEnvironments: {
  name: 'github-env-${environment.key}'
  parent: githubIdentity
  properties: {
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:${githubRepoNameWithOwner}:environment:${environment.key}'
  }
}]


///////////////////////////////////
// Outputs

output githubIdentityClientId string = githubIdentity.properties.clientId
output githubIdentityPrincipalId string = githubIdentity.properties.principalId
