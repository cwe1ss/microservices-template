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
$env = $config.environments | Select-Object -ExpandProperty $Environment


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

