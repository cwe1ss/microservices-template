# This script will connect your GitHub repository with your Azure subscription.
#
# It will do the following things:
# * Creates an Azure AD application that will be used by GitHub Actions to deploy resources to Azure.
# * Assigns necessary Microsoft Graph API permissions to the application.
# * Creates a service principal for the application.
# * Gives admin consent to the previously configured API permissions for this service principal.
# * Assigns the "Contributor"-role to the service principal in the Azure subscription.
# * Assigns the "User Access Administrator"-role to the service principal in the Azure subscription.
# * Adds GitHub federated identity credentials to the application (to allow signing in from the GitHub action without any passwords).
# * Creates the necessary secrets in GitHub.
# * Creates the environments in GitHub.
#
# https://docs.microsoft.com/en-us/azure/developer/github/connect-from-azure?tabs=azure-cli%2Cwindows

$ErrorActionPreference = "Stop"

. .\helpers.ps1

############################
"Ensuring required tools are installed"

if (Get-Command Get-AzContext -ErrorAction Ignore) {
    Write-Success "Azure PowerShell module"
} else {
    throw "'Azure PowerShell' is not installed. See https://docs.microsoft.com/en-us/powershell/azure/install-az-ps" 
}

if (Get-Command gh.exe -ErrorAction Ignore) { 
    Write-Success "GitHub CLI"
} else {
    throw "'GitHub CLI' is not installed. See https://github.com/cli/cli#installation" 
}


############################
""
"Confirming Azure Subscription"

$azContext = Get-AzContext
if (!$azContext) { throw "You are not signed in to an Azure subscription. Please login using 'Connect-AzAccount'" }

$subscriptionInfo = "You are connected to the subscription '$($azContext.Name)'. Are you sure you want to install the necessary resources here?"
$decision = $Host.UI.PromptForChoice($null, $subscriptionInfo, ('&Yes', '&No'), 1)
if ($decision -ne 0) {
    Write-Error "Script aborted. Please use 'Connect-AzAccount' to sign in to a different subscription and re-run the script."
    exit
}


############################
""
"Confirming GitHub account"

gh auth status
if ($LASTEXITCODE -ne 0) {
    exit
} else {
    $decision = $Host.UI.PromptForChoice($null, 'Are you sure you this is the correct GitHub account?', ('&Yes', '&No'), 1)
    if ($decision -ne 0) {
        Write-Error "Script aborted. Please use 'gh auth login' to sign in to a different account and re-run the script."
        exit
    }
}


############################
""
"Confirming GitHub repo"

$ghRepo = (gh repo view --json name,nameWithOwner,defaultBranchRef,url) | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Script aborted. Please run this script in a folder that is connected with a GitHub repository."
    exit
} else {
    $repoInfo = "You are connected to the GitHub repo '$($ghRepo.url)'. Are you sure you want to install the necessary resources here?"
    $decision = $Host.UI.PromptForChoice($null, $repoInfo, ('&Yes', '&No'), 1)
    if ($decision -ne 0) {
        Write-Error "Script aborted. Please run this script in a folder that is connected with a GitHub repository."
        exit
    }
}


############################
""
"Loading config"

$config = Get-Content .\_config.json | ConvertFrom-Json

$githubAppName = "$($config.platformResourcePrefix)-github"
$acrName = "$($config.platformResourcePrefix)registry.azurecr.io".Replace("-", "")
$msGraphPermissions = @( 
    "Group.Read.All"
    "Group.Create"
)

Write-Success "Config loaded"


############################
""
"Creating Azure AD application for GitHub Actions"

$githubApp = Get-AzADApplication -DisplayName $githubAppName
if ($githubApp) {
    Write-Success "Application '$githubAppName' already existed"
} else {
    $githubApp = New-AzADApplication -DisplayName $githubAppName `
        -AvailableToOtherTenants $false `
        -Note "GitHub Actions uses this application to authenticate with Azure when deploying resources" `
        -RequiredResourceAccess $resourceAccess

    Write-Success "Application '$githubAppName' created"
}


############################
""
"Assigning MS Graph API permissions to the application"

$msGraphAppId = "00000003-0000-0000-c000-000000000000"
$msGraphSp = Get-AzAdServicePrincipal -ApplicationId $msGraphAppId
$existingPermissions = Get-AzADAppPermission -ObjectId $githubApp.Id

foreach ($permissionName in $msGraphPermissions) {
    $permDefinition = $msGraphSp.AppRole | Where-Object { $_.Value -eq $permissionName } | Select-Object
    if (!$permDefinition) { throw "INTERNAL ERROR: Couldn't load permission '$permissionName'." }

    if (($existingPermissions | Where-Object { $_.ApiId -eq $msGraphAppId -and $_.Id -eq $permDefinition.Id})) {
        Write-Success "Permission '$permissionName' already existed"
    } else {
        Add-AzADAppPermission -ObjectId $githubApp.Id -ApiId $msGraphAppId -PermissionId $permDefinition.Id -Type "Role"
        Write-Success "Permission '$permissionName' created"
    }
}


############################
""
"Creating service principal for Azure AD application"

$githubAppSp = Get-AzADServicePrincipal -ApplicationId $githubApp.AppId
if ($githubAppSp) {
    Write-Success "Service principal already existed"
} else {
    $githubAppSp = New-AzADServicePrincipal -ApplicationId $githubApp.AppId
    Write-Success "Service principal created"
}


############################
""
"Giving admin consent to enable the API permissions for the service principal"
# There is no PowerShell command, so we have to manually call the URL

$graphAccessToken = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com/"
$apiUrl = "https://graph.microsoft.com/v1.0/servicePrincipals/$($githubAppSp.Id)/appRoleAssignments"

$existingAssignments = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers @{ Authorization = "Bearer $($graphAccessToken.Token)" } 

foreach ($permissionName in $msGraphPermissions) {
    #$permissionName = "Group.Read.All"
    $appRoleId = ($msGraphSp.AppRole | Where-Object { $_.Value -eq $permissionName } | Select-Object).Id 

    $exists = $existingAssignments.value | Where-Object { $_.appRoleId -eq $appRoleId }
    if ($exists) {
        Write-Success "Admin consent for '$permissionName' already existed"
    } else {
        $body = @{
            appRoleId = $appRoleId
            resourceId = $msGraphSp.Id
            principalId = $githubAppSp.Id
        }
        Invoke-RestMethod -Uri $apiUrl -Method Post -ContentType "application/json" `
            -Headers @{ Authorization = "Bearer $($graphAccessToken.Token)" } `
            -Body $($body | convertto-json) | Out-Null
        
        Write-Success "Admin consent for '$permissionName' created"
    }
}


############################
""
"Assigning 'Contributor'-role to the service principal on the Azure subscription"

$roleAssignment = Get-AzRoleAssignment -ObjectId $githubAppSp.Id -RoleDefinitionName "Contributor"
if ($roleAssignment) {
    Write-Success "Role assignment already existed"
} else {
    New-AzRoleAssignment -ObjectId $githubAppSp.Id -RoleDefinitionName "Contributor" | Out-Null
    Write-Success "Role assignment created"
}


############################
""
"Assigning 'User Access Administrator'-role to the service principal on the Azure subscription"

$roleAssignment = Get-AzRoleAssignment -ObjectId $githubAppSp.Id -RoleDefinitionName "User Access Administrator"
if ($roleAssignment) {
    Write-Success "Role assignment already existed"
} else {
    New-AzRoleAssignment -ObjectId $githubAppSp.Id -RoleDefinitionName "User Access Administrator" | Out-Null
    Write-Success "Role assignment created"
}


############################
""
"Assigning GitHub federated credentials to application"

$existingCredentials = Get-AzADAppFederatedCredential -ApplicationObjectId $githubApp.Id

$credentialName = "github-branch-$($ghRepo.defaultBranchRef.name)"
if ($existingCredentials | Where-Object { $_.Name -eq $credentialName}) {
    Write-Success "Credential '$credentialName' already existed"
} else {
    New-AzADAppFederatedCredential -ApplicationObjectId $githubApp.Id `
        -Audience "api://AzureADTokenExchange" `
        -Issuer "https://token.actions.githubusercontent.com" `
        -Name $credentialName `
        -Subject "repo:$($ghRepo.nameWithOwner):ref:refs/heads/$($ghRepo.defaultBranchRef.name)" | Out-Null

    Write-Success "Credential '$credentialName' created"
}

# Environments
$environmentNames = $config.environments | Get-Member -MemberType NoteProperty | Select-Object -Property Name
foreach ($envObj in $environmentNames) {
    $env = $envObj.Name
    $credentialName = "github-env-$env"

    if ($existingCredentials | Where-Object { $_.Name -eq $credentialName}) {
        Write-Success "Credential '$credentialName' already existed"
    } else {
        New-AzADAppFederatedCredential -ApplicationObjectId $githubApp.Id `
            -Audience "api://AzureADTokenExchange" `
            -Issuer "https://token.actions.githubusercontent.com" `
            -Name $credentialName `
            -Subject "repo:$($ghRepo.nameWithOwner):environment:$env" | Out-Null
        
        Write-Success "Credential '$credentialName' created"
    }
}


############################
""
"Creating GitHub secrets"

Exec { gh secret set "AZURE_CLIENT_ID" -b $($githubApp.AppId) }
Exec { gh secret set "AZURE_SUBSCRIPTION_ID" -b $((Get-AzContext).Subscription.Id) }
Exec { gh secret set "AZURE_TENANT_ID" -b $((Get-AzContext).Subscription.TenantId) }

Exec { gh secret set "REGISTRY_SERVER" -b $acrName }


############################
""
"Creating GitHub environments"
foreach ($envObj in $environmentNames) {
    $env = $envObj.Name

    # There is no CLI method, so we have to use the REST API: https://github.com/cli/cli/issues/5149 
    Exec { gh api "/repos/$($ghRepo.nameWithOwner)/environments/$env" -X PUT -H "Accept: application/vnd.github+json" | Out-Null }
    Write-Success "Environment '$env' created"
}

# TODO Branch protection rules??
