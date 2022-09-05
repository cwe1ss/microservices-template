# Deploys Azure infrastructure resources that are shared by all services in one given environment.
# Must be deployed before any service.

[CmdletBinding()]
Param (

    [Parameter(Mandatory=$True)]
    [string]$Environment
)

$ErrorActionPreference = "Stop"

#$Environment = "development"

. .\helpers.ps1


############################
"Loading config"

$config = Get-Content .\_config.json | ConvertFrom-Json
$env = $config.environments | Select-Object -ExpandProperty $Environment

# Naming conventions

$sqlAdminAdGroupName = "$($env.environmentResourcePrefix)-sql-admins"
$sqlServerAdminUserName = "$($env.environmentResourcePrefix)-sql-admin"


############################
"Loading Azure AD objects"

$sqlAdminAdGroup = Get-AzAdGroup -DisplayName $sqlAdminAdGroupName
if (!$sqlAdminAdGroup) { throw "AAD group '$sqlAdminAdGroupName' not found. Did you run 'init-platform.ps1' after you added the environment?" }


############################
""
"Deploying Azure resources"

New-AzSubscriptionDeployment `
    -Location $config.location `
    -Name ("env-" + (Get-Date).ToString("yyyyMMddHHmmss")) `
    -TemplateFile .\environment.bicep `
    -TemplateParameterObject @{
        environment = $Environment
        sqlAdminAdGroupId = $sqlAdminAdGroup.Id
        sqlAdminAdGroupName = $sqlAdminAdGroup.DisplayName
    } `
    -Verbose | Out-Null


############################
""
"Adding SQL server managed identity to SQL administrators AAD group"

# These resources can not be created via ARM/Bicep, so we need to use the PowerShell module.
$sqlAdminAdGroupMembers = Get-AzADGroupMember -GroupObjectId $sqlAdminAdGroup.Id
$sqlAdminUser = Get-AzADServicePrincipal -DisplayName $sqlServerAdminUserName

if ($sqlAdminAdGroupMembers | Where-Object { $_.Id -eq $sqlAdminUser.Id }) {
    Write-Success "Member already exists in group"
} else {
    Add-AzADGroupMember -TargetGroupObjectId $sqlAdminAdGroup.Id -MemberObjectId $sqlAdminUser.Id
    Write-Success "Member added to group"
}


# TODO: "Other SQL Administrators AAD group members"
