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
$tags = @("product=$platformResourcePrefix", "environment=$environmentResourcePrefix")


"Environment resource group"
Exec {
    az group create --name $envGroupName --location $location --tags $tags -o none
}

"Environment resources"
Exec {
    az deployment group create `
        --resource-group $envGroupName `
        --name ("env-" + (Get-Date).ToString("yyyyMMddHHmmss")) `
        --output none `
        --template-file .\environment-resources.bicep `
        --parameters location=$location platformResourcePrefix=$platformResourcePrefix environmentResourcePrefix=$environmentResourcePrefix
}

"SQL Administrators AAD group"
$sqlAdAdminGroup = Exec {
    (az ad group create --display-name $sqlAdminAdGroupName --mail-nickname $sqlAdminAdGroupName) | ConvertFrom-Json
}

"SQL Administrators group assignments"
# TODO!!

"SQL resource group"
Exec {
    az group create --name $sqlGroupName --location $location --tags $tags -o none
}

"SQL resources"
Exec {
    az deployment group create `
        --resource-group $sqlGroupName `
        --name ("sql-" + (Get-Date).ToString("yyyyMMddHHmmss")) `
        --output none `
        --template-file .\environment-sql.bicep `
        --parameters `
            location=$location `
            platformResourcePrefix=$platformResourcePrefix `
            environmentResourcePrefix=$environmentResourcePrefix `
            sqlAdminAdGroup=$sqlAdminAdGroupName `
            sqlAdminAdGroupId=$($sqlAdAdminGroup.id)
}
