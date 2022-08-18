$platformResourcePrefix = "lab-msa"
$location = "westeurope"

. .\deploy-helpers.ps1

"Deploying platform"

Exec {
    az deployment sub create `
        --location $location `
        --template-file .\platform.bicep `
        --parameters location=$location platformResourcePrefix=$platformResourcePrefix
}
