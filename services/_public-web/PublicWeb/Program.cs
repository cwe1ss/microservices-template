using Dapr.Client;
using InternalGrpc.Api;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

// Application Insights
builder.Services.AddCustomAppInsights();

// gRPC Clients
var internalGrpcInvoker = DaprClient.CreateInvocationInvoker("internal-grpc"); // invoker should be singleton according to docs
builder.Services.AddTransient(_ => new InternalGrpcEntities.InternalGrpcEntitiesClient(internalGrpcInvoker));

// Health checks
builder.Services.AddHealthChecks();

var app = builder.Build();


// Configure the HTTP request pipeline.

// Health checks
app.MapCustomHealthCheckEndpoints();

app.MapGet("/", () => "Hello from 'public-web'");

app.MapGet("/entities", async (HttpContext context, InternalGrpcEntities.InternalGrpcEntitiesClient internalGrpcClient) =>
{
    var response = await internalGrpcClient.ListEntitiesAsync(new ListEntitiesRequest(), cancellationToken: context.RequestAborted);
    return Results.Ok(response);
});

app.Run();
