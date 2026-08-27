namespace Kibo.App.Controls;

/// <summary>
/// The mascot's 16×16 pixel grid, transcribed verbatim from <c>Sources/Kibo/KiboSprite.swift</c>:
/// a solid ghost silhouette with the eyes cut out as holes. One colour, features as holes — the
/// same construction as everywhere else Kibo is drawn.
/// </summary>
/// <remarks>
/// <c>Y</c> is body, <c>.</c> is empty. <c>Open</c> eyes are one-pixel slits at x=4 and x=11;
/// <c>Shut</c> is a pair of three-pixel dashes on the middle eye row, for the blink and the
/// contented look after a copy.
/// </remarks>
internal static class KiboSprite
{
    public const int Columns = 16;
    public const int Rows = 16;

    public enum Eyes
    {
        Open,
        Shut,
    }

    private static readonly string[] Dome =
    [
        ".....YYYYYY.....",
        "...YYYYYYYYYY...",
        "..YYYYYYYYYYYY..",
        ".YYYYYYYYYYYYYY.",
        ".YYYYYYYYYYYYYY.",
        "YYYYYYYYYYYYYYYY",
        "YYYYYYYYYYYYYYYY",
    ];

    private static readonly string[] Hem =
    [
        "YYYYYYYYYYYYYYYY",
        "YYYYYYYYYYYYYYYY",
        "YYYYYYYYYYYYYYYY",
        "YYYYYYYYYYYYYYYY",
        "YYYYY.YYYY.YYYYY",
        ".YYYY.YYYY.YYYY.",
    ];

    private static readonly string[] OpenEyes =
    [
        "YYYY.YYYYYY.YYYY",
        "YYYY.YYYYYY.YYYY",
        "YYYY.YYYYYY.YYYY",
    ];

    private static readonly string[] ShutEyes =
    [
        "YYYYYYYYYYYYYYYY",
        "YYY...YYYY...YYY",
        "YYYYYYYYYYYYYYYY",
    ];

    /// <summary>The 16 rows for the given eyes, each a 16-character string of <c>Y</c> and <c>.</c>.</summary>
    public static IReadOnlyList<string> RowsFor(Eyes eyes) =>
        [.. Dome, .. (eyes == Eyes.Open ? OpenEyes : ShutEyes), .. Hem];
}
