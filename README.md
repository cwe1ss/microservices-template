# Microservices Architecture Template

This microservices template is targeted at SMEs and smaller teams and focuses on the following key aspects:

* *Use "infrastructure as code" and automation to improve time-to-market and to leverage industry best-practices.*
* *Use serverless hosting to minimize the operations efforts for the team.*
* *Minimize the amount of programming languages to reduce development complexity.*

The template focuses on the **solution architecture** and **infrastructure automation** by leveraging industry best-practices and by finding the "right" compromises when following microservices guidelines, which are often targeted at big corporations.

The template is meant to be a "production-ready starting point" that is easy to extend with your own services. For the most part, it does *not* force any specific software architecture or folder structure within the services.

The template uses the following technologies:
* Microsoft .NET for the microservices
* Azure Container Apps & Dapr for hosting
* Azure PowerShell & Azure Bicep for infrastructure as code
* GitHub for code hosting and GitHub Actions for CI/CD

### Highlights:

* **(Almost) no secrets**
  * Wherever possible, authentication is done via Azure AD and managed identities. This includes GitHub Actions & Azure SQL Database access.
* **Script for connecting GitHub with Azure**
  * With one script, all the necessary resources are created in your GitHub repository and in your Azure account to allow you to deploy from GitHub to Azure.
  * Authentication is done via an Azure AD managed identity and deployments are done via GitHub environments that allow you to set up protection rules (e.g. required reviewers, ...).
* **Fully automated SQL migrations during deployment**
  * The service's identity is automatically added to the SQL database with db_datareader/db_datawriter permissions.
  * EF Core Migrations are automatically applied during deployment by an admin identity with elevated privileges.
* **Sample services for different use cases**
  * gRPC, HTTP APIs, SQL DB, Publish/Subscribe

# Overview

If you look at a microservices solution from an operations view, it can typically be split into 3 parts:

* **Platform**: The *platform* contains global resources that are shared by all environments and services, e.g. the Container registry that contains all Docker images. The platform is set up at the beginning of a project and typically changes very rarely.
* **Environments**: The microservice solution is deployed into one or more *environments*, e.g. "development" and "production". Environments do not share any resources between them. An environment uses the *platform*-resources and contains all its *services*. In many cases, the services of one environment need some resources that are shared by all services of the environment, e.g. a hosting cluster, or some shared networking infrastructure. These shared resources must be set up before any service can be deployed and they might change independently of any service.
* **Services**: A service is the instance of one microservice. It is deployed into one or more environments and contains an app and its dependencies. A service may use shared resources from the *platform* (e.g. the Container Registry) and its *environment* (e.g. hosting cluster). Services might change often and might be created and destroyed at different points during the lifecycle of an environment.

```mermaid
graph TB;
  Platform --> Dev
    Dev(Environment: Development) --> SD1(Service A)
    Dev(Environment: Development) --> SD2(Service B)
    Dev(Environment: Development) --> SD3(Service C)
  Platform --> Prod
    Prod(Environment: Production) --> SP1(Service A)
    Prod(Environment: Production) --> SP2(Service B)
    Prod(Environment: Production) --> SP3(Service C)
```

Since these parts have a different lifecycle and might be managed by different people, we built separate GitHub workflows for each them. This is one important difference to many other templates, where often the entire solution must be deployed at once.

# Platform

For this template, the **platform** contains the following resources that are shared by all environments and their services:

## GitHub repository / GitHub Actions
The code for the microservices and the code for the deployment scripts is stored in a GitHub repository.

The template follows the **monorepo**-pattern by keeping all services in one GitHub repository. This simplifies the developer experience and maximizes the ability to share code.

CI/CD is done via **GitHub Actions**, which allows you to deploy all parts of the system with separate workflows.

The repository is also integrated with [automatic dependency updates via GitHub Dependabot](https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/about-dependabot-version-updates). Dependabot will automatically create pull requests whenever a dependency is updated (currently configured for NuGet only - the configuration file is located here: `.github/dependabot.yml`).

## Azure Managed Identity for GitHub Actions

GitHub Actions uses a user-assigned managed identity to authenticate with Azure. The authentication leverages [federated credentials](https://docs.microsoft.com/en-us/azure/developer/github/connect-from-azure) which means that there are no secrets stored in your GitHub repository!

## Azure Container Registry

Services are built using Docker and container images are stored in an Azure container registry.

As no environment-specific logic should be included in a container image, we do not use an environment-specific registry.

All services are given RBAC-based "AcrPull"-access to the container registry.

## Azure Log Analytics Workspace

Microsoft recommends to start with a single workspace since this reduces the complexity of managing multiple workspaces and in querying data from them
(https://docs.microsoft.com/en-us/azure/azure-monitor/logs/workspace-design).

This template therefore uses one Log Analytics workspace that's shared by all services and environments.

Each environment however uses its own "Application Insights"-instance (which are backed by the shared Log Analytics workspace)

## Azure Storage Account

There is one global Azure Storage account that can be used for data that's needed by all environments and services.

We currently use it to store the SQL migration scripts for services that use Entity Framework Core.

# Environments

An environment in our template consists of the following resources:

## Azure Virtual Network

The Azure Container Apps environment is deployed into a custom VNET to allow you to configure Network Security Groups and to connect the VNET with your existing infrastructure.

You can use VNET peering to connect the VNET to your hub if you use a [Hub-spoke network topology](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke?tabs=cli)

## Azure Container Apps environment

To minimize the operations efforts, we use Azure Container Apps for hosting the microservices system.

The Azure Container Apps environment is created in a `{env}-env`-resource group and is connected to the previously mentioned VNET.

The environment contains a Dapr "pubsub" component that allows services to use Azure Service Bus.

## Azure SQL Server

This template supports Azure SQL Database as the main data storage solution. Azure SQL Database is battle-tested and very flexible in terms of scaling.

Azure SQL Database requires a logical "SQL Server"-resource, which will be shared by all databases. This allows you to enable "Microsoft Defender for SQL" and only pay for one sql server instance.

Unfortunately, the databases and the logical server need to be in the same resource group. This means that service deployments have to add their database to the shared `{env}-sql` resource group.

## Azure Service Bus namespace

This template uses Azure Service Bus for asynchronous communication.

A "Service Bus namespace" is shared by all services and placed in its own `{env}-bus` resource group.

Topics and subscriptions are managed by the Dapr "pubsub"-component. Services can use this component to automatically create topics and subscriptions.

## Azure Application Insights

An environment-specific Application Insights resource is created in a `{env}-monitoring`-resource group that stores its data in the global Log Analytics workspace, so monitoring for an environment can be done via both places.

Having an Application Insights resource per environment allows you to get an environment-specific Application Map and allows for environment-specific alert rules, etc.

## Azure Dashboard

A simple environment-specific dashboard is created that allows you to quickly get an overview about the resources in your environment.

You can extend this dashboard by modifying the dashboard, exporting it to JSON and transforming it into the `./infrastructure/environment/monitoring.bicp`-file.

# Services

Each service in our template consists of the following resources:

## Azure managed identity

A user-assigned identity is created for each service. This identity will be used to access any of its Azure dependencies, like its SQL database or its Azure Key Vault.

The identity will also be assigned the "AcrPull"-role on the global Azure Container Registry, so that Container Apps can pull the image without using a legacy registry password.

## Azure Key Vault

Each service is given its own Azure Key Vault.

The Key Vault is currently used to encrypt/decrypt the "ASP.NET Core Data Protection"-keys but it can also be used for additional custom keys/secrets/certificates.

## Azure Storage Account

Each service is given its own Azure Storage account to store service-specific blobs & files.

The storage account is currently used to store the "ASP.NET Core Data Protection" keys. This is necessary to support Data Protection for apps that use multiple instances.

## Azure Container Apps app

The app itself is hosted in an Azure Container App. The app will be placed in the service resource group, but it's connected to the environment-specific "Azure Container App environment".

We support different kinds of services (`./infrastructure/config.json`) that result in differently configured "Container Apps" (e.g. internal grpc, internal http, public endpoint)

## Optional: Azure SQL Database

A service can opt-in to store data in a Azure SQL Database. If so, a service-specific SQL Database will be created in the environment-specific `{env}-sql`-resource group.

The service-specific identity will be given `db_datareader` & `db_datawriter` rights in this database.

It is currently assumed that the service will use Entity Framework Core with "Migrations" to access the SQL database.

**WARNING**: The deployment will automatically apply any migrations to the database, so you have to be careful when creating new migrations.

# Usage

You can create your own microservices system from this template by following these steps:

* Download this repository
  * You should NOT fork it as you would then inherit its git history
* Adjust the deployment configuration `./infrastructure/config.json`
* Push your changes to a GitHub repository
* Execute the platform initialization script locally `./infrastructure/init-platform.ps1`
* Deploy the shared platform resources via GitHub Actions
* Deploy the shared environment resources via GitHub Actions
* Deploy the sample services via GitHub Actions
* Add your own services
* Add your own environments

## Adjust the deployment configuration

All code to deploy the microservices system is stored in the `./.github` &  `./infrastructure` folders.

The configuration for the entire system is stored in `./infrastructure/config.json` and contains the following important settings:

* Resource prefixes for your platform-resources and environment-resources. All created resources will inherit these prefixes.
* Azure Location
* The list of available services with their service-independent settings.
* The list of available environments, and for each environment:
  * VNET settings
  * Service settings

**IMPORTANT: You MUST adjust this config accordingly before you can deploy the system.**

## Initialize the platform

To automate the deployment of Azure resources, the GitHub repository must be connected to the Azure subscription. As this connection requires elevated permissions and multiple steps, we provide the following script to automates them: `./infrastructure/init-platform.ps1`.

The script will create an Azure AD managed identity that will be used by GitHub Actions to deploy resources to Azure. The credentials of this application will be stored as "secrets" in the GitHub repository.

The script will also create the configured "environments" from `./infrastructure/config.json` in the GitHub repository to allow for environment-specific protection rules when deploying resources.

### Required tools
To run the initialization script, you must have the following tools installed:
* PowerShell 7+: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell
* Azure PowerShell module: https://docs.microsoft.com/en-us/powershell/azure/install-az-ps
* Bicep CLI: https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install
* GitHub CLI: https://github.com/cli/cli#installation

### Executing the script
The script must be executed in a PowerShell session by using the following command.

**Important:** This script must be executed by a user who is an Azure _Global Administrator_ and who has admin permissions in the GitHub repository.

```pwsh
cd .\infrastructure\
.\init-platform.ps1
```

## Deploy the shared platform resources

Once you have connected your GitHub repository with your Azure Account, you can start deploying any other resources via the provided GitHub workflows.

To deploy the platform resources, you have to use the GitHub workflow `.github/workflows/platform.yml` which will be displayed as `1. Platform` in the GitHub Actions UI.

This will create all platform resources that have been documented in the previous "Platform"-chapter.

## Deploy the shared environment resources

Since the environments depend on platform resources, you must wait for your platform deployment to finish.

To deploy the shared environment resources, you have to use the GitHub workflow `.github/workflows/environments.yml` which will be displayed as `2. Environments` in the GitHub Actions UI.

This workflow already uses "GitHub environments" and therefore requires you to approve each environment in the workflow details.

If you want to change the required reviewers for the environment (e.g. to a team, or to somebody else), you have to manually do this via the GitHub UI.

NOTE: The environment deployment may take more than 10 minutes, since some of the resources take a lot of time to be created (e.g. the Container Apps environment).

## Deploy the services

Once the environment has been deployed, you can start to deploy the services.

Each service has its own GitHub workflow. The workflows are stored in `.github/workflows/service-*.yml`.

The workflow is split into multiple stages:
* It will first build the service and store the container image in the global Azure Container Registry
* You can then approve the deployment to each of the environments. Only then will the necessary Azure resources be created.

## Add a new service

TODO

## Add a new environment

* Open `./infrastructure/config.json`
* Duplicate an existing environment section (e.g. `development`).
* Modify the environment name and all its content as desired.
* Add the environment to `./.github/workflows/environments.yml`.
* Add the environment to all `./.github/workflows/service-*.yml` files by duplicating and adjusting an existing `deploy-*`-job.
* Re-run the platform initialization script `./infrastructure/init-platform.ps1`
  * This will create the necessary environment in GitHub and its connection with the Azure subscription.
* Adjust the environment protection rules in GitHub if necessary (required reviewers)
* Deploy the shared resources to the new environment via the GitHub Action
* Deploy services into the new environment via the GitHub Actions

# Deleting all resources

If you want to delete all resources that have been created by this project, you must perform the following *manual* steps:

* Delete the subscription role assignments for the GitHub identity (e.g. `lab-msa-github`)
* Delete all Azure resource groups with the tag `product: (config.platformResourcePrefix)` (e.g. `product: lab-msa`)
  * You should delete all service-groups first, environment-groups second, and platform-groups last.
* Delete Azure AD groups that start with `(config.platformResourcePrefix)-` (e.g. `lab-msa-dev-sql-admins`)
* Delete all secrets from your GitHub repository
* Delete all environments from your GitHub repository
* Delete any GitHub Actions workflow runs
