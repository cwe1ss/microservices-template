# Deploys Azure resources that are shared/used by all environments.
# This must be deployed before any environment can be deployed.

$ErrorActionPreference = "Stop"


############################
"Loading config"

$config = Get-Content .\config.json | ConvertFrom-Json

$githubAppName = "$($config.platformResourcePrefix)-github"


############################
"Loading Azure AD objects"

$githubSp = Get-AzADServicePrincipal -DisplayName $githubAppName
if (!$githubSp) { throw "Service principal '$githubAppName' not found. Did you run 'init-platform.ps1'?" }


############################
"Deploying Azure resources"

New-AzSubscriptionDeployment `
    -Location $config.location `
    -Name ("platform-" + (Get-Date).ToString("yyyyMMddHHmmss")) `
    -TemplateFile .\platform\main.bicep `
    -TemplateParameterObject @{
        githubServicePrincipalId = $githubSp.Id
    } `
    -Verbose | Out-Null
