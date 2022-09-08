using InternalGrpc.Api;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

// ASP.NET Core
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddHealthChecks();

// Application Insights
builder.Services.AddCustomAppInsights();

// gRPC Server
builder.Services.AddGrpc(options =>
{
    options.EnableDetailedErrors = true;
});
builder.Services.AddGrpcReflection();
builder.Services.AddGrpcHttpApi();
builder.Services.AddGrpcSwagger();

var app = builder.Build();

// Configure the HTTP request pipeline.

app.UseSwagger();
app.UseSwaggerUI();

app.MapGrpcService<InternalGrpcServiceImpl>();
app.MapGrpcReflectionService();

app.MapCustomHealthCheckEndpoints();

app.MapGet("/", () => "Hello World").ExcludeFromDescription();

app.Run();
