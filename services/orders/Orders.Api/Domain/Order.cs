using System.Globalization;
using Grpc.Core;

namespace Orders.Api.Domain;

public class Order
{
    public string OrderId { get; protected set; } = null!;
    public string CustomerId { get; protected set; } = null!;
    public string CustomerFullName { get; protected set; } = string.Empty;
    public decimal TotalAmount { get; protected set; }

    protected Order()
    {
        // EF
    }

    public Order(OrderDto dto)
    {
        OrderId = string.IsNullOrWhiteSpace(dto.OrderId) ? Guid.NewGuid().ToString() : dto.OrderId;
            
        CustomerId = dto.Customer.CustomerId;
        CustomerFullName = dto.Customer.FullName;

        TotalAmount = dto.TotalAmount ?? throw new RpcException(new Status(StatusCode.InvalidArgument, "total_amount is missing"));
    }
}
