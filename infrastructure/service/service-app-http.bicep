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

var config = loadJsonContent('./../config.json')
var envConfig = config.environments[environment]
var serviceDefaults = config.services[serviceName]
var serviceConfig = envConfig.services[serviceName]


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

var fullImageName = '${containerRegistry.properties.loginServer}/${config.platformResourcePrefix}-${serviceName}:${buildNumber}'
var sqlConnectionString = serviceDefaults.sqlDatabaseEnabled ? 'Server=${sqlServer.properties.fullyQualifiedDomainName};Database=${database.name};User Id=${svcUser.properties.clientId};Authentication=Active Directory Managed Identity;Connect Timeout=60' : ''


///////////////////////////////////
// New resources

// TODO: It's not currently possible to dynamically create the environment variables array.
// https://github.com/microsoft/azure-container-apps/issues/391

resource containerApp 'Microsoft.App/containerApps@2022-03-01' = {
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
        appPort: 80
        appProtocol: 'http'
        enabled: true
      }
      ingress: {
        external: true
        targetPort: 80
        transport: 'auto'
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
            cpu: serviceConfig.app.cpu
            memory: serviceConfig.app.memory
          }
          probes: [
            {
              type: 'Startup'
              httpGet: {
                path: '/healthz/startup'
                port: 80
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
                port: 80
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
              // Will not actually be set if sqlConnectionString is empty
              name: 'ASPNETCORE_CONNECTIONSTRINGS__SQL'
              value: sqlConnectionString
            }
            // TODO: This creates separate fields for each JSON property in the "ContainerAppConsoleLogs_CL" table, so we keep the regular output for now.
            // https://github.com/microsoft/azure-container-apps/issues/393
            // {
            //   // Console logs are sent to Azure Monitor. The default console logger outputs statements to multiple lines, so we use JSON instead.
            //   // https://docs.microsoft.com/en-us/dotnet/core/extensions/console-log-formatter#json
            //   name: 'Logging__Console__FormatterName'
            //   value: 'json'
            // }
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
        minReplicas: serviceConfig.app.minReplicas
        maxReplicas: serviceConfig.app.maxReplicas
      }
    }
  }
}
