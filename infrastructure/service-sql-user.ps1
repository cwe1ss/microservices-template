param(
    [string] $ServerName,
    [string] $DatabaseName,
    [string] $UserName
)

$ErrorActionPreference = "Stop"

Write-Output "Aquiring access token"
$token = Get-AzAccessToken -Resource "https://database.windows.net"

$dbConn = New-Object System.Data.SqlClient.SqlConnection

try {
    $dbConn.ConnectionString = "Server=tcp:$ServerName,1433;Initial Catalog=$DatabaseName;Persist Security Info=False;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;"
    $dbConn.AccessToken=$token.Token

    Write-Output "Opening connection"
    $dbConn.Open()
    Write-Output ".. Done"

    Write-Output "Ensuring user is created and has datareader/datawriter roles"
    $dbCmd = New-Object System.Data.SqlClient.SqlCommand
    $dbCmd.Connection = $dbConn
    $dbCmd.CommandText = @"
        IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = '$UserName')
        BEGIN
            CREATE USER [$UserName] FROM EXTERNAL PROVIDER
        END

        IF IS_ROLEMEMBER('db_datareader', '$UserName') = 0
        BEGIN
            ALTER ROLE db_datareader ADD MEMBER [$UserName]
        END

        IF IS_ROLEMEMBER('db_datawriter', '$UserName') = 0
        BEGIN
            ALTER ROLE db_datawriter ADD MEMBER [$UserName]
        END
"@
    $dbCmd.ExecuteNonQuery() | Out-Null
    Write-Output ".. Done"
}
finally {
    $dbConn.Close()
}
