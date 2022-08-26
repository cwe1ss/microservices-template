targetScope = 'subscription'

param now string = utcNow()
param environment string
param serviceName string
param imageTag string

var config = loadJsonContent('./_config.json')
var env = config.environments[environment]
var svcConfig = env.services[serviceName]

// Resource names

var svcGroupName = '${env.environmentResourcePrefix}-svc-${serviceName}'

var tags = {
  product: config.platformResourcePrefix
  environment: env.environmentResourcePrefix
  service: serviceName
}

// Existing resources

var platformGroup = resourceGroup('${config.platformResourcePrefix}-platform')
var sqlGroup = resourceGroup('${env.environmentResourcePrefix}-sql')

// New resources

resource svcGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: svcGroupName
  location: config.location
  tags: tags
}

// Create the user assigned identity first, so that we can assign permissions to it before the rest of the service resources is created
module svcIdentity 'service-identity.bicep' = {
  name: 'svcIdentity-${now}'
  scope: svcGroup
  params: {
    environment: environment
    serviceName: serviceName
    tags: tags
  }
}

// Allow the identity to access the platform container registry.
// This must be done before we can create the actual container app, as the deployment would fail otherwise.
module svcIdentityAssignment 'service-platform-assignments.bicep' = {
  name: 'svcIdentityAssignment-${now}'
  scope: platformGroup
  dependsOn: [
    svcIdentity
  ]
  params: {
    environment: environment
    serviceName: serviceName
  }
}

module svcSql 'service-sql.bicep' = if (svcConfig.sqlDatabase.enabled) {
  name: 'svcSql-${now}'
  scope: sqlGroup
  params: {
    environment: environment
    serviceName: serviceName
    tags: tags
  }
}

module svcResources 'service-resources.bicep' = {
  name: 'svcResources-${now}'
  scope: svcGroup
  dependsOn: [
    svcIdentityAssignment
    svcSql
  ]
  params: {
    environment: environment
    serviceName: serviceName
    imageTag: imageTag
    tags: tags
  }
}
