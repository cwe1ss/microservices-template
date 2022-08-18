[CmdletBinding()]
Param (

    [Parameter(Mandatory=$True)]
    [ValidateSet("development", "production")]
    [string]$Environment,

    [Parameter(Mandatory=$True)]
    [string]$ServiceName
)

#$Environment = "development"
#$ServiceName = "demo"

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


"Deploying service"

Exec {
    az deployment sub create `
        --location $location `
        --template-file .\service.bicep `
        --parameters location=$location platformResourcePrefix=$platformResourcePrefix environmentResourcePrefix=$environmentResourcePrefix serviceName=$ServiceName
}
