// Contains the main entry point for deploying all Azure resources required by one service.

targetScope = 'subscription'

param now string = utcNow()
param environment string
param serviceName string
param buildNumber string

// Configuration

var config = loadJsonContent('./_config.json')
var env = config.environments[environment]
var svcConfig = env.services[serviceName]

// Naming conventions

var platformGroupName = '${config.platformResourcePrefix}-platform'
var envGroupName = '${env.environmentResourcePrefix}-env'
var serviceBusGroupName = '${env.environmentResourcePrefix}-bus'
var sqlGroupName = '${env.environmentResourcePrefix}-sql'
var svcGroupName = '${env.environmentResourcePrefix}-svc-${serviceName}'

var tags = {
  product: config.platformResourcePrefix
  environment: env.environmentResourcePrefix
  service: serviceName
}

// Existing resources

var platformGroup = resourceGroup(platformGroupName)
var envGroup = resourceGroup(envGroupName)
var serviceBusGroup = resourceGroup(serviceBusGroupName)
var sqlGroup = resourceGroup(sqlGroupName)

// New resources

resource svcGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: svcGroupName
  location: config.location
  tags: tags
}

// Create the user assigned identity first, so that we can assign permissions to it before the rest of the service resources is created
module svcIdentity 'service-identity.bicep' = {
  name: 'svc-identity-${now}'
  scope: svcGroup
  params: {
    environment: environment
    serviceName: serviceName
    tags: tags
  }
}

// Allow the identity to access the platform container registry.
// This must be done before we can create the actual container app, as the deployment would fail otherwise.
module svcPlatform 'service-platform.bicep' = {
  name: 'svc-platform-${now}'
  scope: platformGroup
  dependsOn: [
    svcIdentity
  ]
  params: {
    environment: environment
    serviceName: serviceName
  }
}

module svcServiceBus 'service-servicebus.bicep' = if (svcConfig.serviceBus.enabled) {
  name: 'svc-bus-${now}'
  scope: serviceBusGroup
  dependsOn: [
    svcIdentity
  ]
  params: {
    environment: environment
    serviceName: serviceName
  }
}

module svcSql 'service-sql.bicep' = if (svcConfig.sqlDatabase.enabled) {
  name: 'svc-sql-${now}'
  scope: sqlGroup
  params: {
    environment: environment
    serviceName: serviceName
    buildNumber: buildNumber
    tags: tags
  }
}

module svcEnv 'service-environment.bicep' = {
  name: 'svc-env-${now}'
  scope: envGroup
  dependsOn: [
    svcIdentity
    svcServiceBus
  ]
  params: {
    environment: environment
    serviceName: serviceName
  }
}

module svcResources 'service-resources.bicep' = {
  name: 'svc-resources-${now}'
  scope: svcGroup
  dependsOn: [
    svcPlatform
    svcServiceBus
    svcSql
    svcEnv
  ]
  params: {
    environment: environment
    serviceName: serviceName
    buildNumber: buildNumber
    tags: tags
  }
}
