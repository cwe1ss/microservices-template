param location string
param environment string
param serviceName string
param tags object


///////////////////////////////////
// Resource names

param platformGroupName string
param platformContainerRegistryName string
param appEnvGroupName string
param appEnvName string
param sqlGroupName string
param sqlServerName string
param sqlDatabaseName string
param monitoringGroupName string
param monitoringAppInsightsName string
param svcUserName string
param svcAppName string
param svcArtifactContainerImageWithTag string


///////////////////////////////////
// Configuration

var config = loadJsonContent('./../config.json')
var envConfig = config.environments[environment]
var serviceDefaults = config.services[serviceName]
var serviceConfig = envConfig.services[serviceName]


///////////////////////////////////
// Existing resources

var platformGroup = resourceGroup(platformGroupName)
var envGroup = resourceGroup(appEnvGroupName)
var monitoringGroup = resourceGroup(monitoringGroupName)
var sqlGroup = resourceGroup(sqlGroupName)

resource platformContainerRegistry 'Microsoft.ContainerRegistry/registries@2021-09-01' existing = {
  name: platformContainerRegistryName
  scope: platformGroup
}

resource appEnv 'Microsoft.App/managedEnvironments@2022-03-01' existing = {
  name: appEnvName
  scope: envGroup
}

resource monitoringAppInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: monitoringAppInsightsName
  scope: monitoringGroup
}

resource sqlServer 'Microsoft.Sql/servers@2022-02-01-preview' existing = {
  name: sqlServerName
  scope: sqlGroup
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-02-01-preview' existing = {
  name: sqlDatabaseName
  scope: sqlGroup
}

resource svcUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: svcUserName
}


///////////////////////////////////
// Configuration values

var sqlDatabaseEnabled = contains(serviceDefaults, 'sqlDatabaseEnabled') ? serviceDefaults.sqlDatabaseEnabled : false
var sqlConnectionString = sqlDatabaseEnabled ? 'Server=${sqlServer.properties.fullyQualifiedDomainName};Database=${sqlDatabase.name};User Id=${svcUser.properties.clientId};Authentication=Active Directory Managed Identity;Connect Timeout=60' : ''


///////////////////////////////////
// New resources

// TODO: It's not currently possible to dynamically create the environment variables array.
// https://github.com/microsoft/azure-container-apps/issues/391

resource containerApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: svcAppName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
     '${svcUser.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: appEnv.id
    configuration: {
      dapr: {
        appId: serviceName
        appPort: 80
        appProtocol: 'grpc'
        enabled: true
      }
      ingress: {
        external: contains(serviceConfig, 'ingressExternal') ? serviceConfig.ingressExternal : false
        targetPort: 80
        transport: 'http2'
      }
      registries: [
        {
          server: platformContainerRegistry.properties.loginServer
          identity: svcUser.id
        }
      ]
      secrets: [
      ]
    }
    template: {
      containers: [
        {
          image: '${platformContainerRegistry.properties.loginServer}/${svcArtifactContainerImageWithTag}'
          name: 'app'
          resources: {
            // TODO: Bicep expects an int even though a string is required. Remove any() if that ever changes.
            cpu: any(contains(serviceConfig, 'app') && contains(serviceConfig.app, 'cpu') ? '${serviceConfig.app.cpu}' : '0.25')
            memory: contains(serviceConfig, 'app') && contains(serviceConfig.app, 'memory') ? '${serviceConfig.app.memory}' : '0.5Gi'
          }
          probes: [
            {
              type: 'Startup'
              httpGet: {
                path: '/healthz/startup'
                port: 8080
                scheme: 'HTTP'
              }
              initialDelaySeconds: 2
              periodSeconds: 2
              failureThreshold: 10
            }
            {
              type: 'Liveness'
              httpGet: {
                path: '/healthz/liveness'
                port: 8080
                scheme: 'HTTP'
              }
              periodSeconds: 10
              failureThreshold: 3
            }
          ]
          env: [
            {
              // https://docs.dapr.io/reference/environment/
              // This is used to set the service name in Application Insights
              name: 'APP_ID'
              value: serviceName
            }
            {
              // The Azure.Identity SDK needs the "ClientId" for the user-assigned identity, even if there is just one:
              // https://github.com/Azure/azure-sdk-for-net/issues/11400#issuecomment-620179175
              // If we don't set this, the authentication fails with the following error: https://github.com/Azure/azure-sdk-for-net/issues/13564
              name: 'AZURE_CLIENT_ID'
              value: svcUser.properties.clientId
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: monitoringAppInsights.properties.ConnectionString
            }
            {
              // Will not actually be set if sqlConnectionString is empty
              name: 'ASPNETCORE_CONNECTIONSTRINGS__SQL'
              value: sqlConnectionString
            }
            {
              name: 'ASPNETCORE_Kestrel__Endpoints__GRPC__Protocols'
              value: 'Http2'
            }
            {
              name: 'ASPNETCORE_Kestrel__Endpoints__GRPC__URL'
              value: 'http://*:80'
            }
            {
              name: 'ASPNETCORE_Kestrel__Endpoints__WEB__Protocols'
              value: 'Http1'
            }
            {
              name: 'ASPNETCORE_Kestrel__Endpoints__WEB__URL'
              value: 'http://*:8080'
            }
            {
              // Console logs are sent to Azure Monitor. The default console logger outputs statements to multiple lines, so we use JSON instead.
              // https://docs.microsoft.com/en-us/dotnet/core/extensions/console-log-formatter#json
              name: 'Logging__Console__FormatterName'
              value: 'json'
            }
            {
              // Apps use the Application Insights SDK to log requests and exceptions, so we don't need to output anything to the console.
              name: 'Logging__Console__LogLevel__Default'
              value: 'Critical'
            }
            {
              // For troubleshooting purposes, we do however output app start/shutdown events.
              name: 'Logging__Console__LogLevel__Microsoft.Hosting.Lifetime'
              value: 'Information'
            }
          ]
        }
      ]
      scale: {
        minReplicas: contains(serviceConfig, 'app') && contains(serviceConfig.app, 'minReplicas') ? serviceConfig.app.minReplicas : 0
        maxReplicas: contains(serviceConfig, 'app') && contains(serviceConfig.app, 'maxReplicas') ? serviceConfig.app.maxReplicas : 10 // Azure default value
        rules: [
          {
            name: 'http-rule'
            http: {
              metadata: {
                // https://docs.microsoft.com/en-us/azure/container-apps/scale-app#http
                // Value must be a string, otherwise it fails with error "ContainerAppInvalidSchema"
                concurrentRequests: contains(serviceConfig, 'app') && contains(serviceConfig.app, 'concurrentRequests') ? '${serviceConfig.app.concurrentRequests}' : '10' // Azure default value
              }
            }
          }
        ]
      }
    }
  }
}
