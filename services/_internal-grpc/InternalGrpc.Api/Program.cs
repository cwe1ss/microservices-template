using Dapr.Client;
using InternalGrpc.Api;
using InternalGrpcSqlBus.Api;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddCustomAppInsights();

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
//builder.Services.AddGrpcClient<Customers.Api.Customers.CustomersClient>(options =>
//{
//    //options.Address = new Uri("https://localhost:7088");
//    options.Creator = _ => DaprClient.CreateInvocationInvoker("customers");
//});
builder.Services.AddTransient(_ =>
{
    // TODO invoker should be singleton according to docs
    var invoker = DaprClient.CreateInvocationInvoker("internal-grpc-sql-bus");
    var client = new Customers.CustomersClient(invoker);
    return client;
});

// Health checks
builder.Services.AddHealthChecks();

var app = builder.Build();

// Configure the HTTP request pipeline.

app.UseSwagger();
app.UseSwaggerUI();

app.MapGrpcService<OrdersService>();
app.MapGrpcReflectionService();

app.MapCustomHealthCheckEndpoints();

app.MapGet("/", () => "Hello World").ExcludeFromDescription();

app.Run();
