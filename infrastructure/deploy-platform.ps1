# Deploys Azure resources that are shared/used by all environments.
# This must be deployed before any environment can be deployed.

$ErrorActionPreference = "Stop"


############################
"Loading config"

$config = Get-Content .\_config.json | ConvertFrom-Json


############################
"Deploying Azure resources"

New-AzSubscriptionDeployment `
    -Location $config.location `
    -Name ("platform-" + (Get-Date).ToString("yyyyMMddHHmmss")) `
    -TemplateFile .\platform.bicep `
    -TemplateParameterObject @{
    } `
    -Verbose | Out-Null
