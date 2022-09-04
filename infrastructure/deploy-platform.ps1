# Deploys Azure resources that are shared/used by all environments.
# This must be deployed before any environment can be deployed.

$ErrorActionPreference = "Stop"


############################
"Loading config"

$config = Get-Content .\_config.json | ConvertFrom-Json

$githubAppName = "$($config.platformResourcePrefix)-github"


############################
"Loading GitHub application from Azure AAD"

$githubSp = Get-AzADServicePrincipal -DisplayName $githubAppName


############################
"Deploying Azure resources"

New-AzSubscriptionDeployment `
    -Location $config.location `
    -Name ("platform-" + (Get-Date).ToString("yyyyMMddHHmmss")) `
    -TemplateFile .\platform.bicep `
    -TemplateParameterObject @{
        githubServicePrincipalId = $githubSp.Id
    } `
    -Verbose | Out-Null
