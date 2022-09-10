using Dapr.Client;
using Grpc.Core;
using InternalGrpc.Api;
using InternalGrpcSqlBus.Api.Domain;
using Microsoft.EntityFrameworkCore;
using Shared;

namespace InternalGrpcSqlBus.Api;

public class CustomersService : Customers.CustomersBase
{
    private readonly CustomersDbContext _dbContext;
    private readonly InternalGrpcEntities.InternalGrpcEntitiesClient _internalGrpcClient;
    private readonly DaprClient _daprClient;
    private readonly ILogger<CustomersService> _logger;

    public CustomersService(
        CustomersDbContext dbContext,
        InternalGrpcEntities.InternalGrpcEntitiesClient internalGrpcClient,
        DaprClient daprClient,
        ILogger<CustomersService> logger)
    {
        _dbContext = dbContext;
        _internalGrpcClient = internalGrpcClient;
        _daprClient = daprClient;
        _logger = logger;
    }

    public override async Task<ListCustomersResponse> ListCustomers(ListCustomersRequest request, ServerCallContext context)
    {
        var customers = await _dbContext.Customers
            .AsNoTracking()
            .ToListAsync();

        return new ListCustomersResponse
        {
            Customers = { customers.Select(ToDto) },
        };
    }

    public override async Task<CustomerDto> GetCustomer(GetCustomerRequest request, ServerCallContext context)
    {
        if (string.IsNullOrWhiteSpace(request.CustomerId))
            throw new RpcException(new Status(StatusCode.InvalidArgument, "'customer_id' is missing"));

        var customer = await _dbContext.Customers.FirstOrDefaultAsync(x => x.CustomerId == request.CustomerId,
                context.CancellationToken);

        return customer is null
            ? throw new RpcException(new Status(StatusCode.NotFound, "customer not found"))
            : ToDto(customer);
    }

    public override async Task<CustomerDto> CreateCustomer(CreateCustomerRequest request, ServerCallContext context)
    {
        if (request.Customer is null)
            throw new RpcException(new Status(StatusCode.InvalidArgument, "'customer' is missing"));

        // Call another internal gRPC service to get some data.
        // (this doesn't actually do anything with the data - it's just here to show a gRPC call)

        var response = await _internalGrpcClient.ListEntitiesAsync(new ListEntitiesRequest(), cancellationToken: context.CancellationToken);
        _logger.LogWarning("External service returned {Response}", response);


        // Persist data to SQL Database via EF Core

        if (!string.IsNullOrWhiteSpace(request.Customer.CustomerId)
            && await _dbContext.Customers.AnyAsync(x => x.CustomerId == request.Customer.CustomerId, context.CancellationToken))
            throw new RpcException(new Status(StatusCode.AlreadyExists, "The given id already exists"));

        var customer = new Customer(request.Customer);

        _dbContext.Customers.Add(customer);

        await _dbContext.SaveChangesAsync(context.CancellationToken);


        // Publish an event via Dapr pub/sub.
        // NOTE: To be safe, this would either require some kind of transactional outbox or to be called in a retry loop.
        //
        // We must manually construct the cloud event because the .NET SDK doesn't change the default "type" (com.dapr.event.sent)
        var evt = DaprHelpers.CreateCloudEvent(new CustomerCreatedEvent
        {
            CustomerId = customer.CustomerId,
        });
        await _daprClient.PublishEventAsync("pubsub", "customer-created", evt, context.CancellationToken);
        _logger.LogWarning("CustomerCreatedEvent event published for {CustomerId}", evt.Data.CustomerId);

        return ToDto(customer);
    }

    private static CustomerDto ToDto(Customer customer)
    {
        return new CustomerDto
        {
            CustomerId = customer.CustomerId,
            FullName = customer.FullName,
        };
    }
}
