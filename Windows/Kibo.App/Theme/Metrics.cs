
namespace Kibo.App.Theme;

/// <summary>
/// Every hardcoded size from <c>ConverterView.swift</c>, <c>SettingsView.swift</c> and
/// <c>AboutView.swift</c>, at text-size Small (factor 1.0). <see cref="ThemeManager.SetFontScale"/>
/// multiplies them and writes them into the application resources, so every
/// <c>{DynamicResource}</c> consumer resizes live — field heights included, as
/// <c>scaled()</c> does on macOS.
/// </summary>
internal static class Metrics
{
    public static readonly IReadOnlyDictionary<string, double> Base = new Dictionary<string, double>
    {
        ["Font.Title"] = 15,          // "Kibo" in the converter header
        ["Font.Body"] = 12,           // toggles, close button
        ["Font.Button"] = 11,         // Paste / Clear, segments
        ["Font.Label"] = 10,          // INPUT / RESULT, section headers
        ["Font.Badge"] = 9,           // the direction badge and the privacy capsule
        ["Font.Thai"] = 13,           // the input and result fields
        ["Font.Note"] = 10,           // settings notes
        ["Font.PreviewSmall"] = 11,   // the settings preview's "before" line
        ["Font.SettingsTitle"] = 17,
        ["Font.AboutTitle"] = 22,
        ["Font.AboutSubtitle"] = 11,
        ["Font.AboutVersion"] = 10,
        ["Metric.FieldHeight"] = 64,  // input and result fields
    };

    public static void Write(ResourceDictionary resources, double scale)
    {
        foreach (var (key, size) in Base)
        {
            resources[key] = size * scale;
        }
    }
}
