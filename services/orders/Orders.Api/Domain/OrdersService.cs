using Customers.Api;
using Grpc.Core;
using Microsoft.EntityFrameworkCore;

namespace Orders.Api.Domain;

public class OrdersService : Orders.OrdersBase
{
    private readonly OrdersDbContext _dbContext;
    private readonly Customers.Api.Customers.CustomersClient _customersClient;

    public OrdersService(OrdersDbContext dbContext, Customers.Api.Customers.CustomersClient customersClient)
    {
        _dbContext = dbContext;
        _customersClient = customersClient;
    }

    public override async Task<ListOrdersResponse> ListOrders(ListOrdersRequest request, ServerCallContext context)
    {
        var Orders = await _dbContext.Orders
            .Select(x => ToDto(x))
            .ToListAsync();

        return new ListOrdersResponse
        {
            Orders = { Orders },
        };
    }

    public override async Task<OrderDto> CreateOrder(CreateOrderRequest request, ServerCallContext context)
    {
        if (request.Order is null)
            throw new RpcException(new Status(StatusCode.InvalidArgument, "'order' is missing"));

        if (!string.IsNullOrWhiteSpace(request.Order.OrderId)
            && await _dbContext.Orders.AnyAsync(x => x.OrderId == request.Order.OrderId, context.CancellationToken))
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

        var order = new Order(request.Order);

        _dbContext.Orders.Add(order);

        await _dbContext.SaveChangesAsync(context.CancellationToken);

        return ToDto(order);
    }

    private OrderDto ToDto(Order order)
    {
        return new OrderDto
        {
            OrderId = order.OrderId,
            Customer = new OrderDto.Types.Customer
            {
                CustomerId = order.CustomerId,
                FullName = order.CustomerFullName,
            },
            TotalAmount = order.TotalAmount,
        };
    }
}