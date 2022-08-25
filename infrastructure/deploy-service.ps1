[CmdletBinding()]
Param (

    [Parameter(Mandatory=$True)]
    [ValidateSet("development", "production")]
    [string]$Environment,

    [Parameter(Mandatory=$True)]
    [string]$ServiceName,

    [Parameter(Mandatory=$True)]
    [string]$ImageTag
)

#$Environment = "development"
#$ServiceName = "customers"
#$ImageTag = "27"

$platformResourcePrefix = "lab-msa"
$location = "westeurope"
$tags = @{
    "product" = $platformResourcePrefix
    "environment" = $environmentResourcePrefix
    "service" = $ServiceName
}

if ($Environment -eq "development") {
    $environmentResourcePrefix = "lab-msa-dev"
} elseif ($Environment -eq "production") {
    $environmentResourcePrefix = "lab-msa-prod"
} else {
    throw "Invalid environment: $Environment"
}

. .\deploy-helpers.ps1


"Service resources"
New-AzSubscriptionDeployment `
    -Location $location `
    -Name ("svc-" + (Get-Date).ToString("yyyyMMddHHmmss")) `
    -TemplateFile .\service.bicep `
    -TemplateParameterObject @{
        location = $location
        platformResourcePrefix = $platformResourcePrefix
        environmentResourcePrefix = $environmentResourcePrefix
        serviceName = $ServiceName
        imageTag = $ImageTag
        tags = $tags
    } `
    -Verbose | Out-Null
