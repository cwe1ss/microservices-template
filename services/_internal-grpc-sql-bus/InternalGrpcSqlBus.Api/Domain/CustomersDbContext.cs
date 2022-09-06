using Microsoft.EntityFrameworkCore;

namespace InternalGrpcSqlBus.Api.Domain;

public class CustomersDbContext : DbContext
{
    public DbSet<Customer> Customers => Set<Customer>();

    public CustomersDbContext(DbContextOptions<CustomersDbContext> options)
        : base(options)
    {
    }
}
