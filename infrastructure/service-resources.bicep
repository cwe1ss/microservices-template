param location string = resourceGroup().location
param platformResourcePrefix string
param environmentResourcePrefix string
param serviceName string
param imageTag string
param tags object

// Existing resources

resource acr 'Microsoft.ContainerRegistry/registries@2021-09-01' existing = {
  name: replace('${platformResourcePrefix}-registry', '-', '')
  scope: resourceGroup('${platformResourcePrefix}-platform')
}

resource env 'Microsoft.App/managedEnvironments@2022-03-01' existing = {
  name: '${environmentResourcePrefix}-env'
  scope: resourceGroup('${environmentResourcePrefix}-env')
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: '${environmentResourcePrefix}-appinsights'
  scope: resourceGroup('${environmentResourcePrefix}-env')
}

resource sqlServer 'Microsoft.Sql/servers@2022-02-01-preview' existing = {
  name: '${environmentResourcePrefix}-sql'
  scope: resourceGroup('${environmentResourcePrefix}-sql')
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-02-01-preview' existing = {
  name: serviceName
  parent: sqlServer
}

resource svcUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: '${environmentResourcePrefix}-svc-${serviceName}'
}

// New resources

var fullImageName = '${acr.properties.loginServer}/${platformResourcePrefix}-svc-${serviceName}:${imageTag}'
var grpcPort = 80
var http1Port = 8080

resource app 'Microsoft.App/containerApps@2022-03-01' = {
  name: '${environmentResourcePrefix}-svc-${serviceName}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
     '${svcUser.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: env.id
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
            cpu: '0.5'
            memory: '1.0Gi'
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
              // We use this to set the service name in Application Insights
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
              value: 'Server=${sqlServer.properties.fullyQualifiedDomainName};Database=${sqlDatabase.name};User Id=${svcUser.properties.clientId};Authentication=Active Directory Managed Identity;Connect Timeout=60'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
      }
    }
  }
  tags: tags
}
