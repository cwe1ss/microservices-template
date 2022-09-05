using System.Globalization;
using Customers.Api.Domain;
using Dapr.Client;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddCustomAppInsights();

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

builder.Services.AddHealthChecks()
    .AddDbContextCheck<CustomersDbContext>();

builder.Services.AddDaprClient();

var app = builder.Build();

// Configure the HTTP request pipeline.

app.UseSwagger();
app.UseSwaggerUI();

//app.UseHttpsRedirection();

//app.UseAuthentication();
//app.UseAuthorization();

app.MapCustomHealthCheckEndpoints();

app.MapGrpcService<CustomersService>();
app.MapGrpcReflectionService();

app.MapPost("/publish-event1", async (DaprClient dapr) =>
{
    await dapr.PublishEventAsync("pubsub", "test-topic", new MyEvent1 { Text1 = DateTime.UtcNow.ToString(CultureInfo.InvariantCulture) });
    return Results.Ok();
});

app.MapPost("/publish-event2", async (DaprClient dapr) =>
{
    await dapr.PublishEventAsync("pubsub", "test-topic", new MyEvent2 { Text2 = DateTime.UtcNow.ToString(CultureInfo.InvariantCulture) });
    return Results.Ok();
});

app.MapGet("/", () => "Hello World");

app.Run();


record MyEvent1
{
    public string Text1 { get; set; } = string.Empty;
}

record MyEvent2
{
    public string Text2 { get; set; } = string.Empty;
}
