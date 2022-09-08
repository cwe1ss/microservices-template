using System.ComponentModel.DataAnnotations;

namespace InternalGrpcSqlBus.Api.Domain;

public class Customer
{
    [MaxLength(36)]
    public string CustomerId { get; protected set; }

    [MaxLength(100)]
    public string FullName { get; protected set; }

    protected Customer()
    {
        // EF Core uses this constructor when loading entities from the database.
        CustomerId = null!;
        FullName = null!;
    }

    public Customer(CustomerDto dto)
    {
        CustomerId = string.IsNullOrWhiteSpace(dto.CustomerId) ? Guid.NewGuid().ToString() : dto.CustomerId;
        FullName = dto.FullName;
    }
}
