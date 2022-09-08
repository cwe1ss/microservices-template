param(
    [string] $ServerName,
    [string] $DatabaseName,
    [string] $SqlMigrationBlobUrl
)

#$ServerName = "lab-msa-dev-sql.database.windows.net"
#$DatabaseName = "customers"
#$SqlMigrationBlobUrl = ""

$ErrorActionPreference = "Stop"

############################
"Installing module 'SqlServer'"

$sqlServerModule = Get-InstalledModule -Name SqlServer -ErrorAction Ignore
if ($sqlServerModule) {
    ".. Already installed"
} else {
    Install-Module -Name SqlServer -Force
    ".. Module installed"
}

############################
"Downloading SQL migration file"

$blobFile = Get-AzStorageBlobContent -Uri $SqlMigrationBlobUrl -Force

############################
"Aquiring access token for SQL database"

$token = Get-AzAccessToken -Resource "https://database.windows.net"

############################
"Executing SQL script"

Invoke-Sqlcmd -ServerInstance $ServerName -Database $DatabaseName -AccessToken $token.Token -InputFile $blobFile.Name

"Script finished"
