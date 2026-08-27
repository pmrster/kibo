using System.Windows.Media;

namespace Kibo.App.Theme;

/// <summary>The port of <c>AppFont</c> in <c>Theme.swift</c>.</summary>
internal static class AppFonts
{
    /// <summary>English chrome and the title: the system face, as on macOS.</summary>
    public static readonly FontFamily Ui = new("Segoe UI");

    /// <summary>
    /// The input and result fields, which can contain Thai. Noto Sans Thai when the machine has
    /// it — the system Thai face crowds vowel and tone marks at 11–13pt, and those marks are the
    /// whole point here — else Leelawadee UI, which Windows ships. WPF walks the list per glyph,
    /// so nothing is bundled and nothing falls back silently to a face that lacks Thai.
    /// </summary>
    public static readonly FontFamily Thai = new("Noto Sans Thai, Leelawadee UI, Segoe UI");

    /// <summary>The version line in About, and the mascot's "boo~".</summary>
    public static readonly FontFamily Mono = new("Consolas");
}
