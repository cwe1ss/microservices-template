using Dapr;
using InternalGrpcSqlBus.Api;
using Microsoft.AspNetCore.Mvc;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddCustomAppInsights();

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddDaprClient();

builder.Services.AddHealthChecks();

var app = builder.Build();

// Configure the HTTP request pipeline.

app.UseSwagger();
app.UseSwaggerUI();

app.UseCloudEvents();
app.MapSubscribeHandler();

app.MapCustomHealthCheckEndpoints();

// Custom endpoints

app.MapGet("/", () => "Hello from 'internal-http-bus'").ExcludeFromDescription();


// The simplest of all demo in-memory stores.
HashSet<string> customerIds = new();

app.MapGet("/received-customers", () => Results.Ok(customerIds.ToArray()));

app.MapPost("/receive-customer-created", [Topic("pubsub", "customer-created", $"event.type == \"{nameof(CustomerCreatedEvent)}\"", 1)] (CustomerCreatedEvent evt, ILogger<Program> logger) =>
{
    logger.LogWarning("Customer received: {evt}", evt);

    customerIds.Add(evt.CustomerId);

    return Results.Ok("Customer received");
});

app.MapPost("/receive-fallback", [Topic("pubsub", "test-topic")] ([FromBody] CloudEvent evt, ILogger<Program> logger) =>
{
    logger.LogWarning("Fallback event received: {evt}", evt);

    throw new NotSupportedException("No handler for " + evt.Type);
});


app.Run();
