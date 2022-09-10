using InternalGrpcSqlBus.Api;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace PublicRazor.Web.Pages;

public class InternalGrpcSqlBusModel : PageModel
{
    private readonly Customers.CustomersClient _customersClient;

    public IList<CustomerDto> Customers { get; private set; } = new List<CustomerDto>();

    [BindProperty]
    public string? NewCustomerFullName { get; set; }

    public InternalGrpcSqlBusModel(Customers.CustomersClient customersClient)
    {
        _customersClient = customersClient;
    }

    public async Task<IActionResult> OnGetAsync()
    {
        var response = await _customersClient.ListCustomersAsync(new ListCustomersRequest(), cancellationToken: HttpContext.RequestAborted);
        Customers = response.Customers;

        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid)
        {
            return Page();
        }

        if (!string.IsNullOrWhiteSpace(NewCustomerFullName))
        {
            var request = new CreateCustomerRequest()
            {
                Customer = new CustomerDto()
                {
                    CustomerId = Guid.NewGuid().ToString(),
                    FullName = NewCustomerFullName,
                }
            };
            await _customersClient.CreateCustomerAsync(request, cancellationToken: HttpContext.RequestAborted);
        }

        return RedirectToPage();
    }
}
