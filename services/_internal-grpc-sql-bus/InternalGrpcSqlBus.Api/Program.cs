using System.Collections;
using System.Globalization;
using Dapr.Client;
using Grpc.Net.ClientFactory;
using InternalGrpc.Api;
using InternalGrpcSqlBus.Api;
using InternalGrpcSqlBus.Api.Domain;
using Microsoft.EntityFrameworkCore;
using Shared;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

// Swagger
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Application Insights
builder.Services.AddCustomAppInsights();

// Dapr
builder.Services.AddDaprClient();

// gRPC Server
builder.Services.AddGrpc(options =>
{
    options.EnableDetailedErrors = true;
});
builder.Services.AddGrpcReflection();
builder.Services.AddGrpcHttpApi();
builder.Services.AddGrpcSwagger();

// gRPC Clients
// TODO Can we make this work with .AddGrpcClient() ??
var internalGrpcInvoker = DaprClient.CreateInvocationInvoker("internal-grpc"); // invoker should be singleton according to docs
builder.Services.AddTransient(_ => new InternalGrpcEntities.InternalGrpcEntitiesClient(internalGrpcInvoker));

// EF Core
builder.Services.AddDbContext<CustomersDbContext>(options =>
{
    options.UseSqlServer(builder.Configuration.GetConnectionString("SQL") ?? throw new ArgumentException("SQL Connection String missing"));
});

// Health checks
builder.Services.AddHealthChecks()
    .AddDbContextCheck<CustomersDbContext>();

var app = builder.Build();

foreach (DictionaryEntry environmentVariable in Environment.GetEnvironmentVariables())
{
    Console.WriteLine($"{environmentVariable.Key}: {environmentVariable.Value}");
}


// Configure the HTTP request pipeline.

app.UseDeveloperExceptionPage();

// Swagger
app.UseSwagger();
app.UseSwaggerUI();

// gRPC Server
app.MapGrpcService<CustomersService>();
app.MapGrpcReflectionService();

// Health checks
app.MapCustomHealthCheckEndpoints();

app.MapGet("/", () => "Hello from 'internal-grpc-sql-bus'").ExcludeFromDescription();

app.MapPost("/publish-event1", async (DaprClient dapr) =>
{
    // We must manually construct the cloud event because the .NET SDK doesn't change the default "type" (com.dapr.event.sent)
    var evt = DaprHelpers.CreateCloudEvent(new MyEvent1
    {
        Text1 = DateTime.UtcNow.ToString(CultureInfo.InvariantCulture)
    });
    await dapr.PublishEventAsync("pubsub", "test-topic", evt);
    return Results.Ok();
});

app.MapPost("/publish-event2", async (DaprClient dapr) =>
{
    // We must manually construct the cloud event because the .NET SDK doesn't change the default "type" (com.dapr.event.sent)
    var evt = DaprHelpers.CreateCloudEvent(new MyEvent2
    {
        Text2 = DateTime.UtcNow.ToString(CultureInfo.InvariantCulture)
    });
    await dapr.PublishEventAsync("pubsub", "test-topic", evt);
    return Results.Ok();
});

app.MapPost("/publish-event3", async (DaprClient dapr) =>
{
    // We must manually construct the cloud event because the .NET SDK doesn't change the default "type" (com.dapr.event.sent)
    var evt = DaprHelpers.CreateCloudEvent(new MyEvent3
    {
        Text3 = DateTime.UtcNow.ToString(CultureInfo.InvariantCulture)
    });
    await dapr.PublishEventAsync("pubsub", "test-topic", evt);
    return Results.Ok();
});

app.Run();


record MyEvent1
{
    public string Text1 { get; set; } = string.Empty;
}

record MyEvent2
{
    public string Text2 { get; set; } = string.Empty;
}

record MyEvent3
{
    public string Text3 { get; set; } = string.Empty;
}
