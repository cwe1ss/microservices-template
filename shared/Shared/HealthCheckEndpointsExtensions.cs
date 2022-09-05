using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.Routing;

namespace Microsoft.AspNetCore.Builder;

public static class HealthCheckEndpointsExtensions
{
    public static IEndpointRouteBuilder MapCustomHealthCheckEndpoints(this IEndpointRouteBuilder app)
    {
        // https://andrewlock.net/deploying-asp-net-core-applications-to-kubernetes-part-6-adding-health-checks-with-liveness-readiness-and-startup-probes/
        app.MapHealthChecks("/healthz/startup"); // Execute all checks on startup
        app.MapHealthChecks("/healthz/liveness", new HealthCheckOptions { Predicate = _ => false }); // Liveness only tests if the app can serve requests

        return app;
    }
}
