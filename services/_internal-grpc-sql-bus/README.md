A complex internal service that:
* exposes a gRPC server (with "customers"-entities)
* acts as client to another gRPC server (internal-grpc)
* stores data in a SQL database
* publishes events to pub/sub
