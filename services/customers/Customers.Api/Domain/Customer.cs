using System.ComponentModel.DataAnnotations;

namespace Customers.Api.Domain;
 
public class Customer
{
    [MaxLength(36)]
    public string CustomerId { get; protected set; }

    [MaxLength(100)]
    public string FullName { get; protected set; }

    protected Customer()
    {
        // EF
        CustomerId = null!;
        FullName = null!;
    }

    public Customer(CustomerDto dto)
    {
        CustomerId = string.IsNullOrWhiteSpace(dto.CustomerId) ? Guid.NewGuid().ToString() : dto.CustomerId;
        FullName = dto.FullName;
    }
}
