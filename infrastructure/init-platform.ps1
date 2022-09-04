Write-Host -ForegroundColor White "*******************************"
Write-Host -ForegroundColor White "*** PLATFORM INITIALIZATION ***"
Write-Host -ForegroundColor White "*******************************"
""
"This script will set up the connection between your GitHub repository and your Azure account to allow for automated deployments."
""
"The script will perform the following actions:"
"* It will create an Azure AD application that will be used by GitHub Actions to deploy resources to Azure."
"* The application will be given the 'GroupMember.ReadWrite.All' permission in Azure Active Directory (to add environment-specific users to AAD groups)"
"* The application will be given 'Contributor' and 'User Access Administrator' roles in your Azure subscription (to create Azure-resources during deployment)"
"* Your GitHub repository will be configured with the necessary secrets (to authenticate as the given Azure AD application)"
"* For each configured environment (_config.json), the following will be created:"
"  * An 'environment' in your GitHub repository with the current user as a required reviewer (can be changed afterwards)"
"  * An Azure AD group for admins of the environment-specific SQL server"
"  * The group will be assigned the 'Directory Readers'-role to allow members (e.g. the managed identity of the SQL server) to query AAD users"
""
"IMPORTANT: You must be a 'Global Administrator' in your Azure tenant to execute this script!"
""
"NOTE: It is safe to run this script multiple times (e.g. when you add an environment)."
""
$decision = $Host.UI.PromptForChoice($null, "Are you sure you want to execute this script?", ('&Yes', '&No'), 1)
if ($decision -ne 0) {
    Write-Error "Script aborted."
    exit
}


$ErrorActionPreference = "Stop"

. .\helpers.ps1

############################
""
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
"Ensuring user is a 'Global Administrator'"

$currentUser = Get-AzADUser -SignedIn

$graphAccessToken = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com/"
$globalAdminRoleId = (Invoke-RestMethod -Method Get -Headers @{ Authorization = "Bearer $($graphAccessToken.Token)" } -Uri "https://graph.microsoft.com/v1.0/directoryRoles?`$filter=displayName eq 'Global Administrator'").value.id

$globalAdminMembers = (Invoke-RestMethod -Method Get -Headers @{ Authorization = "Bearer $($graphAccessToken.Token)" } -Uri "https://graph.microsoft.com/v1.0/directoryRoles/$($globalAdminRoleId)/members").value
$isGlobalAdmin = $globalAdminMembers | Where-Object { $_.id -eq $currentUser.Id }
if ($isGlobalAdmin) {
    Write-Success "User '$($currentUser.UserPrincipalName)' is a 'Global Administrator'"
} else {
    throw "Current user ($($currentUser.UserPrincipalName)) is not a 'Global Administrator' in Azure AD. You must run this script as a Global Administrator."
}


############################
""
"Loading config"

$config = Get-Content .\_config.json | ConvertFrom-Json
$environmentNames = $config.environments | Get-Member -MemberType NoteProperty | ForEach-Object { $_.Name }

$githubAppName = "$($config.platformResourcePrefix)-github"
$acrName = "$($config.platformResourcePrefix)registry.azurecr.io".Replace("-", "")

$msGraphPermissions = @( 
    "GroupMember.ReadWrite.All"
)

Write-Success "Config loaded"


############################
""
"Creating Azure AD application for GitHub Actions"

$githubApp = Get-AzADApplication -DisplayName $githubAppName
if ($githubApp) {
    Write-Success "Application '$githubAppName' already exists"
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
    #$permissionName = "GroupMember.ReadWrite.All"
    $permDefinition = $msGraphSp.AppRole | Where-Object { $_.Value -eq $permissionName } | Select-Object
    if (!$permDefinition) { throw "INTERNAL ERROR: Couldn't load permission '$permissionName'." }

    if (($existingPermissions | Where-Object { $_.ApiId -eq $msGraphAppId -and $_.Id -eq $permDefinition.Id})) {
        Write-Success "Permission '$permissionName' already exists"
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
    Write-Success "Service principal already exists"
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
    #$permissionName = "GroupMember.ReadWrite.All"
    $appRoleId = ($msGraphSp.AppRole | Where-Object { $_.Value -eq $permissionName } | Select-Object).Id 

    $exists = $existingAssignments.value | Where-Object { $_.appRoleId -eq $appRoleId }
    if ($exists) {
        Write-Success "Admin consent for '$permissionName' already exists"
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
    Write-Success "Role assignment already exists"
} else {
    New-AzRoleAssignment -ObjectId $githubAppSp.Id -RoleDefinitionName "Contributor" | Out-Null
    Write-Success "Role assignment created"
}


############################
""
"Assigning 'User Access Administrator'-role to the service principal on the Azure subscription"

$roleAssignment = Get-AzRoleAssignment -ObjectId $githubAppSp.Id -RoleDefinitionName "User Access Administrator"
if ($roleAssignment) {
    Write-Success "Role assignment already exists"
} else {
    New-AzRoleAssignment -ObjectId $githubAppSp.Id -RoleDefinitionName "User Access Administrator" | Out-Null
    Write-Success "Role assignment created"
}


############################
""
"Allowing GitHub Actions AAD-app to deploy from branch '$($ghRepo.defaultBranchRef.name)' (via federated credentials)"

$existingCredentials = Get-AzADAppFederatedCredential -ApplicationObjectId $githubApp.Id

$credentialName = "github-branch-$($ghRepo.defaultBranchRef.name)"
if ($existingCredentials | Where-Object { $_.Name -eq $credentialName}) {
    Write-Success "Credential '$credentialName' already exists"
} else {
    New-AzADAppFederatedCredential -ApplicationObjectId $githubApp.Id `
        -Audience "api://AzureADTokenExchange" `
        -Issuer "https://token.actions.githubusercontent.com" `
        -Name $credentialName `
        -Subject "repo:$($ghRepo.nameWithOwner):ref:refs/heads/$($ghRepo.defaultBranchRef.name)" | Out-Null

    Write-Success "Credential '$credentialName' created"
}


############################
""
"Creating GitHub secrets"

Exec { gh secret set "AZURE_CLIENT_ID" -b $($githubApp.AppId) }
Exec { gh secret set "AZURE_SUBSCRIPTION_ID" -b $((Get-AzContext).Subscription.Id) }
Exec { gh secret set "AZURE_TENANT_ID" -b $((Get-AzContext).Subscription.TenantId) }

Exec { gh secret set "REGISTRY_SERVER" -b $acrName }


############################
# ENVIRONMENTS             #
############################


foreach ($env in $environmentNames) {
    #$env = "development"

    $envConfig = $config.environments | Select-Object -ExpandProperty $env

    $sqlAdminAdGroupName = "$($envConfig.environmentResourcePrefix)-sql-admins"


    ############################
    ""
    "Environment '$env': Creating GitHub environment"
    # There are no CLI methods for managing environments, so we have to use the REST API: https://github.com/cli/cli/issues/5149 

    $ghEnvironments = Exec { gh api "/repos/$($ghRepo.nameWithOwner)/environments" -H "Accept: application/vnd.github+json" } | ConvertFrom-Json
    $ghUser = Exec { gh api "/user" -H "Accept: application/vnd.github+json" } | ConvertFrom-Json

    if ($ghEnvironments.environments | Where-Object { $_.name -eq $env }) {
        Write-Success "Environment '$env' already exists"
    } else {
        $body = @{
            reviewers = @( 
                @{ type = "User"; id = $ghUser.id }
            )
        } | ConvertTo-Json -Compress

        $ghEnv = Exec { $body | gh api "/repos/$($ghRepo.nameWithOwner)/environments/$env" -X PUT -H "Accept: application/vnd.github+json" --input - } | ConvertFrom-Json

        Write-Success "Environment '$env' created with YOU ($($ghUser.login)) as a required reviewer."
        "    You can modify the protection rules here: $($ghRepo.url)/settings/environments/$($ghEnv.id)/edit"
    }


    ############################
    ""
    "Environment '$env': Allowing GitHub Actions AAD-app to deploy from environment (via federated credentials)"

    $credentialName = "github-env-$env"

    if ($existingCredentials | Where-Object { $_.Name -eq $credentialName}) {
        Write-Success "Credential '$credentialName' already exists"
    } else {
        New-AzADAppFederatedCredential -ApplicationObjectId $githubApp.Id `
            -Audience "api://AzureADTokenExchange" `
            -Issuer "https://token.actions.githubusercontent.com" `
            -Name $credentialName `
            -Subject "repo:$($ghRepo.nameWithOwner):environment:$env" | Out-Null
        
        Write-Success "Credential '$credentialName' created"
    }


    ############################
    ""
    "Environment '$env': Creating SQL Admins AAD group"

    $sqlAdminAdGroup = Get-AzAdGroup -DisplayName $sqlAdminAdGroupName
    if ($sqlAdminAdGroup) {
        Write-Success "AAD group '$sqlAdminAdGroupName' already exists"
    } else {
        $sqlAdminAdGroup = New-AzAdGroup -DisplayName $sqlAdminAdGroupName -MailNickname $sqlAdminAdGroupName -IsAssignableToRole
        Write-Success "AAD group '$sqlAdminAdGroupName' already exists"
    }


    ############################
    ""
    "Environment '$env': Assigning 'Directory Reader'-role to SQL Admins AAD group"

    $graphAccessToken = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com/"

    $adRoleDefinition = Invoke-RestMethod -Method Get -Headers @{ Authorization = "Bearer $($graphAccessToken.Token)" } `
        -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions?`$filter=displayName eq 'Directory Readers'"
    
    $existingAdRoleAssignments = Invoke-RestMethod -Method Get -Headers @{ Authorization = "Bearer $($graphAccessToken.Token)" } `
        -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?`$filter=roleDefinitionId eq '$($adRoleDefinition.value.id)'"
    
    if ($existingAdRoleAssignments.value | Where-Object { $_.principalId -eq $sqlAdminAdGroup.Id }) {
        Write-Success "Role assignment already exists"
    } else {
        $body = @{
            principalId = $sqlAdminAdGroup.Id;
            roleDefinitionId = $adRoleDefinition.value.id;
            directoryScopeId = "/"
        }
        Invoke-RestMethod -Method Post -ContentType "application/json" -Headers @{ Authorization = "Bearer $($graphAccessToken.Token)" } `
            -Body $($body | convertto-json) `
            -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments" | Out-Null
        
        Write-Success "Role assignment created"
    }
}

""
"Script finished."
