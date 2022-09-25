[CmdletBinding()]
Param ()

"This script will set up the connection between your current GitHub repository and your current Azure account to allow for automated deployments."
""
"IMPORTANT: You must be a 'Global Administrator' in your Azure tenant and you must have admin rights in your GitHub repository to execute this script!"
""
"Changes to your Azure account:"
""
"* A managed identity '{platform}-github' will be created"
"  - The identity will be used by GitHub Actions to deploy resources to Azure"
"  - The identity will be given 'Contributor' and 'User Access Administrator' roles in your current Azure subscription"
"  - The identity will be given the AAD permission 'Group.Read.All'"
""
"* A managed identity '{env}-sql-admin' will be created per environment (as configured in 'config.json')"
"  - The identity will later be used by the SQL server to allow for Azure AD-based authentication"
"  - The identity will be given the AAD permissions 'Application.Read.All', 'GroupMember.Read.All', 'User.Read.All'"
""
"* An AAD group '{env}-sql-admins' will be created per environment (as configured in 'config.json')"
"  - This group will later be set as the SQL server admin to allow for AAD based management of SQL admins"
"  - The '{env}-sql-admin' identity will be added to the group as the first member"
"  - You can add additional admins to this group later"
""
"Changes to your GitHub repository:"
""
"* A 'platform'-environment and the environments configured in 'config.json' will be added to your GitHub repository"
"  - You will be set as a required reviewer to prevent unindentional deployments"
"  - You can manually change the protection rules later (Changes will NOT be overwritten if you call this script again afterwards)"
""
"* Your GitHub repository will be configured with the necessary secrets (to authenticate as the given Azure AD application)"
""
"NOTE: It is safe to run this script multiple times (e.g. when you add an environment)."
""
$decision = $Host.UI.PromptForChoice($null, "Are you sure you want to execute this script?", ('&Yes', '&No'), 1)
if ($decision -ne 0) {
    Write-Error "Script aborted."
    exit
}


$ErrorActionPreference = "Stop"

. .\_includes\helpers.ps1

############################
""
"Ensuring required tools are installed"

if (Get-Command Get-AzContext -ErrorAction Ignore) {
    Write-Success "Azure PowerShell module"
} else {
    throw "'Azure PowerShell' is not installed. See https://docs.microsoft.com/en-us/powershell/azure/install-az-ps"
}

if (Get-Command bicep -ErrorAction Ignore) {
    Write-Success "Bicep CLI"
} else {
    throw "'Bicep CLI' is not installed. See https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install"
}

if (Get-Command gh -ErrorAction Ignore) {
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

$config = Get-Content .\config.json | ConvertFrom-Json

# Naming conventions
$acrName = "$($config.platformAbbreviation)registry.azurecr.io".Replace("-", "")

$environments = $config.environments | Get-Member -MemberType NoteProperty | ForEach-Object { $_.Name }

$githubIdentityMsGraphPermissions = @(
    "Group.Read.All" # Required to get the SQL Admins AAD group in `deploy-environment.ps1`
)

# https://docs.microsoft.com/en-us/azure/azure-sql/database/authentication-azure-ad-user-assigned-managed-identity?view=azuresql#permissions
$sqlIdentityMsGraphPermissions = @(
    "Application.Read.All",
    "GroupMember.Read.All",
    "User.Read.All"
)

Write-Success "Config loaded"


############################
""
"---------------"
"GitHub identity"
"---------------"
""
"Creating Azure resources for GitHub identity (this may take a minute)"

$deployment = New-AzSubscriptionDeployment `
    -Location $config.location `
    -Name ("init-gh-" + (Get-Date).ToString("yyyyMMddHHmmss")) `
    -TemplateFile .\init\github-identity.bicep `
    -TemplateParameterObject @{
        githubRepoNameWithOwner = $($ghRepo.nameWithOwner)
        githubDefaultBranchName = $ghRepo.defaultBranchRef.name
    }

Write-Success "GitHub identity resources deployed"

# AAD replicates data so future queries might not immediately recognize the newly created object
$githubIdentity = $null
for ($i=1; $i -le 12; $i++) {
    $githubIdentity = Get-AzADServicePrincipal -ObjectId $deployment.Outputs.githubIdentityPrincipalId.Value -ErrorAction Ignore
    if ($githubIdentity) {
        if ($i -gt 1) { Write-Success "Identity found in Azure AD API" }
        break
    } else {
        "  Identity not yet available in Azure AD API. Waiting for 10 seconds"
        Start-Sleep -Seconds 10
    }
}


############################
""
"Assigning MS Graph API permissions to the GitHub identity"

# There is no Bicep-feature or Azure-PowerShell command, so we have to manually call the URL
# (There would be a separate AzureAD PowerShell-module but this would require a separate login, so it's easier to just call the Graph API directly)

$msGraphSp = Get-AzAdServicePrincipal -ApplicationId "00000003-0000-0000-c000-000000000000"
$graphAccessToken = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com/"
$apiUrl = "https://graph.microsoft.com/v1.0/servicePrincipals/$($githubIdentity.Id)/appRoleAssignments"

$existingAssignments = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers @{ Authorization = "Bearer $($graphAccessToken.Token)" }

foreach ($permissionName in $githubIdentityMsGraphPermissions) {
    #$permissionName = "GroupMember.ReadWrite.All"
    $appRoleId = ($msGraphSp.AppRole | Where-Object { $_.Value -eq $permissionName } | Select-Object).Id

    $exists = $existingAssignments.value | Where-Object { $_.appRoleId -eq $appRoleId }
    if ($exists) {
        Write-Success "Permission '$permissionName' already exists"
    } else {
        $body = @{
            appRoleId = $appRoleId
            resourceId = $msGraphSp.Id
            principalId = $githubIdentity.Id
        }
        Invoke-RestMethod -Uri $apiUrl -Method Post -ContentType "application/json" `
            -Headers @{ Authorization = "Bearer $($graphAccessToken.Token)" } `
            -Body $($body | convertto-json) | Out-Null

        Write-Success "Permission '$permissionName' created"
    }
}


############################
""
"-------------------"
"SQL Server identity"
"-------------------"

foreach ($environment in $environments) {
    #$environment = "development"

    $envConfig = $config.environments | Select-Object -ExpandProperty $environment

    $sqlAdminAdGroupName = "$($envConfig.environmentAbbreviation)-sql-admins"

    ############################
    ""
    "Environment '$environment': Creating SQL Admins AAD group"

    $sqlAdminAdGroup = Get-AzAdGroup -DisplayName $sqlAdminAdGroupName
    if ($sqlAdminAdGroup) {
        Write-Success "AAD group '$sqlAdminAdGroupName' already exists"
    } else {
        $sqlAdminAdGroup = New-AzAdGroup -DisplayName $sqlAdminAdGroupName -MailNickname $sqlAdminAdGroupName -IsAssignableToRole
        Write-Success "AAD group '$sqlAdminAdGroupName' created"
    }

    ############################
    ""
    "Environment '$environment': Creating SQL identity (this may take a minute)"

    $deployment = New-AzSubscriptionDeployment `
        -Location $config.location `
        -Name ("init-sql-" + (Get-Date).ToString("yyyyMMddHHmmss")) `
        -TemplateFile .\init\sql-identity.bicep `
        -TemplateParameterObject @{
            environment = $environment
        }

    Write-Success "SQL identity for environment '$environment' created"

    # AAD replicates data so future queries might not immediately recognize the newly created object
    $sqlIdentity = $null
    for ($i=1; $i -le 12; $i++) {
        $sqlIdentity = Get-AzADServicePrincipal -ObjectId $deployment.Outputs.sqlIdentityPrincipalId.Value -ErrorAction Ignore
        if ($sqlIdentity) {
            if ($i -gt 1) { Write-Success "Identity found in AAD API" }
            break
        } else {
            "  Identity not yet available in AAD API. Waiting for 10 seconds"
            Start-Sleep -Seconds 10
        }
    }


    ############################
    ""
    "Environment '$environment': Assigning MS Graph API permissions to the SQL identity"

    # https://docs.microsoft.com/en-us/azure/azure-sql/database/authentication-azure-ad-user-assigned-managed-identity?view=azuresql#permissions

    $msGraphSp = Get-AzAdServicePrincipal -ApplicationId "00000003-0000-0000-c000-000000000000"
    $graphAccessToken = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com/"
    $apiUrl = "https://graph.microsoft.com/v1.0/servicePrincipals/$($sqlIdentity.Id)/appRoleAssignments"

    $existingAssignments = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers @{ Authorization = "Bearer $($graphAccessToken.Token)" }

    foreach ($permissionName in $sqlIdentityMsGraphPermissions) {
        #$permissionName = "GroupMember.Read.All"
        $appRoleId = ($msGraphSp.AppRole | Where-Object { $_.Value -eq $permissionName } | Select-Object).Id

        $exists = $existingAssignments.value | Where-Object { $_.appRoleId -eq $appRoleId }
        if ($exists) {
            Write-Success "Permission '$permissionName' already exists"
        } else {
            $body = @{
                appRoleId = $appRoleId
                resourceId = $msGraphSp.Id
                principalId = $sqlIdentity.Id
            }
            Invoke-RestMethod -Uri $apiUrl -Method Post -ContentType "application/json" `
                -Headers @{ Authorization = "Bearer $($graphAccessToken.Token)" } `
                -Body $($body | convertto-json) | Out-Null

            Write-Success "Permission '$permissionName' created"
        }
    }

    ############################
    ""
    "Environment '$environment': Adding SQL server identity to SQL Admins AAD group"

    $sqlAdminAdGroupMembers = Get-AzADGroupMember -GroupObjectId $sqlAdminAdGroup.Id

    if ($sqlAdminAdGroupMembers | Where-Object { $_.Id -eq $sqlIdentity.Id }) {
        Write-Success "Membership for SQL identity already exists in group"
    } else {
        Add-AzADGroupMember -TargetGroupObjectId $sqlAdminAdGroup.Id -MemberObjectId $sqlIdentity.Id
        Write-Success "Member for SQL identity added to group"
    }
}


############################
""
"-----------------"
"GitHub repository"
"-----------------"
""
"Creating GitHub environments"

$gitHubEnvironments = $environments
$gitHubEnvironments += "platform" # A special environment for deploying the platform resources

# There are no CLI methods for managing environments, so we have to use the REST API: https://github.com/cli/cli/issues/5149

$ghEnvironments = Exec { gh api "/repos/$($ghRepo.nameWithOwner)/environments" -H "Accept: application/vnd.github+json" } | ConvertFrom-Json
$ghUser = Exec { gh api "/user" -H "Accept: application/vnd.github+json" } | ConvertFrom-Json

foreach ($environment in $gitHubEnvironments) {
    #$environment = "development"

    if ($ghEnvironments.environments | Where-Object { $_.name -eq $environment }) {
        Write-Success "Environment '$environment' already exists"
    } else {
        $body = @{
            reviewers = @(
                @{ type = "User"; id = $ghUser.id }
            )
        } | ConvertTo-Json -Compress

        $ghEnv = Exec { $body | gh api "/repos/$($ghRepo.nameWithOwner)/environments/$environment" -X PUT -H "Accept: application/vnd.github+json" --input - } | ConvertFrom-Json

        Write-Success "Environment '$environment' created with YOU ($($ghUser.login)) as a required reviewer."
        "    You can modify the protection rules here: $($ghRepo.url)/settings/environments/$($ghEnv.id)/edit"
    }
}


############################
""
"Creating GitHub secrets"

Exec { gh secret set "AZURE_CLIENT_ID" -b $githubIdentity.AppId }
Exec { gh secret set "AZURE_SUBSCRIPTION_ID" -b $((Get-AzContext).Subscription.Id) }
Exec { gh secret set "AZURE_TENANT_ID" -b $((Get-AzContext).Subscription.TenantId) }

Exec { gh secret set "REGISTRY_SERVER" -b $acrName }


""
"Script finished. Push your code to your GitHub repository and use GitHub Actions to deploy the 'Platform'-resources next."
