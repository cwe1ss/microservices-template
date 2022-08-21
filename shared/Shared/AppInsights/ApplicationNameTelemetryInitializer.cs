using Microsoft.ApplicationInsights.Channel;
using Microsoft.ApplicationInsights.Extensibility;

namespace Shared.AppInsights;

/// <summary>
/// Sets the "RoleName" for each telemetry.
/// </summary>
public class ApplicationNameTelemetryInitializer : ITelemetryInitializer
{
    private readonly string _appId;

    public ApplicationNameTelemetryInitializer()
    {
        // Dapr APP_ID
        // https://docs.dapr.io/reference/environment/
        _appId = Environment.GetEnvironmentVariable("APP_ID") ?? string.Empty;
    }

    public void Initialize(ITelemetry telemetry)
    {
        telemetry.Context.Cloud.RoleName = _appId;
    }
}
