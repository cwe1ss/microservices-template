using Grpc.Core;
using Microsoft.EntityFrameworkCore;

namespace Customers.Api.Domain;

public class CustomersService : Customers.CustomersBase
{
    private readonly CustomersDbContext _dbContext;

    public CustomersService(CustomersDbContext dbContext)
    {
        _dbContext = dbContext;
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

        if (!string.IsNullOrWhiteSpace(request.Customer.CustomerId) 
            && await _dbContext.Customers.AnyAsync(x => x.CustomerId == request.Customer.CustomerId, context.CancellationToken))
            throw new RpcException(new Status(StatusCode.AlreadyExists, "The given id already exists"));

        var customer = new Customer(request.Customer);

        _dbContext.Customers.Add(customer);

        await _dbContext.SaveChangesAsync(context.CancellationToken);

        return ToDto(customer);
    }

    private CustomerDto ToDto(Customer customer)
    {
        return new CustomerDto
        {
            CustomerId = customer.CustomerId,
            FullName = customer.FullName,
        };
    }
}
