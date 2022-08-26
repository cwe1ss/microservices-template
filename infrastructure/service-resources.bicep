param environment string
param serviceName string
param imageTag string
param tags object

var config = loadJsonContent('./_config.json')
var env = config.environments[environment]
var svcConfig = env.services[serviceName]

// Resource names

var acrName = replace('${config.platformResourcePrefix}-registry', '-', '')
var appEnvName = '${env.environmentResourcePrefix}-env'
var sqlServerName = '${env.environmentResourcePrefix}-sql'
var appInsightsName = '${env.environmentResourcePrefix}-appinsights'
var sqlDatabaseName = serviceName

var svcUserName = '${env.environmentResourcePrefix}-svc-${serviceName}'
var appName = '${env.environmentResourcePrefix}-svc-${serviceName}'

// Configuration values

var fullImageName = '${acr.properties.loginServer}/${config.platformResourcePrefix}-svc-${serviceName}:${imageTag}'
var grpcPort = 80
var http1Port = 8080

// Existing resources

var platformGroup = resourceGroup('${config.platformResourcePrefix}-platform')
var appEnvGroup = resourceGroup('${env.environmentResourcePrefix}-env')
var sqlGroup = resourceGroup('${env.environmentResourcePrefix}-sql')

resource acr 'Microsoft.ContainerRegistry/registries@2021-09-01' existing = {
  name: acrName
  scope: platformGroup
}

resource appEnv 'Microsoft.App/managedEnvironments@2022-03-01' existing = {
  name: appEnvName
  scope: appEnvGroup
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
  scope: appEnvGroup
}

resource sqlServer 'Microsoft.Sql/servers@2022-02-01-preview' existing = {
  name: sqlServerName
  scope: sqlGroup
}

resource svcUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: svcUserName
}

// New resources

var sqlConnectionString = svcConfig.sqlDatabase.enabled ? 'Server=${sqlServer.properties.fullyQualifiedDomainName};Database=${sqlDatabaseName};User Id=${svcUser.properties.clientId};Authentication=Active Directory Managed Identity;Connect Timeout=60' : ''

resource app 'Microsoft.App/containerApps@2022-03-01' = {
  name: appName
  location: config.location
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
          server: acr.properties.loginServer
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
            cpu: svcConfig.appCpu
            memory: svcConfig.appMemory
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
        minReplicas: svcConfig.appMinReplicas
        maxReplicas: svcConfig.appMaxReplicas
      }
    }
  }
  tags: tags
}
