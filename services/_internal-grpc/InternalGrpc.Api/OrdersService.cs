using Grpc.Core;
using InternalGrpcSqlBus.Api;
using Orders.Api;

namespace InternalGrpc.Api;

public class OrdersService : Orders.Api.Orders.OrdersBase
{
    private static readonly List<OrderDto> Orders = new();

    private readonly Customers.CustomersClient _customersClient;

    public OrdersService(Customers.CustomersClient customersClient)
    {
        _customersClient = customersClient;
    }

    public override Task<ListOrdersResponse> ListOrders(ListOrdersRequest request, ServerCallContext context)
    {
        return Task.FromResult(new ListOrdersResponse
        {
            Orders = { Orders },
        });
    }

    public override async Task<OrderDto> CreateOrder(CreateOrderRequest request, ServerCallContext context)
    {
        if (request.Order is null)
            throw new RpcException(new Status(StatusCode.InvalidArgument, "'order' is missing"));

        if (!string.IsNullOrWhiteSpace(request.Order.OrderId) && Orders.Any(x => x.OrderId == request.Order.OrderId))
            throw new RpcException(new Status(StatusCode.AlreadyExists, "The given id already exists"));

        try
        {
            var customer = await _customersClient.GetCustomerAsync(new GetCustomerRequest
            {
                CustomerId = request.Order?.Customer?.CustomerId ??
                             throw new RpcException(new Status(StatusCode.InvalidArgument, "'customer_id' is missing"))
            });

            request.Order.Customer.FullName = customer.FullName;
        }
        catch (RpcException ex) when (ex.StatusCode == StatusCode.NotFound)
        {
            throw new RpcException(new Status(StatusCode.FailedPrecondition, "order.customer_id does not exist"));
        }

        var order = request.Order.Clone();

        Orders.Add(order);

        return order;
    }
}
