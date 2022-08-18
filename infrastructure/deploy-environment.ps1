[CmdletBinding()]
Param (

    [Parameter(Mandatory=$True)]
    [ValidateSet("development", "production")]
    [string]$Environment
)

#$Environment = "development"

$platformResourcePrefix = "lab-msa"
$location = "westeurope"

if ($Environment -eq "development") {
    $environmentResourcePrefix = "lab-msa-dev"
} elseif ($Environment -eq "production") {
    $environmentResourcePrefix = "lab-msa-prod"
} else {
    throw "Invalid environment: $Environment"
}

. .\deploy-helpers.ps1


"Deploying environment"

Exec {
    az deployment sub create `
        --location $location `
        --template-file .\infrastructure\environment.bicep `
        --parameters location=$location platformResourcePrefix=$platformResourcePrefix environmentResourcePrefix=$environmentResourcePrefix
}
