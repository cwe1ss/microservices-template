param environment string
param serviceName string
param tags object

var config = loadJsonContent('./_config.json')
var env = config.environments[environment]

// Resource names

var svcUserName = '${env.environmentResourcePrefix}-svc-${serviceName}'

// New resources

resource svcUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: svcUserName
  location: config.location
  tags: tags
}
