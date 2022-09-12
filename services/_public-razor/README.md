A public service that:
* uses ASP.NET Core Razor pages as its frontend architecture
* uses Azure Storage and Azure Key Vault to configure ASP.NET Core DataProtection (required for multi-instance support of anti-forgery tokens, etc.)
* exposes a "/InternalGrpc" page that uses a gRPC-client to talk to the "internal-grpc" service.
* exposes a "/InternalGrpcSqlBus" page that uses a gRPC client to talk to the "internal-grpc-sql-bus" service.
* exposes a "/InternalHttpBus" page that uses DaprClient to talk to the HTTP based "internal-http-bus" service.
