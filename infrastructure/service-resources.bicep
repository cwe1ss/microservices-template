param location string = resourceGroup().location
param platformResourcePrefix string
param environmentResourcePrefix string
param serviceName string
param imageTag string

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

resource svcUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: '${environmentResourcePrefix}-svc-${serviceName}'
}

// New resources

var fullImageName = '${acr.properties.loginServer}/${platformResourcePrefix}-svc-${serviceName}:${imageTag}'

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
        appPort: 80
        appProtocol: 'grpc'
        enabled: true
      }
      ingress: {
        external: true
        targetPort: 80
        transport: 'http2'
      }
      registries: [
        {
          server: acr.properties.loginServer
          identity: svcUser.id
        }
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
          ]
        }
      ]
      scale: {
        minReplicas: 0
      }
    }
  }
  tags: {
    product: platformResourcePrefix
    environment: environmentResourcePrefix
  }
}
