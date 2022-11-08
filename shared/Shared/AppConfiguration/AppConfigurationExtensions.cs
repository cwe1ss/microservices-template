using Azure.Core;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.FeatureManagement;
using Microsoft.FeatureManagement.FeatureFilters;
using Shared.AppConfiguration;

namespace Microsoft.Extensions.DependencyInjection;

public static class AppConfigurationExtensions
{
    public static WebApplicationBuilder AddCustomAppConfiguration(this WebApplicationBuilder builder, TokenCredential tokenCredential)
    {
        // TODO: Remove once FeatureManagement library 3.0.0 is GA
        //
        // Opt-in to use new schema with features received from Azure App Configuration
        Environment.SetEnvironmentVariable("AZURE_APP_CONFIGURATION_FEATURE_MANAGEMENT_SCHEMA_VERSION", "2");

        builder.Configuration.AddAzureAppConfiguration(options =>
        {
            // We use the environment names from "Service Connector" as there's no other standard.
            // https://learn.microsoft.com/en-us/azure/service-connector/how-to-integrate-app-configuration?tabs=app-service#default-environment-variable-names-or-application-properties

            var connectionString = builder.Configuration["AZURE_APPCONFIGURATION_CONNECTIONSTRING"] ?? string.Empty;
            var endpoint = builder.Configuration["AZURE_APPCONFIGURATION_ENDPOINT"] ?? string.Empty;

            if (!string.IsNullOrWhiteSpace(connectionString))
            {
                options.Connect(connectionString);
            }
            else if (!string.IsNullOrWhiteSpace(endpoint))
            {
                options.Connect(new Uri(endpoint), tokenCredential);
            }
            else
            {
                throw new InvalidOperationException("Environment variable 'AZURE_APPCONFIGURATION_ENDPOINT' not set.");
            }

            options.ConfigureRefresh(refreshOptions => refreshOptions.Register("Sentinel", refreshAll: true));

            options.UseFeatureFlags();
        });

        builder.Services.AddAzureAppConfiguration();

        // This will automatically add the middleware to the ASP.NET Core Pipeline, which will trigger the refresh.
        // Since it's a middleware, the configuration will not be refreshed if the application is idle. This fits very
        // good with Azure Container Apps idle mode.
        // https://learn.microsoft.com/en-us/azure/azure-app-configuration/enable-dynamic-configuration-aspnet-core?tabs=core6x#request-driven-configuration-refresh
        //
        // Remove this and call `app.UseAzureAppConfiguration()` manually in your app if you want it at a specific
        // location in your pipeline.
        builder.Services.AddTransient<IStartupFilter, AppConfigurationStartupFilter>();

        // Enables Feature Management with support for the built-in filter types.
        builder.Services.AddFeatureManagement(builder.Configuration.GetSection("FeatureManagement:FeatureFlags:Template"))
            .AddFeatureFilter<PercentageFilter>()
            .AddFeatureFilter<TargetingFilter>()
            .AddFeatureFilter<TimeWindowFilter>();

        // TargetingFilter requires a service that knows how to get the UserId & Groups from the current user
        // and that service requires a way to access the user from the current HTTP request.
        builder.Services.AddSingleton<ITargetingContextAccessor, HttpContextTargetingContextAccessor>();
        builder.Services.TryAddSingleton<IHttpContextAccessor, HttpContextAccessor>();

        builder.Services.Configure<FeatureManagementOptions>(options => options.IgnoreMissingFeatures = false);

        return builder;
    }

    public class AppConfigurationStartupFilter : IStartupFilter
    {
        public Action<IApplicationBuilder> Configure(Action<IApplicationBuilder> next)
        {
            return builder =>
            {
                builder.UseAzureAppConfiguration();
                next(builder);
            };
        }
    }
}
