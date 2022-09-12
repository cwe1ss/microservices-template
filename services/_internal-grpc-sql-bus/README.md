A complex internal service that:
* exposes a gRPC service (with "customers"-entities)
* acts as client to another gRPC server ("internal-grpc")
* stores data in a SQL database
* publishes a "CustomerCreatedEvent" message to the pubsub-topic "customer-created" (subscribed to by "internal-http-bus")
