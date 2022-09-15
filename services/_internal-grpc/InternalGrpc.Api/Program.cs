using InternalGrpc.Api;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

// ASP.NET Core
builder.Services.AddSwaggerGen();

// Application Insights
builder.Services.AddCustomAppInsights();

// gRPC Server
builder.Services.AddGrpc(options =>
{
    options.EnableDetailedErrors = true;
});
builder.Services.AddGrpcReflection();
builder.Services.AddGrpcSwagger();

// Health checks
builder.Services.AddHealthChecks();

var app = builder.Build();

// Configure the HTTP request pipeline.

// Swagger
app.UseSwagger();
app.UseSwaggerUI();

// gRPC Server
app.MapGrpcService<InternalGrpcService>();
app.MapGrpcReflectionService();

// Health checks
app.MapCustomHealthCheckEndpoints();


app.MapGet("/", () => "Hello from 'internal-grpc'").ExcludeFromDescription();

app.Run();
