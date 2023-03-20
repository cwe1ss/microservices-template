param location string
param environment string
param tags object


///////////////////////////////////
// Resource names

param platformGroupName string
param platformLogsName string
param monitoringAppInsightsName string
param monitoringDashboardName string
param serviceBusGroupName string
param serviceBusNamespaceName string


///////////////////////////////////
// Configuration

var names = loadJsonContent('./../names.json')
var config = loadJsonContent('./../config.json')
var envConfig = config.environments[environment]


///////////////////////////////////
// Existing resources

var platformGroup = resourceGroup(platformGroupName)

resource platformLogs 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: platformLogsName
  scope: platformGroup
}


///////////////////////////////////
// New resources

@description('Application insights is targeted at a single environment so that you can properly use the application map etc, but data is stored in the global Log Analytics workspace.')
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: monitoringAppInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: platformLogs.id
  }
}

resource dashboard 'Microsoft.Portal/dashboards@2020-09-01-preview' = {
  name: monitoringDashboardName
  location: location
  tags: {
    'hidden-title': monitoringDashboardName
  }
  properties: {
    lenses: [
      {
        order: 0
        parts: [
          // Sample for "ResourceGroupMapPinnedPart
          // {
          //   position: {
          //     x: 0
          //     y: 0
          //     colSpan: 4
          //     rowSpan: 3
          //   }
          //   metadata: {
          //     type: 'Extension/HubsExtension/PartType/ResourceGroupMapPinnedPart'
          //     inputs: [
          //       {
          //         name: 'resourceGroup'
          //         isOptional: true
          //       }
          //       {
          //         name: 'id'
          //         value: resourceGroup().id
          //         isOptional: true
          //       }
          //     ]
          //   }
          // }

          // Sample for MarkdownPart
          // {
          //   position: {
          //     x: 4
          //     y: 0
          //     colSpan: 4
          //     rowSpan: 3
          //   }
          //   metadata: {
          //     type: 'Extension/HubsExtension/PartType/MarkdownPart'
          //     inputs: []
          //     settings: {
          //       content: {
          //         settings: {
          //           title: 'Title'
          //           subtitle: 'Subtitle'
          //           content: 'Content'
          //         }
          //       }
          //     }
          //   }
          // }

          // Replica Count per Service
          {
            position: {
              x: 0
              y: 0
              colSpan: 6
              rowSpan: 3
            }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                {
                  name: 'options'
                  isOptional: true
                }
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
              ]
              settings: {
                content: {
                  options: {
                    chart: {
                      title: 'Max Replica Count per Service'
                      titleKind: 1
                      visualization: {
                        disablePinning: true
                      }
                      metrics: [ for item in (contains(envConfig, 'services') ? items(envConfig.services) : []): {
                          resourceMetadata: {
                            id: resourceId(
                              replace(replace(names.svcGroupName, '{environment}', envConfig.environmentAbbreviation), '{service}', item.key),
                              'Microsoft.App/containerApps',
                              take(replace(replace(names.svcAppName, '{environment}', envConfig.environmentAbbreviation), '{service}', item.key), 32 /* max allowed length */)
                            )
                          }
                          name: 'Replicas'
                          aggregationType: 3
                          namespace: 'microsoft.app/containerapps'
                          metricVisualization: {
                            displayName: 'Replica Count'
                            resourceDisplayName: item.key
                          }
                        } ]
                    }
                  }
                }
              }
            }
          }

          // Service Bus Deadletter messages
          {
            position: {
              x: 0
              y: 3
              colSpan: 6
              rowSpan: 3
            }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                {
                  name: 'options'
                  value: {
                    chart: {
                      title: 'Max Count of dead-lettered messages in a Queue/Topic'
                      titleKind: 1
                      metrics: [
                        {
                          resourceMetadata: {
                            id: resourceId(serviceBusGroupName, 'Microsoft.ServiceBus/namespaces', serviceBusNamespaceName)
                          }
                          name: 'DeadletteredMessages'
                          aggregationType: 3
                          namespace: 'microsoft.servicebus/namespaces'
                          metricVisualization: {
                            displayName: 'Count of dead-lettered messages in a Queue/Topic'
                          }
                        }
                      ]
                      visualization: {
                        chartType: 2
                        legendVisualization: {
                          isVisible: true
                          position: 2
                          hideSubtitle: false
                        }
                        axisVisualization: {
                          x: {
                            isVisible: true
                            axisType: 2
                          }
                          y: {
                            isVisible: true
                            axisType: 1
                          }
                        }
                      }
                      grouping: {
                        dimension: 'EntityName'
                        sort: 1
                        top: 50
                      }
                      timespan: {
                        relative: {
                          duration: 86400000
                        }
                        showUTCTime: false
                        grain: 1
                      }
                    }
                  }
                  isOptional: true
                }
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
              ]
            }
          }
        ]
      }
    ]
    metadata: {
      model: {
        timeRange: {
          value: {
            relative: {
              duration: 24
              timeUnit: 1
            }
          }
          type: 'MsPortalFx.Composition.Configuration.ValueTypes.TimeRange'
        }
      }
    }
  }
}
