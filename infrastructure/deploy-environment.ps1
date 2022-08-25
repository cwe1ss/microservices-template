[CmdletBinding()]
Param (

    [Parameter(Mandatory=$True)]
    [ValidateSet("development", "production")]
    [string]$Environment
)

#$Environment = "development"

. .\deploy-helpers.ps1

$platformResourcePrefix = "lab-msa"
$location = "westeurope"

if ($Environment -eq "development") {
    $environmentResourcePrefix = "lab-msa-dev"
} elseif ($Environment -eq "production") {
    $environmentResourcePrefix = "lab-msa-prod"
} else {
    throw "Invalid environment: $Environment"
}

# Naming conventions

$envGroupName = "$environmentResourcePrefix-env"
$sqlAdminAdGroupName = "$environmentResourcePrefix-sql-admins"
$sqlGroupName = "$environmentResourcePrefix-sql"
$tags = @{
    "product" = $platformResourcePrefix
    "environment" = $environmentResourcePrefix
}


"Environment resource group"
New-AzResourceGroup -Name $envGroupName -Location $location -Tag $tags -Force | Out-Null

"Environment resources"
New-AzResourceGroupDeployment `
    -ResourceGroupName $envGroupName `
    -Name ("env-" + (Get-Date).ToString("yyyyMMddHHmmss")) `
    -TemplateFile .\environment-resources.bicep `
    -TemplateParameterObject @{
        location = $location
        platformResourcePrefix = $platformResourcePrefix
        environmentResourcePrefix = $environmentResourcePrefix
        tags = $tags
    } `
    -Verbose | Out-Null

"SQL Administrators AAD group"
$sqlAdAdminGroup = Get-AzAdGroup -DisplayName $sqlAdminAdGroupName
if (-not $sqlAdAdminGroup) {
    ".. Creating group"
    $sqlAdAdminGroup = New-AzAdGroup -DisplayName $sqlAdminAdGroupName -MailNickname $sqlAdminAdGroupName
}

# TODO: "SQL Administrators AAD group members"

"SQL resource group"
New-AzResourceGroup -Name $sqlGroupName -Location $location -Tag $tags -Force | Out-Null

"SQL resources"
New-AzResourceGroupDeployment `
    -ResourceGroupName $sqlGroupName `
    -Name ("sql-" + (Get-Date).ToString("yyyyMMddHHmmss")) `
    -TemplateFile .\environment-sql.bicep `
    -TemplateParameterObject @{
        location = $location
        platformResourcePrefix = $platformResourcePrefix
        environmentResourcePrefix = $environmentResourcePrefix
        sqlAdminAdGroup = $sqlAdminAdGroupName 
        sqlAdminAdGroupId = $sqlAdAdminGroup.id
        tags = $tags
    } `
    -Verbose | Out-Null
