An internal service that:
* uses Dapr pub/sub to subscribe to "CustomerCreatedEvent"-events from the topic "customer-created" (published by "internal-grpc-sql-bus")
* has a "/receive-fallback"-endpoint which subscribes to any message coming to that topic that is not a "CustomerCreatedEvent" event and logs it as an error.
* exposes a HTTP API endpoint "GET /received-customers": It returns data about the "CustomerCreatedEvent"-messages it received from "internal-grpc-sql-bus"
