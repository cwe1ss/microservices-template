using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;

namespace Shared.AppInsights;

/// <summary>
/// Sends the response body of failed requests to Application Insights to simplify troubleshooting.
/// </summary>
public class AppInsightsHttpMessageHandler : DelegatingHandler
{
    private readonly TelemetryClient _telemetryClient;

    public AppInsightsHttpMessageHandler(TelemetryClient telemetryClient)
    {
        _telemetryClient = telemetryClient;
    }

    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var response = await base.SendAsync(request, cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            int responseStatus = (int)response.StatusCode;

            var responseBody = await response.Content.ReadAsStringAsync(cancellationToken);

            _telemetryClient.TrackTrace(
                "Http call returned non-success status " + responseStatus,
                SeverityLevel.Warning,
                new Dictionary<string, string>
                {
                    {"ResultCode", responseStatus.ToString()},
                    {"ResponseBody", responseBody}
                });
        }

        return response;
    }
}
