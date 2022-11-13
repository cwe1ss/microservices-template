// The entire environment uses one shared SQL server instance.
// The necessary databases are added by the service deployments.

param location string
param tags object
param sqlAdminAdGroupId string


///////////////////////////////////
// Resource names

param platformGroupName string
param platformLogsName string
param diagnosticSettingsName string
param networkGroupName string
param networkVnetName string
param networkSubnetAppsName string
param sqlServerAdminUserName string
param sqlServerName string
param sqlAdminAdGroupName string


///////////////////////////////////
// Existing resources

var platformGroup = resourceGroup(platformGroupName)
var networkGroup = resourceGroup(networkGroupName)

resource platformLogs 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: platformLogsName
  scope: platformGroup
}

resource networkVnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: networkVnetName
  scope: networkGroup
}

resource networkSubnetApps 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  name: networkSubnetAppsName
  parent: networkVnet
}

@description('The SQL identity must have been created beforehand via the init script.')
resource sqlServerAdminUser 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: sqlServerAdminUserName
}


///////////////////////////////////
// New resources

resource sqlServer 'Microsoft.Sql/servers@2022-02-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${sqlServerAdminUser.id}': {}
    }
  }
  properties: {
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      principalType: 'Group'
      login: sqlAdminAdGroupName
      sid: sqlAdminAdGroupId
      tenantId: subscription().tenantId
    }
    minimalTlsVersion: '1.2'
    primaryUserAssignedIdentityId: sqlServerAdminUser.id
    publicNetworkAccess: 'Enabled'
  }
}

@description('Allows apps from the Container Apps-subnet to access the SQL server')
resource appsVnetRule 'Microsoft.Sql/servers/virtualNetworkRules@2022-02-01-preview' = {
  name: networkSubnetAppsName
  parent: sqlServer
  properties: {
    ignoreMissingVnetServiceEndpoint: false
    virtualNetworkSubnetId: networkSubnetApps.id
  }
}

// TODO We currently need this because the container instances created by the deploymentScripts can not yet be joined to a VNET.
@description('Allows all Azure services to access the SQL server')
resource allowAllWindowsAzureIps 'Microsoft.Sql/servers/firewallRules@2020-11-01-preview' = {
  name: 'AllowAllWindowsAzureIps'
  parent: sqlServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource masterDb 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: sqlServer
  location: location
  name: 'master'
  properties: {
  }
}

resource masterDbDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagnosticSettingsName
  scope: masterDb
  properties: {
    workspaceId: platformLogs.id
    logs:[
      {
        category: 'SQLSecurityAuditEvents'
        enabled: true
      }
    ]
  }
}

resource sqlAudit 'Microsoft.Sql/servers/auditingSettings@2021-08-01-preview'= {
  name: 'default'
  parent: sqlServer
  properties:{
    auditActionsAndGroups:[
     'BATCH_COMPLETED_GROUP'
     'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
     'FAILED_DATABASE_AUTHENTICATION_GROUP'
    ]
    isAzureMonitorTargetEnabled: true
    state:'Enabled'
  }
}

@description('Enables Microsoft Defender for Azure SQL')
resource sqlSecurity 'Microsoft.Sql/servers/securityAlertPolicies@2022-05-01-preview' = {
  name: 'Default'
  parent: sqlServer
  properties: {
    state: 'Enabled'
    emailAccountAdmins: true
  }
}
