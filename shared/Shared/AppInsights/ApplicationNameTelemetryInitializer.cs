using Microsoft.ApplicationInsights.Channel;
using Microsoft.ApplicationInsights.Extensibility;

namespace Shared.AppInsights;

public class ApplicationNameTelemetryInitializer : ITelemetryInitializer
{
    private readonly string? _appId;

    public ApplicationNameTelemetryInitializer()
    {
        // Dapr App Id
        // https://docs.dapr.io/reference/environment/
        _appId = Environment.GetEnvironmentVariable("APP_ID");
    }

    public void Initialize(ITelemetry telemetry)
    {
        if (!string.IsNullOrEmpty(_appId))
        {
            telemetry.Context.Cloud.RoleName = _appId;
        }
    }
}
