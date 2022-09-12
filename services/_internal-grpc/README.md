A simple internal gRPC server that:
* exposes a gRPC service for listing/creating "entitites" (will be used by "internal-grpc-sql-bus" and "public-razor").
* does not have any external dependencies, so it does not even use Dapr.
