using Azure.Identity;
using InternalGrpc.Api;
using InternalGrpcSqlBus.Api;
using Microsoft.AspNetCore.DataProtection;
using Shared;

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

// gRPC Clients (uses a custom extension method from Shared)
builder.Services.AddDaprGrpcClient<InternalGrpcEntities.InternalGrpcEntitiesClient>("internal-grpc");
builder.Services.AddDaprGrpcClient<Customers.CustomersClient>("internal-grpc-sql-bus");

// HTTP Clients (uses a custom extension method from Shared)
builder.Services.AddDaprHttpClient("internal-http-bus");

// Health checks
builder.Services.AddHealthChecks();

var app = builder.Build();


// Configure the HTTP request pipeline.

app.UseDeveloperExceptionPage();

app.UseStaticFiles();

app.UseRouting();

app.UseAuthorization();

app.MapRazorPages();

// Health checks
app.MapCustomHealthCheckEndpoints();

app.Run();
