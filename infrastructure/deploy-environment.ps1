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

#$githubAppName = "$($config.platformResourcePrefix)-github"
$sqlAdminAdGroupName = "$($env.environmentResourcePrefix)-sql-admins"
$sqlGroupName = "$($env.environmentResourcePrefix)-sql"
$sqlServerUserName = "$($env.environmentResourcePrefix)-sql"

Write-Success "Done"


############################
""
"Creating AAD group for SQL administrators"

# These resources can not be created via ARM/Bicep, so we need to use the PowerShell module.
$sqlAdAdminAdGroup = Get-AzAdGroup -DisplayName $sqlAdminAdGroupName
if ($sqlAdAdminAdGroup) {
    Write-Success "Group already exists"
} else {
    $sqlAdAdminAdGroup = New-AzAdGroup -DisplayName $sqlAdminAdGroupName -MailNickname $sqlAdminAdGroupName
    Write-Success "Group created"
}


############################
# ""
# "Adding GitHub Actions application to SQL Administrators group"

# # These resources can not be created via ARM/Bicep, so we need to use the PowerShell module.
# $sqlAdminAdGroupMembers = Get-AzADGroupMember -GroupObjectId $sqlAdAdminAdGroup.Id
# $githubApp = Get-AzADServicePrincipal -DisplayName $githubAppName

# if ($sqlAdminAdGroupMembers | Where-Object { $_.Id -eq $githubApp.Id }) {
#     Write-Success "Member already exists in group"
# } else {
#     Add-AzADGroupMember -TargetGroupObjectId $sqlAdAdminAdGroup.Id -MemberObjectId $githubApp.Id
#     Write-Success "Member added to group"
# }


# TODO: "Other SQL Administrators AAD group members"


############################
""
"Deploying Azure resources"

New-AzSubscriptionDeployment `
    -Location $config.location `
    -Name ("env-" + (Get-Date).ToString("yyyyMMddHHmmss")) `
    -TemplateFile .\environment.bicep `
    -TemplateParameterObject @{
        environment = $Environment
        sqlAdminAdGroupId = $sqlAdAdminAdGroup.Id
        sqlAdminAdGroupName = $sqlAdAdminAdGroup.DisplayName
    } `
    -Verbose | Out-Null


############################
""
"Adding SQL server managed identity to AAD administrators group"

# These resources can not be created via ARM/Bicep, so we need to use the PowerShell module.
$sqlAdminAdGroupMembers = Get-AzADGroupMember -GroupObjectId $sqlAdAdminAdGroup.Id
$sqlAdminUser = Get-AzUserAssignedIdentity -ResourceGroupName $sqlGroupName -Name $sqlServerUserName

if ($sqlAdminAdGroupMembers | Where-Object { $_.Id -eq $sqlAdminUser.PrincipalId }) {
    Write-Success "Member already exists in group"
} else {
    Add-AzADGroupMember -TargetGroupObjectId $sqlAdAdminAdGroup.Id -MemberObjectId $sqlAdminUser.PrincipalId
    Write-Success "Member added to group"
}
