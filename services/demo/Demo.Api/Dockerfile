#See https://aka.ms/containerfastmode to understand how Visual Studio uses this Dockerfile to build your images for faster debugging.

FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src
COPY ["Directory.Build.props", "Directory.Build.props"]
COPY ["services/demo/Demo.sln", "services/demo/"]
COPY ["services/demo/Demo.Api/Demo.Api.csproj", "services/demo/Demo.Api/"]
RUN dotnet restore "services/demo"
COPY . .
RUN dotnet build "services/demo" -c Release --no-restore

#FROM build as test
#RUN dotnet test "services/demo/Demo.Tests" -c Release --no-build --results-directory /tests --logger "trx;LogFileName=test_results.xml"

FROM build AS publish
RUN dotnet publish "services/demo/Demo.Api/Demo.Api.csproj" -c Release --no-build -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
#COPY --from=test /tests /tests
ENTRYPOINT ["dotnet", "Demo.Api.dll"]
