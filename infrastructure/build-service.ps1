[CmdletBinding()]
Param (

    [Parameter(Mandatory=$true)]
    [string]$ServiceName,

    [Parameter(Mandatory=$true)]
    [string]$ServicePath,

    [Parameter(Mandatory=$true)]
    [string]$HostProjectName,

    [Parameter(Mandatory=$true)]
    [string]$BuildNumber,

    [Parameter(Mandatory=$true)]
    [string]$RegistryServer,

    [Parameter(Mandatory=$false)]
    [Switch]$UploadArtifacts
)

#$ServiceName = "internal-http-bus"
#$ServicePath = "services/_internal-http-bus"
#$HostProjectName = "InternalHttpBus.Api"
#$BuildNumber = "1"
#$RegistryServer = "labmsaregistry.azurecr.io"

$ErrorActionPreference = "Stop"

. .\_includes\helpers.ps1

############################
""
"Loading config"

$config = Get-Content .\config.json | ConvertFrom-Json
$serviceDefaults = $config.services | Select-Object -ExpandProperty $ServiceName

$platformGroupName = "$($config.platformResourcePrefix)-platform"
$storageAccountName = "$($config.platformResourcePrefix)sa".Replace("-", "")
$sqlMigrationContainerName = 'sql-migration'
$containerImageName = "$($config.platformResourcePrefix)-$serviceName"


$solutionFolder = (Get-Item (Join-Path "../" $ServicePath)).FullName
$projectFolder = (Get-Item (Join-Path $solutionFolder $HostProjectName)).FullName

Get-Item $solutionFolder | Out-Null
Get-Item $projectFolder | Out-Null


############################
""
"Restoring .NET tools"

Exec { dotnet tool restore }


############################
""
"Restoring dependencies"

Exec { dotnet restore "$solutionFolder" }


############################
""
"Building solution"

Exec { dotnet build "$solutionFolder" -c Release --no-restore }


############################
# TODO: Running tests


############################
""
"Creating SQL migration file"

if ($serviceDefaults.sqlDatabaseEnabled) {
    Exec { dotnet ef migrations script --configuration Release --no-build --idempotent -p "$projectFolder" -o "../artifacts/migration.sql" }
} else {
    ".. SKIPPED (sqlDatabaseEnabled=false)"
}


############################
""
"Creating docker image"
Exec { dotnet publish "$projectFolder" -c Release --os linux --arch x64 -p:PublishProfile=DefaultContainer -p:ContainerImageName=$containerImageName -p:ContainerImageTag=$BuildNumber }


############################
""
"Tagging docker image with Azure Container Registry"
Exec { docker tag "$($containerImageName):$BuildNumber" "$RegistryServer/$($containerImageName):$BuildNumber" }


############################
""
"Uploading SQL migration file"

if (!$serviceDefaults.sqlDatabaseEnabled) {
    ".. SKIPPED (sqlDatabaseEnabled=false)"
} elseif (!$UploadArtifacts) {
    ".. SKIPPED (UploadArtifacts=false)"
} else {
    Get-AzStorageAccount -ResourceGroupName $platformGroupName -Name $storageAccountName `
        | Get-AzStorageContainer -Container $sqlMigrationContainerName `
        | Set-AzStorageBlobContent -File "../artifacts/migration.sql" -Blob "$containerImageName-$BuildNumber.sql" -Force `
        | Out-Null
}


############################
""
"Pushing docker image to Azure Container Registry"

if (!$UploadArtifacts) {
    ".. SKIPPED (UploadArtifacts=false)"
} else {
    Exec { docker push "$RegistryServer/$($containerImageName):$BuildNumber" }
}
