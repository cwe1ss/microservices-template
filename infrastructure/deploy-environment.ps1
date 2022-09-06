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

$config = Get-Content .\config.json | ConvertFrom-Json
$envConfig = $config.environments | Select-Object -ExpandProperty $Environment

# Naming conventions

$sqlAdminAdGroupName = "$($envConfig.environmentResourcePrefix)-sql-admins"
$sqlServerAdminUserName = "$($envConfig.environmentResourcePrefix)-sql-admin"


############################
"Loading Azure AD objects"

$sqlAdminAdGroup = Get-AzAdGroup -DisplayName $sqlAdminAdGroupName
if (!$sqlAdminAdGroup) { throw "AAD group '$sqlAdminAdGroupName' not found. Did you run 'init-platform.ps1' after you added the environment?" }


############################
"Deploying Azure resources"

New-AzSubscriptionDeployment `
    -Location $config.location `
    -Name ("env-" + (Get-Date).ToString("yyyyMMddHHmmss")) `
    -TemplateFile .\environment\environment.bicep `
    -TemplateParameterObject @{
        environment = $Environment
        sqlAdminAdGroupId = $sqlAdminAdGroup.Id
        sqlAdminAdGroupName = $sqlAdminAdGroup.DisplayName
    } `
    -Verbose | Out-Null


############################
"Refreshing Az access token"

# When the previous Azure deployment takes more than 5 minutes the access token will expire and future calls
# will fail with the error "AADSTS700024: Client assertion is not within its valid time range".

# TODO REMOVE THIS
".. Sleeping for 6 minutes to test behavior"
Start-Sleep -Seconds (6*60)
".... done"

#Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com/" | Out-Null


############################
"Adding SQL server managed identity to SQL administrators AAD group"

# These resources can not be created via ARM/Bicep, so we need to use the PowerShell module.
$sqlAdminAdGroupMembers = Get-AzADGroupMember -GroupObjectId $sqlAdminAdGroup.Id
$sqlAdminUser = Get-AzADServicePrincipal -DisplayName $sqlServerAdminUserName

if ($sqlAdminAdGroupMembers | Where-Object { $_.Id -eq $sqlAdminUser.Id }) {
    ".. Member already exists in group"
} else {
    Add-AzADGroupMember -TargetGroupObjectId $sqlAdminAdGroup.Id -MemberObjectId $sqlAdminUser.Id
    ".. Member added to group"
}


# TODO: "Other SQL Administrators AAD group members"
