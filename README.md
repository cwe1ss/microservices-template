# Microservices Architecture Template

This project contains a template for a .NET & Azure-based microservices system.



## Requirements

* winget install -e --id Microsoft.Bicep
* Azure PowerShell
* (Azure CLI)

## Github

* Environments:
  * development
  * production

* Secrets:
  * REGISTRY_SERVER - e.g. myregistry.azurecr.io


## Platform initialization

To automate the deployment of Azure resources, the GitHub repository must be connected to the Azure subscription. As this connection requires elevated permissions and multiple steps, we provide the script `.\infrastructure\init-platform.ps1` to automates them.

The script will perform the following steps:
* An Azure AD application will be created. It will be used by GitHub Actions to deploy resources to Azure.
* The application will be given 'Group.Read.All' and 'Group.Create' permissions in Azure Active Directory (to create environment-specific AAD groups)
* The application will be given 'Contributor' and 'User Access Administrator' roles in your Azure subscription (to create Azure-resources during deployment)
* Your GitHub repository will be configured with the necessary secrets (to authenticate as the given Azure AD application)
* The configured 'environments' from `.\infrastructure\_config.json` will be created in your GitHub repository.

### Required tools
To run the initialization script, you must have the following tools installed:
* PowerShell 7+: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell
* Azure PowerShell: https://docs.microsoft.com/en-us/powershell/azure/install-az-ps
* GitHub CLI: https://github.com/cli/cli#installation

### Executing the script
The script must be executed in a PowerShell session by using the following command.

**Important:** Running this script requires elevated permissions. It must be executed by a user who is an Azure _Global Administrator_ and who has admin permissions in the GitHub repository.

```pwsh
cd .\infrastructure\
.\init-platform.ps1
```

## Platform

The "platform" contains resources that are shared by all services in all environments.

The platform resources must be deployed first.

Deployment can be initiated via the GitHub Action 

### Azure Container Registry

Services are built using Docker and stored in a Azure container registry. As no environment-specific logic should be included in a container image, we do not need 
a environment-specific registry.

All environments are given RBAC-based "pull"-access to the container registry.

### Azure Monitor Log Analytics Workspace

Microsoft recommends to start with a single workspace since this reduces the complexity of managing multiple workspaces and in querying data from them
(https://docs.microsoft.com/en-us/azure/azure-monitor/logs/workspace-design).

This template therefore uses one workspace that's shared by all environments.



# Configuration

