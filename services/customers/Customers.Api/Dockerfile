#See https://aka.ms/containerfastmode to understand how Visual Studio uses this Dockerfile to build your images for faster debugging.

FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src
COPY ["Directory.Build.props", "Directory.Build.props"]
COPY ["services/customers/Customers.sln", "services/customers/"]
COPY ["services/customers/Customers.Api/Customers.Api.csproj", "services/customers/Customers.Api/"]
COPY ["shared/Shared/Shared.csproj", "shared/Shared/"]
RUN dotnet restore "services/customers"
COPY . .
RUN dotnet build "services/customers" -c Release --no-restore

#FROM build as test
#RUN dotnet test "services/customers/Customers.Tests" -c Release --no-build --results-directory /tests --logger "trx;LogFileName=test_results.xml"

FROM build AS publish
RUN dotnet publish "services/customers/Customers.Api/Customers.Api.csproj" -c Release --no-build -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
#COPY --from=test /tests /tests
ENTRYPOINT ["dotnet", "Customers.Api.dll"]

# ENV ASPNETCORE_Kestrel__Endpoints__GRPC__Protocols=Http2
# ENV ASPNETCORE_Kestrel__Endpoints__GRPC__URL=http://*:80
# ENV ASPNETCORE_Kestrel__Endpoints__WEB__Protocols=Http1
# ENV ASPNETCORE_Kestrel__Endpoints__WEB__URL=http://*:8080
EXPOSE 8080
