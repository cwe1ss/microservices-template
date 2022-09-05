param location string
param environment string
param serviceName string
param buildNumber string
param tags object


///////////////////////////////////
// Resource names

param platformGroupName string
param containerRegistryName string
param envGroupName string
param appEnvName string
param sqlGroupName string
param sqlServerName string
param appInsightsName string
param svcUserName string
param appName string
param sqlDatabaseName string


///////////////////////////////////
// Configuration

var config = loadJsonContent('./_config.json')
var env = config.environments[environment]
var svcConfig = env.services[serviceName]


///////////////////////////////////
// Existing resources

var platformGroup = resourceGroup(platformGroupName)
var envGroup = resourceGroup(envGroupName)
var sqlGroup = resourceGroup(sqlGroupName)

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-09-01' existing = {
  name: containerRegistryName
  scope: platformGroup
}

resource appEnv 'Microsoft.App/managedEnvironments@2022-03-01' existing = {
  name: appEnvName
  scope: envGroup
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
  scope: envGroup
}

resource sqlServer 'Microsoft.Sql/servers@2022-02-01-preview' existing = {
  name: sqlServerName
  scope: sqlGroup
}

resource database 'Microsoft.Sql/servers/databases@2022-02-01-preview' existing = {
  name: sqlDatabaseName
  scope: sqlGroup
}

resource svcUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: svcUserName
}


///////////////////////////////////
// Configuration values

var fullImageName = '${containerRegistry.properties.loginServer}/${config.platformResourcePrefix}-svc-${serviceName}:${buildNumber}'
var sqlConnectionString = svcConfig.sqlDatabase.enabled ? 'Server=${sqlServer.properties.fullyQualifiedDomainName};Database=${database.name};User Id=${svcUser.properties.clientId};Authentication=Active Directory Managed Identity;Connect Timeout=60' : ''
var grpcPort = 80
var http1Port = 8080


///////////////////////////////////
// New resources

resource app 'Microsoft.App/containerApps@2022-03-01' = {
  name: appName
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
        appPort: grpcPort
        appProtocol: 'grpc'
        enabled: true
      }
      ingress: {
        external: true
        targetPort: grpcPort
        transport: 'http2'
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: svcUser.id
        }
      ]
      secrets: [
      ]
    }
    template: {
      containers: [
        {
          image: fullImageName
          name: 'app'
          resources: {
            cpu: svcConfig.app.cpu
            memory: svcConfig.app.memory
          }
          probes: [
            {
              type: 'Startup'
              httpGet: {
                path: '/healthz/startup'
                port: http1Port
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
                port: http1Port
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
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsights.properties.ConnectionString
            }
            {
              name: 'ASPNETCORE_Kestrel__Endpoints__GRPC__Protocols'
              value: 'Http2'
            }
            {
              name: 'ASPNETCORE_Kestrel__Endpoints__GRPC__URL'
              value: 'http://*:${grpcPort}'
            }
            {
              name: 'ASPNETCORE_Kestrel__Endpoints__WEB__Protocols'
              value: 'Http1'
            }
            {
              name: 'ASPNETCORE_Kestrel__Endpoints__WEB__URL'
              value: 'http://*:${http1Port}'
            }
            {
              name: 'ASPNETCORE_CONNECTIONSTRINGS__SQL'
              value: sqlConnectionString
            }
          ]
        }
      ]
      scale: {
        minReplicas: svcConfig.app.minReplicas
        maxReplicas: svcConfig.app.maxReplicas
      }
    }
  }
}
