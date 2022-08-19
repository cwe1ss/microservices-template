using Dapr.Client;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using Microsoft.EntityFrameworkCore;
using Orders.Api.Domain;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
//builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
//    .AddMicrosoftIdentityWebApi(builder.Configuration.GetSection("AzureAd"));

builder.WebHost.UseKestrel(x =>
{
    x.ConfigureEndpointDefaults(o => o.Protocols = HttpProtocols.Http2);
});

builder.Services.AddApplicationInsightsTelemetry();

builder.Services.AddDbContext<OrdersDbContext>(options =>
{
    options.UseInMemoryDatabase("orders");
});

//builder.Services.AddGrpcClient<Customers.Api.Customers.CustomersClient>(options =>
//{
//    //options.Address = new Uri("https://localhost:7088");
//    options.Creator = _ => DaprClient.CreateInvocationInvoker("customers");
//});

builder.Services.AddDaprClient();
builder.Services.AddTransient<Customers.Api.Customers.CustomersClient>(sp =>
{
    var invoker = DaprClient.CreateInvocationInvoker("customers");
    var client = new Customers.Api.Customers.CustomersClient(invoker);
    return client;
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

var app = builder.Build();

// Configure the HTTP request pipeline.
app.UseSwagger();
app.UseSwaggerUI();

//app.UseHttpsRedirection();

//app.UseAuthentication();
//app.UseAuthorization();

app.MapGrpcService<OrdersService>();
app.MapGrpcReflectionService();

app.MapGet("/health", () => "OK");
app.MapGet("/", () => "Service: orders");

app.Run();
