using Microsoft.EntityFrameworkCore;

namespace Customers.Api.Domain;

public class CustomersDbContext : DbContext
{
    public DbSet<Customer> Customers => Set<Customer>();

    public CustomersDbContext(DbContextOptions<CustomersDbContext> options)
        : base(options)
    {
    }
}