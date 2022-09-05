using Microsoft.ApplicationInsights.Extensibility;
using Shared.AppInsights;

namespace Microsoft.Extensions.DependencyInjection;

public static class AppInsightsExtensions
{
    public static IServiceCollection AddCustomAppInsights(this IServiceCollection services)
    {
        services.AddApplicationInsightsTelemetry(x =>
        {
            // No need to track performance counters separately as they are tracked in Container Apps anyway.
            x.EnablePerformanceCounterCollectionModule = false;
        });

        services.AddSingleton<ITelemetryInitializer, ApplicationNameTelemetryInitializer>();
        return services;
    }
}
