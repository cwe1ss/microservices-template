using Dapr;
using Dapr.Client;
using Microsoft.AspNetCore.Mvc;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddCustomAppInsights();

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

app.MapGet("/", () => "Hello World").ExcludeFromDescription();

app.MapPost("/publish-event1", async (string text, DaprClient daprClient) =>
{
    await daprClient.PublishEventAsync("pubsub", "topic-a", new MyEvent1
    {
        Text1 = text
    });
});

app.MapPost("/receive1", [Topic("pubsub", "test-topic", $"event.type == \"{nameof(MyEvent1)}\"", 1)] (MyEvent1 evt, ILogger<Program> logger) =>
{
    logger.LogWarning("Event1 received: {evt}", evt);

    return Results.Ok("Event1 received");
});

app.MapPost("/receive2-error", [Topic("pubsub", "test-topic", $"event.type == \"{nameof(MyEvent2)}\"", 2)] (MyEvent2 evt, ILogger<Program> logger) =>
{
    logger.LogWarning("Event2 received: {evt}", evt);

    throw new InvalidOperationException("Some simulated business logic error");
});

app.MapPost("/receive-fallback", [Topic("pubsub", "test-topic")] ([FromBody] CloudEvent evt, ILogger<Program> logger) =>
{
    logger.LogWarning("Fallback event received: {evt}", evt);

    throw new NotSupportedException("No handler for " + evt.Type);

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
