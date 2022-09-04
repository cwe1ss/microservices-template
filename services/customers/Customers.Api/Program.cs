using System.Globalization;
using Customers.Api.Domain;
using Dapr.Client;
using Microsoft.ApplicationInsights.Extensibility;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.EntityFrameworkCore;
using Shared.AppInsights;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddApplicationInsightsTelemetry(x =>
{
    // No need to track performance counters separately as they are tracked in Container Apps anyway.
    x.EnablePerformanceCounterCollectionModule = false;
});
builder.Services.AddSingleton<ITelemetryInitializer, ApplicationNameTelemetryInitializer>();

builder.Services.AddDbContext<CustomersDbContext>(options =>
{
    options.UseSqlServer(builder.Configuration.GetConnectionString("SQL") ?? throw new ArgumentException("SQL Connection String missing"));
});

builder.Services.AddGrpc(options =>
{
    options.EnableDetailedErrors = true;
});

builder.Services.AddGrpcReflection();
builder.Services.AddGrpcHttpApi();
builder.Services.AddGrpcSwagger();

// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddHealthChecks();
    //.AddDbContextCheck<CustomersDbContext>();

builder.Services.AddDaprClient();

var app = builder.Build();

// Configure the HTTP request pipeline.

app.UseSwagger();
app.UseSwaggerUI();

//app.UseHttpsRedirection();

//app.UseAuthentication();
//app.UseAuthorization();

app.MapGrpcService<CustomersService>();
app.MapGrpcReflectionService();

// https://andrewlock.net/deploying-asp-net-core-applications-to-kubernetes-part-6-adding-health-checks-with-liveness-readiness-and-startup-probes/
app.MapHealthChecks("/healthz/startup"); // Execute all checks on startup
app.MapHealthChecks("/healthz/liveness", new HealthCheckOptions {Predicate = _ => false}); // Liveness only tests if the app can serve requests

app.MapPost("/send", async () =>
{
    var daprClient = new DaprClientBuilder().Build();
    await daprClient.InvokeBindingAsync("customers-test", "create", DateTime.UtcNow.ToString(CultureInfo.InvariantCulture));
    return Results.Ok();
});

app.MapGet("/", () => "Hello World");

app.Run();
