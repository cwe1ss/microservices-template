namespace Customers.Api.Domain;
 
public class Customer
{
    public string CustomerId { get; protected set; } = null!;
    public string FullName { get; protected set; } = string.Empty;

    protected Customer()
    {
        // EF
    }

    public Customer(CustomerDto dto)
    {
        CustomerId = string.IsNullOrWhiteSpace(dto.CustomerId) ? Guid.NewGuid().ToString() : dto.CustomerId;
        FullName = dto.FullName;
    }
}
