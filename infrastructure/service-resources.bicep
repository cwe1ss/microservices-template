param location string = resourceGroup().location
param platformResourcePrefix string
param environmentResourcePrefix string
param serviceName string

resource env 'Microsoft.App/managedEnvironments@2022-03-01' existing = {
  name: '${environmentResourcePrefix}-env'
  scope: resourceGroup('${environmentResourcePrefix}-env')
}

resource app 'Microsoft.App/containerApps@2022-03-01' = {
  name: '${environmentResourcePrefix}-svc-${serviceName}'
  location: location
  properties: {
    managedEnvironmentId: env.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
      }
    }
    template: {
      containers: [
        {
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          name: 'app'
          resources: {
            cpu: '0.5'
            memory: '1.0Gi'
          }
        }
      ]
    }
  }
  tags: {
    product: platformResourcePrefix
    environment: environmentResourcePrefix
  }
}
