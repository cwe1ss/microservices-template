using System.Collections;
using Dapr.Client;
using InternalGrpc.Api;
using InternalGrpcSqlBus.Api;
using InternalGrpcSqlBus.Api.Domain;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

// Swagger
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

app.Run();
