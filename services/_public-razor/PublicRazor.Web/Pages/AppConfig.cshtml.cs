using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Extensions.Options;
using Microsoft.FeatureManagement;

namespace PublicRazor.Web.Pages;

public class AppConfigModel : PageModel
{
    private readonly IFeatureManager _featureManager;

    public TemplateSettings Settings { get; }

    public string Sentinel { get; }

    public bool SimpleFlagEnabled { get; private set; }

    public bool PercentageFlagEnabled { get; private set; }

    public AppConfigModel(
        IFeatureManager featureManager,
        IOptionsSnapshot<TemplateSettings> options,
        IConfiguration config)
    {
        _featureManager = featureManager;
        Settings = options.Value;
        Sentinel = config["Sentinel"] ?? string.Empty;
    }

    public async Task OnGet()
    {
        List<string> featureNames = new();
        await foreach (var featureName in _featureManager.GetFeatureFlagNamesAsync(HttpContext.RequestAborted))
        {
            featureNames.Add(featureName);
        }
        Console.WriteLine(string.Join(",", featureNames));

        SimpleFlagEnabled = await _featureManager.IsEnabledAsync(TemplateFlags.SimpleFlag, HttpContext.RequestAborted);
        //SimpleFlagEnabled = await _featureManager.IsEnabledAsync("TestFlag");
        PercentageFlagEnabled = await _featureManager.IsEnabledAsync(TemplateFlags.PercentageFlag, HttpContext.RequestAborted);
    }
}
