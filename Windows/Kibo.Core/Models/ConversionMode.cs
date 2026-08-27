namespace Kibo.Core;

/// <summary>
/// How to interpret the text the user handed us. The port of <c>ConversionMode.swift</c>.
/// </summary>
/// <remarks>
/// Three of the four are mechanical: every mapped character is flipped, no questions asked.
/// <see cref="Mixed"/> is the one that judges — see <see cref="KeyboardConverter"/> — so the other
/// three double as the escape hatch for when that judgement is wrong.
/// <para>
/// <b>Declaration order is the order of the picker</b>, via <see cref="ConversionModes.All"/>, and
/// it also sets the Ctrl+1–4 shortcuts. It runs most-used first.
/// </para>
/// </remarks>
public enum ConversionMode
{
    /// <summary>
    /// Flip <b>every</b> run, each in the direction implied by the script it is already in — Thai
    /// runs back to English, Latin runs to Thai — without consulting the gate. Exists because text
    /// can be mistyped in <i>both</i> directions at once, which no single explicit direction fixes
    /// and which Mixed provably cannot tell apart by spelling shape.
    /// </summary>
    SwapAll,

    /// <summary>Treat the whole string as English keystrokes typed with the Thai layout active.</summary>
    EnglishToThai,

    /// <summary>Treat the whole string as Thai keystrokes typed with the US layout active.</summary>
    ThaiToEnglish,

    /// <summary>Convert each run only if it is malformed in its own script; leave correct text alone.</summary>
    Mixed,
}

/// <summary>
/// What Swift hangs off the enum itself — <c>allCases</c>, <c>rawValue</c>, <c>default</c>,
/// <c>swapped</c> — lives here, because a C# enum cannot carry members.
/// </summary>
public static class ConversionModes
{
    /// <summary>Picker order. Most-used first.</summary>
    public static IReadOnlyList<ConversionMode> All { get; } =
        [ConversionMode.SwapAll, ConversionMode.EnglishToThai, ConversionMode.ThaiToEnglish, ConversionMode.Mixed];

    /// <summary>
    /// What the converter opens in when nothing is remembered — a fresh install, or a stored value
    /// that no longer parses. Deliberately <b>not</b> <c>All[0]</c>: picker order is presentation
    /// and may be reshuffled, while this is behaviour. <c>SwapAll</c> rather than the safer
    /// <c>Mixed</c> by explicit product decision — the result field is a preview the user reads
    /// before copying, and a mode that always does <i>something</i> beats one that silently does
    /// nothing.
    /// </summary>
    public const ConversionMode Default = ConversionMode.SwapAll;

    /// <summary>
    /// The opposite explicit direction. <c>Mixed</c> and <c>SwapAll</c> are direction-symmetric and
    /// return themselves, so a Swap control can call this unconditionally.
    /// </summary>
    public static ConversionMode Swapped(this ConversionMode mode) => mode switch
    {
        ConversionMode.EnglishToThai => ConversionMode.ThaiToEnglish,
        ConversionMode.ThaiToEnglish => ConversionMode.EnglishToThai,
        _ => mode,
    };

    /// <summary>Whether the mode has an opposite for a Swap control to flip to.</summary>
    public static bool HasDirection(this ConversionMode mode) => mode.Swapped() != mode;

    /// <summary>
    /// The identifier used by <c>Fixtures/conversion-cases.json</c> and by the settings file. Fixed
    /// by that contract, not by the C# member names.
    /// </summary>
    public static string RawValue(this ConversionMode mode) => mode switch
    {
        ConversionMode.SwapAll => "swapAll",
        ConversionMode.EnglishToThai => "englishToThai",
        ConversionMode.ThaiToEnglish => "thaiToEnglish",
        ConversionMode.Mixed => "mixed",
        _ => throw new ArgumentOutOfRangeException(nameof(mode), mode, null),
    };

    /// <summary>
    /// Exact, ordinal parsing of a raw value. Hand-written rather than <see cref="Enum.TryParse{TEnum}(string?, out TEnum)"/>,
    /// which accepts integers ("3") and, with the wrong flag, any casing — a corrupted or
    /// newer-build setting must fall back to <see cref="Default"/>, not land on a mode by accident.
    /// </summary>
    public static bool TryParse(string? raw, out ConversionMode mode)
    {
        foreach (var candidate in All)
        {
            if (string.Equals(candidate.RawValue(), raw, StringComparison.Ordinal))
            {
                mode = candidate;
                return true;
            }
        }
        mode = Default;
        return false;
    }
}
