using InternalGrpc.Api;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace PublicRazor.Web.Pages;

public class InternalGrpcModel : PageModel
{
    private readonly InternalGrpcEntities.InternalGrpcEntitiesClient _internalGrpcClient;

    public IList<InternalGrpcEntityDto> Entities { get; private set; } = new List<InternalGrpcEntityDto>();

    [BindProperty]
    public string? NewEntityDisplayName { get; set; }

    public InternalGrpcModel(InternalGrpcEntities.InternalGrpcEntitiesClient internalGrpcClient)
    {
        _internalGrpcClient = internalGrpcClient;
    }

    public async Task<IActionResult> OnGetAsync()
    {
        var response = await _internalGrpcClient.ListEntitiesAsync(new ListEntitiesRequest(), cancellationToken: HttpContext.RequestAborted);
        Entities = response.Entities;

        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid)
        {
            return Page();
        }

        if (!string.IsNullOrWhiteSpace(NewEntityDisplayName))
        {
            var request = new CreateEntityRequest
            {
                Entity = new InternalGrpcEntityDto()
                {
                    EntityId = Guid.NewGuid().ToString(),
                    DisplayName = NewEntityDisplayName,
                }
            };
            await _internalGrpcClient.CreateEntityAsync(request, cancellationToken: HttpContext.RequestAborted);
        }

        return RedirectToPage();
    }
}
