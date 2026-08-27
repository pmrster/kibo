namespace Kibo.Core;

/// <summary>
/// Text-size preset. <see cref="FontSizes.Factor"/> multiplies every hardcoded point size;
/// <see cref="Small"/> is 1.0 so the app is pixel-identical to its designed size and the presets
/// only grow from there.
/// </summary>
public enum FontSize
{
    Small,
    Medium,
    Large,
}

public static class FontSizes
{
    public static IReadOnlyList<FontSize> All { get; } = [FontSize.Small, FontSize.Medium, FontSize.Large];

    public static double Factor(this FontSize size) => size switch
    {
        FontSize.Small => 1.0,
        FontSize.Medium => 1.15,
        FontSize.Large => 1.3,
        _ => throw new ArgumentOutOfRangeException(nameof(size), size, null),
    };

    public static string RawValue(this FontSize size) => size switch
    {
        FontSize.Small => "small",
        FontSize.Medium => "medium",
        FontSize.Large => "large",
        _ => throw new ArgumentOutOfRangeException(nameof(size), size, null),
    };

    /// <summary>Exact, ordinal parsing; see <see cref="ConversionModes.TryParse"/> for why.</summary>
    public static bool TryParse(string? raw, out FontSize size)
    {
        foreach (var candidate in All)
        {
            if (string.Equals(candidate.RawValue(), raw, StringComparison.Ordinal))
            {
                size = candidate;
                return true;
            }
        }
        size = FontSize.Small;
        return false;
    }
}
