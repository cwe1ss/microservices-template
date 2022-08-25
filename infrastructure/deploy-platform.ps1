$platformResourcePrefix = "lab-msa"
$location = "westeurope"

. .\deploy-helpers.ps1

# Naming conventions
$platformGroupName = "$platformResourcePrefix-platform"
$tags = @("product=$platformResourcePrefix")

"Platform resource group"
Exec {
    az group create --name $platformGroupName --location $location --tags $tags -o none
}

"Platform resources"
Exec {
    az deployment group create `
        --resource-group $platformGroupName `
        --name ("platform-" + (Get-Date).ToString("yyyyMMddHHmmss")) `
        --output none `
        --template-file .\platform-resources.bicep `
        --parameters platformResourcePrefix=$platformResourcePrefix
}
