using Customers.Api;
using Customers.Api.Domain;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.Identity.Web;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
//builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
//    .AddMicrosoftIdentityWebApi(builder.Configuration.GetSection("AzureAd"));

builder.Services.AddDbContext<CustomersDbContext>(options =>
{
    options.UseInMemoryDatabase("customers");
});

builder.Services.AddGrpc();
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

app.UseHttpsRedirection();

//app.UseAuthentication();
//app.UseAuthorization();

app.MapGrpcService<CustomersService>();
app.MapGrpcReflectionService();

app.MapGet("/health", () => "OK");
app.MapGet("/", () => "Hello World");

app.Run();
