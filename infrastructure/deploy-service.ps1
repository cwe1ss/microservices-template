# Deploys all Azure resources that are used by one single service.
# It also adds some resources to the environment (SQL database, Service Bus queues & topics) and platform (permissions).

[CmdletBinding()]
Param (

    [Parameter(Mandatory=$True)]
    [string]$Environment,

    [Parameter(Mandatory=$True)]
    [string]$ServiceName,

    [Parameter(Mandatory=$True)]
    [string]$ImageTag
)

$ErrorActionPreference = "Stop"

#$Environment = "development"
#$ServiceName = "customers"
#$ImageTag = "27"


############################
"Loading config"

$config = Get-Content .\_config.json | ConvertFrom-Json


############################
"Deploying Azure resources"

New-AzSubscriptionDeployment `
    -Location $config.location `
    -Name ("svc-" + (Get-Date).ToString("yyyyMMddHHmmss")) `
    -TemplateFile .\service.bicep `
    -TemplateParameterObject @{
        environment = $Environment
        serviceName = $ServiceName
        imageTag = $ImageTag
    } `
    -Verbose | Out-Null

