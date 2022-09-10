using Azure.Identity;
using Dapr.Client;
using InternalGrpc.Api;
using InternalGrpcSqlBus.Api;
using Microsoft.AspNetCore.DataProtection;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

// Azure
var azureCredential = new DefaultAzureCredential();

// ASP.NET Core
builder.Services.AddRazorPages();

// ASP.NET Core Data Protection (to support e.g. anti-forgery with multiple instances)
var dataProtectionBuilder = builder.Services.AddDataProtection();
if (!builder.Environment.IsDevelopment())
{
    dataProtectionBuilder.PersistKeysToAzureBlobStorage(
        blobUri: new Uri(builder.Configuration["DataProtectionBlobUri"] ?? throw new InvalidOperationException("Config value 'DataProtectionBlobUri' not set")),
        tokenCredential: azureCredential);

    dataProtectionBuilder.ProtectKeysWithAzureKeyVault(
        keyIdentifier: new Uri(builder.Configuration["DataProtectionKeyUri"] ?? throw new InvalidOperationException("Config value 'DataProtectionKeyUri' not set")),
        tokenCredential: azureCredential);
}

// Application Insights
builder.Services.AddCustomAppInsights();

// gRPC Clients
var internalGrpcInvoker = DaprClient.CreateInvocationInvoker("internal-grpc"); // invoker should be singleton according to docs
var internalGrpcSqlBusInvoker = DaprClient.CreateInvocationInvoker("internal-grpc-sql-bus");
builder.Services.AddTransient(_ => new InternalGrpcEntities.InternalGrpcEntitiesClient(internalGrpcInvoker));
builder.Services.AddTransient(_ => new Customers.CustomersClient(internalGrpcSqlBusInvoker));

// HTTP Clients
var baseUrl = (Environment.GetEnvironmentVariable("BASE_URL") ?? "http://localhost") + ":" + (Environment.GetEnvironmentVariable("DAPR_HTTP_PORT") ?? "3500");
builder.Services.AddHttpClient("internal-http-bus", (httpClient) =>
{
    httpClient.BaseAddress = new Uri(baseUrl);
    httpClient.DefaultRequestHeaders.Add("dapr-app-id", "internal-http-bus");
});

// Health checks
builder.Services.AddHealthChecks();

var app = builder.Build();


// Configure the HTTP request pipeline.

app.UseDeveloperExceptionPage();

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

app.UseAuthorization();

app.MapRazorPages();

// Health checks
app.MapCustomHealthCheckEndpoints();

app.Run();
