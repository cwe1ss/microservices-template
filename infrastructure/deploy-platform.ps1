$platformResourcePrefix = "lab-msa"
$location = "westeurope"

. .\deploy-helpers.ps1

# Naming conventions
$platformGroupName = "$platformResourcePrefix-platform"
$tags = @{
    "product" = $platformResourcePrefix
}

"Platform resource group"
New-AzResourceGroup -Name $platformGroupName -Location $location -Tag $tags -Force | Out-Null

"Platform resources"
New-AzResourceGroupDeployment `
    -ResourceGroupName $platformGroupName `
    -Name ("platform-" + (Get-Date).ToString("yyyyMMddHHmmss")) `
    -TemplateFile .\platform-resources.bicep `
    -TemplateParameterObject @{
        platformResourcePrefix = $platformResourcePrefix
        tags = $tags
    } `
    -Verbose | Out-Null
