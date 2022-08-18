$platformResourcePrefix = "lab-msa"
$location = "westeurope"

. .\deploy-helpers.ps1

"Deploying platform"

New-AzSubscriptionDeployment -Location $location -TemplateFile .\platform.bicep -TemplateParameterObject @{
    location = $location;
    platformResourcePrefix = $platformResourcePrefix;
}
