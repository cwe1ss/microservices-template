[CmdletBinding()]
Param (

    [Parameter(Mandatory=$True)]
    [string]$Environment
)

$ErrorActionPreference = "Stop"

#$Environment = "development"


############################
"Loading config"

$config = Get-Content .\_config.json | ConvertFrom-Json
$env = $config.environments | Select-Object -ExpandProperty $Environment


############################
"Deploying Azure AD resources"

".. SQL Administrators AAD group"
$sqlAdminAdGroupName = "$($env.environmentResourcePrefix)-sql-admins"
$sqlAdAdminAdGroup = Get-AzAdGroup -DisplayName $sqlAdminAdGroupName
if (-not $sqlAdAdminAdGroup) {
    ".... Creating group"
    $sqlAdAdminAdGroup = New-AzAdGroup -DisplayName $sqlAdminAdGroupName -MailNickname $sqlAdminAdGroupName
}

# TODO: "SQL Administrators AAD group members"


############################
"Deploying Azure resources"

New-AzSubscriptionDeployment `
    -Location $config.location `
    -Name ("env" + (Get-Date).ToString("yyyyMMddHHmmss")) `
    -TemplateFile .\environment.bicep `
    -TemplateParameterObject @{
        environment = $Environment
        sqlAdminAdGroupId = $sqlAdAdminAdGroup.Id
        sqlAdminAdGroupName = $sqlAdAdminAdGroup.DisplayName
    } `
    -Verbose | Out-Null
