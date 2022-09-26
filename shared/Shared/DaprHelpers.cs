using Dapr;
using Dapr.Client;
using Grpc.Net.ClientFactory;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Shared.AppInsights;

namespace Shared;

public static class DaprHelpers
{
    private static Uri? grpcEndpoint;

    /// <summary>
    /// Get the value of environment variable DAPR_GRPC_PORT
    /// </summary>
    /// <returns>The value of environment variable DAPR_GRPC_PORT</returns>
    public static Uri GetDefaultGrpcEndpoint()
    {
        if (grpcEndpoint == null)
        {
            var port = Environment.GetEnvironmentVariable("DAPR_GRPC_PORT");
            port = string.IsNullOrEmpty(port) ? "50001" : port;
            grpcEndpoint = new Uri($"http://127.0.0.1:{port}");
        }

        return grpcEndpoint;
    }

    public static IHttpClientBuilder AddDaprHttpClient(this IServiceCollection services, string appId)
    {
        services.TryAddSingleton<AppInsightsHttpMessageHandler>();

        var baseUrl = (Environment.GetEnvironmentVariable("BASE_URL") ?? "http://localhost") + ":" + (Environment.GetEnvironmentVariable("DAPR_HTTP_PORT") ?? "3500");

        return services.AddHttpClient(appId, httpClient =>
        {
            httpClient.BaseAddress = new Uri(baseUrl);
            httpClient.DefaultRequestHeaders.Add("dapr-app-id", appId);
        }).AddHttpMessageHandler<AppInsightsHttpMessageHandler>();
    }

    public static IHttpClientBuilder AddDaprGrpcClient<TClient>(this IServiceCollection services, string appId, string? daprEndpoint = null, string? daprApiToken = null)
        where TClient : class
    {
        return services.AddGrpcClient<TClient>(o =>
        {
            o.Address = daprEndpoint != null ? new Uri(daprEndpoint) : GetDefaultGrpcEndpoint();

            // Dapr Interceptor
            o.InterceptorRegistrations.Add(new InterceptorRegistration(InterceptorScope.Channel, _ => new InvocationInterceptor(appId, daprApiToken)));
        }).EnableCallContextPropagation(o => o.SuppressContextNotFoundErrors = true);
    }

    /// <summary>
    /// We must manually construct the cloud event because the .NET SDK doesn't change the default "type" (com.dapr.event.sent)
    /// </summary>
    public static CloudEvent<T> CreateCloudEvent<T>(T message)
    {
        return new CloudEvent<T>(message)
        {
            Type = typeof(T).Name
        };
    }
}
