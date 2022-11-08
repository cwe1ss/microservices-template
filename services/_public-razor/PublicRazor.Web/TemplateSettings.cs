namespace PublicRazor.Web;

public class TemplateSettings
{
    public string SimpleKey { get; set; } = string.Empty;
    public string EnvironmentSpecific { get; set; } = string.Empty;

    public JsonKeyType? JsonKey { get; set; }

    public class JsonKeyType
    {
        public string SomeField { get; set; } = string.Empty;
    }
}
