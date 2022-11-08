param now string = utcNow()
param location string
param environment string
param tags object


///////////////////////////////////
// Resource names

param platformGroupName string
param platformLogsName string
param diagnosticSettingsName string
param appConfigStoreName string


///////////////////////////////////
// Configuration

var config = loadJsonContent('./../config.json')
var envConfig = config.environments[environment]

var appsettings = loadJsonContent('./../appsettings.json')


///////////////////////////////////
// Existing resources

var platformGroup = resourceGroup(platformGroupName)

resource platformLogs 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: platformLogsName
  scope: platformGroup
}


///////////////////////////////////
// New resources

resource appConfigStore 'Microsoft.AppConfiguration/configurationStores@2022-05-01' = {
  name: appConfigStoreName
  location: location
  tags: tags
  sku: {
    name: contains(envConfig, 'appConfigSku') ? envConfig.appConfigSku : 'free'
  }
  properties: {
    disableLocalAuth: false // TODO If we disable local auth, then we can't create the keys
  }
}

resource appConfigStoreDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagnosticSettingsName
  scope: appConfigStore
  properties: {
    workspaceId: platformLogs.id
    logs: [
      {
        category: 'HttpRequest'
        enabled: true
      }
      {
        category: 'Audit'
        enabled: true
      }
    ]
  }
}

// We trigger a refresh in the apps whenever the environment is deployed.
// https://learn.microsoft.com/en-us/azure/azure-app-configuration/enable-dynamic-configuration-aspnet-core?tabs=core6x#add-a-sentinel-key
resource sentinelKey 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = {
  name: 'Sentinel'
  parent: appConfigStore
  properties: {
    value: now
  }
}

resource keyValues 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = [for item in items(appsettings.keys): {
  name: item.key
  parent: appConfigStore
  properties: {
    contentType: contains(item.value, 'contentType') ? item.value.contentType : null
    value: contains(item.value, 'environments') && contains(item.value.environments, environment) ? string(item.value.environments[environment]) : string(item.value.value)
  }
}]

resource flags 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = [for item in items(appsettings.flags): {
  name: '.appconfig.featureflag~2F${item.key}'
  parent: appConfigStore
  properties: {
    contentType: 'application/vnd.microsoft.appconfig.ff+json;charset=utf-8'
    value: string({
#disable-next-line use-resource-id-functions
      id: item.key
      description: item.value.description
      enabled: contains(item.value, 'enabled') && contains(item.value.enabled, environment) ? item.value.enabled[environment] : false
      conditions: contains(item.value, 'conditions') ? item.value.conditions : null
    })
  }
}]
