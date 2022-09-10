An internal service that:
* exposes a HTTP API
* uses Dapr pub/sub to subscribe to "CustomerCreatedEvent"-events from the topic "customer-created" (published to by "internal-grpc-sql-bus")
* Any event coming to that topic that is not a "CustomerCreatedEvent" event, will be subscribed to by "/receive-fallback" and an error will be logged.
* returns the list of customer ids in the endpoint "/received-customers"
