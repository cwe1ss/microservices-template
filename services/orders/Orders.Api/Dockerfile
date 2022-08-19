#See https://aka.ms/containerfastmode to understand how Visual Studio uses this Dockerfile to build your images for faster debugging.

FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src
COPY ["Directory.Build.props", "Directory.Build.props"]
COPY ["services/orders/Orders.sln", "services/orders/"]
COPY ["shared/Shared/Shared.csproj", "shared/Shared/"]
COPY ["services/orders/Orders.Api/Orders.Api.csproj", "services/orders/Orders.Api/"]
RUN dotnet restore "services/orders"
COPY . .
RUN dotnet build "services/orders" -c Release --no-restore

#FROM build as test
#RUN dotnet test "services/orders/Orders.Tests" -c Release --no-build --results-directory /tests --logger "trx;LogFileName=test_results.xml"

FROM build AS publish
RUN dotnet publish "services/orders/Orders.Api/Orders.Api.csproj" -c Release --no-build -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
#COPY --from=test /tests /tests
ENTRYPOINT ["dotnet", "Orders.Api.dll"]
