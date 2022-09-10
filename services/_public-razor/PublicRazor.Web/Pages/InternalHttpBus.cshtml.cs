using Microsoft.AspNetCore.Mvc.RazorPages;

namespace PublicRazor.Web.Pages;

public class InternalHttpBusModel : PageModel
{
    private readonly IHttpClientFactory _httpClientFactory;

    public List<string> CustomerIds { get; private set; } = new();

    public InternalHttpBusModel(IHttpClientFactory httpClientFactory)
    {
        _httpClientFactory = httpClientFactory;
    }

    public async Task OnGet()
    {
        var httpClient = _httpClientFactory.CreateClient("internal-http-bus");

        var receivedCustomers = await httpClient.GetFromJsonAsync<List<string>>("/received-customers")
            ?? new List<string>();
        CustomerIds = receivedCustomers;
    }
}
