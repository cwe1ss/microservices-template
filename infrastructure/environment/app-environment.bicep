// Deploys the "Container Apps Environment".
// The "container app" for each service will be deployed into its own resource group by the service.
//
// The following resources will be deployed:
// * An "Azure Container Apps environment", used to store all service apps.

param location string
param tags object


///////////////////////////////////
// Resource names

param platformGroupName string
param platformLogsName string
param diagnosticSettingsName string
param networkGroupName string
param networkVnetName string
param networkSubnetAppsName string
param monitoringGroupName string
param monitoringAppInsightsName string
param appEnvName string


///////////////////////////////////
// Existing resources

var platformGroup = resourceGroup(platformGroupName)
var networkGroup = resourceGroup(networkGroupName)
var monitoringGroup = resourceGroup(monitoringGroupName)

resource platformLogs 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: platformLogsName
  scope: platformGroup
}

resource networkVnet 'Microsoft.Network/virtualNetworks@2022-09-01' existing = {
  name: networkVnetName
  scope: networkGroup
}

resource networkSubnetApps 'Microsoft.Network/virtualNetworks/subnets@2022-09-01' existing = {
  name: networkSubnetAppsName
  parent: networkVnet
}

resource monitoringAppInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: monitoringAppInsightsName
  scope: monitoringGroup
}


///////////////////////////////////
// New resources

resource appEnv 'Microsoft.App/managedEnvironments@2022-10-01' = {
  name: appEnvName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'azure-monitor'
    }
    daprAIConnectionString: monitoringAppInsights.properties.ConnectionString
    daprAIInstrumentationKey: monitoringAppInsights.properties.InstrumentationKey
    vnetConfiguration: {
      internal: false
      infrastructureSubnetId: networkSubnetApps.id
    }
  }
}

resource appEnvDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagnosticSettingsName
  scope: appEnv
  properties: {
    workspaceId: platformLogs.id
    logs: [
      {
        category: 'ContainerAppConsoleLogs'
        enabled: true
      }
      {
        category: 'ContainerAppSystemLogs'
        enabled: true
      }
    ]
  }
}
