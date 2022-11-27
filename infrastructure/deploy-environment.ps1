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
"Registering Az providers"

# New subscriptions that never deployed container apps before require to register the container service provider first.
# Azure Portal and CLI are doing this automatically but Bicep is not. We therefore have to manually register the providers first.
# https://github.com/microsoft/azure-container-apps/issues/451#issuecomment-1282628180
# https://github.com/Azure/bicep/issues/3267

"* Microsoft.App"
Register-AzResourceProvider -ProviderNamespace Microsoft.App | Out-Null
"* Microsoft.ContainerService"
Register-AzResourceProvider -ProviderNamespace Microsoft.ContainerService | Out-Null


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
