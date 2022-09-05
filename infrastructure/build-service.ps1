[CmdletBinding()]
Param (

    [Parameter(Mandatory=$True)]
    [string]$ServiceName,

    [Parameter(Mandatory=$True)]
    [string]$HostProjectName,

    [Parameter(Mandatory=$True)]
    [string]$ContainerImageName,

    [Parameter(Mandatory=$True)]
    [string]$BuildNumber
)

#$ServiceName = "customers"
#$SolutionFolder = "./services/customers"
#$ProjectFolder = "./services/customers/Customers.Api"
#$ContainerImageName = "lab-msa-svc-customers"

$ErrorActionPreference = "Stop"

. $PSScriptRoot\helpers.ps1

############################
""
"Loading config"

$config = Get-Content $PSScriptRoot\_config.json | ConvertFrom-Json
$serviceDefaults = $config.services | Select-Object -ExpandProperty $ServiceName

$solutionFolder = (Get-Item (Join-Path "../services" $ServiceName)).FullName
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
"Creating Docker image"
Exec { dotnet publish "$projectFolder" -c Release --os linux --arch x64 -p:PublishProfile=DefaultContainer -p:ContainerImageName=$ContainerImageName -p:ContainerImageTag=$BuildNumber }
