# Microservices Architecture Template

This project contains a template for a .NET & Azure-based microservices system.

## Usage

* Download this repository (or fork it if you don't mind its git history)
* Adjust the deployment configuration `.\infrastructure\_config.json`
* Push your changes to a GitHub repository
* Execute the platform initialization script locally `.\infrastructure\init-platform.ps1`
* Deploy the shared platform resources via GitHub Actions
* Deploy the shared environment resources via GitHub Actions
* Deploy the sample services via GitHub Actions

## Requirements

* winget install -e --id Microsoft.Bicep
* Azure PowerShell

## Platform initialization

To automate the deployment of Azure resources, the GitHub repository must be connected to the Azure subscription. As this connection requires elevated permissions and multiple steps, we provide the following script to automates them: `.\infrastructure\init-platform.ps1`.

The script will create an Azure AD application that will be used by GitHub Actions to deploy resources to Azure. The credentials of this application will be stored as "secrets" in the GitHub repository.

The script will also create the configured "environments" from `.\infrastructure\_config.json` in the GitHub repository to allow for environment-specific protection rules when deploying resources.

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

The "platform" contains resources that are shared by all services in all environments. The platform resources must therefore be deployed first.

### Azure Container Registry

Services are built using Docker and stored in a Azure container registry. As no environment-specific logic should be included in a container image, we do not need 
a environment-specific registry.

All environments are given RBAC-based "pull"-access to the container registry.

### Azure Monitor Log Analytics Workspace

Microsoft recommends to start with a single workspace since this reduces the complexity of managing multiple workspaces and in querying data from them
(https://docs.microsoft.com/en-us/azure/azure-monitor/logs/workspace-design).

This template therefore uses one workspace that's shared by all environments.

## Environments

* development
* production


# Configuration

## Adding a new environment

* Open `.\infrastructure\_config.json`
* Duplicate an existing environment section (e.g. `development`).
* Modify the environment name and all its content as desired.
* Re-run the platform initialization script `.\infrastructure\init-platform.ps1`
  * This will create the necessary environment in GitHub and its connection with the Azure subscription.
* Create a new deployment for the environment GitHub action and approve the new environment
* Create new deployments for all service GitHub actions and approve the new environment
