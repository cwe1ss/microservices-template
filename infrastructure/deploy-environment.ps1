# Deploys Azure infrastructure resources that are shared by all services in one given environment.
# Must be deployed before any service.

[CmdletBinding()]
Param (

    [Parameter(Mandatory=$True)]
    [string]$Environment
)

$ErrorActionPreference = "Stop"

#$Environment = "development"


############################
"Loading config"

$names = Get-Content .\names.json | ConvertFrom-Json
$config = Get-Content .\config.json | ConvertFrom-Json
$envConfig = $config.environments | Select-Object -ExpandProperty $Environment

# Naming conventions
$sqlAdminAdGroupName = $($names.sqlAdminAdGroupName).Replace("{environment}", $envConfig.environmentAbbreviation)


############################
"Loading Azure AD objects"

$sqlAdminAdGroup = Get-AzAdGroup -DisplayName $sqlAdminAdGroupName
if (!$sqlAdminAdGroup) { throw "AAD group '$sqlAdminAdGroupName' not found. Did you run 'init-platform.ps1' after you added the environment?" }


############################
"Deploying Azure resources"

New-AzSubscriptionDeployment `
    -Location $config.location `
    -Name ("env-" + (Get-Date).ToString("yyyyMMddHHmmss")) `
    -TemplateFile .\environment\main.bicep `
    -TemplateParameterObject @{
        environment = $Environment
        sqlAdminAdGroupId = $sqlAdminAdGroup.Id
    } `
    -Verbose | Out-Null
