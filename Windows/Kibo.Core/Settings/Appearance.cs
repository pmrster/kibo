namespace Kibo.Core;

/// <summary>Forced appearance. <see cref="System"/> follows the OS.</summary>
public enum Appearance
{
    System,
    Light,
    Dark,
}

public static class Appearances
{
    public static IReadOnlyList<Appearance> All { get; } = [Appearance.System, Appearance.Light, Appearance.Dark];

    public static string RawValue(this Appearance appearance) => appearance switch
    {
        Appearance.System => "system",
        Appearance.Light => "light",
        Appearance.Dark => "dark",
        _ => throw new ArgumentOutOfRangeException(nameof(appearance), appearance, null),
    };

    /// <summary>Exact, ordinal parsing; see <see cref="ConversionModes.TryParse"/> for why.</summary>
    public static bool TryParse(string? raw, out Appearance appearance)
    {
        foreach (var candidate in All)
        {
            if (string.Equals(candidate.RawValue(), raw, StringComparison.Ordinal))
            {
                appearance = candidate;
                return true;
            }
        }
        appearance = Appearance.System;
        return false;
    }
}
