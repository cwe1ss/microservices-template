using Customers.Api.Domain;
using Microsoft.ApplicationInsights.Extensibility;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using Microsoft.EntityFrameworkCore;
using Shared.AppInsights;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
//builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
//    .AddMicrosoftIdentityWebApi(builder.Configuration.GetSection("AzureAd"));

builder.WebHost.UseKestrel(x =>
{
    x.ConfigureEndpointDefaults(o => o.Protocols = HttpProtocols.Http2);
});

builder.Services.AddApplicationInsightsTelemetry(x =>
{
    // No need to track performance counters separately as they are tracked in Container Apps anyway.
    x.EnablePerformanceCounterCollectionModule = false;
});
builder.Services.AddSingleton<ITelemetryInitializer, ApplicationNameTelemetryInitializer>();

builder.Services.AddDbContext<CustomersDbContext>(options =>
{
    options.UseInMemoryDatabase("customers");
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

app.MapGet("/", () => "Hello World");

app.Run();
