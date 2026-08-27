using System.Windows.Interop;
using Kibo.App.Services;

namespace Kibo.App.Theme;

/// <summary>
/// Applies the palette and the text-size factor. The port of what <c>AppSettings.swift</c> does
/// with <c>NSApp.appearance</c> — except that WPF has no application-wide appearance, so the
/// palette is a resource dictionary swapped in place, and every colour in the app is looked up
/// through <c>{DynamicResource}</c> so the swap is live.
/// </summary>
internal static class ThemeManager
{
    private static ResourceDictionary? palette;

    public static bool IsDark { get; private set; }

    /// <summary>Raised after the palette changes, for the pieces WPF cannot re-theme by itself.</summary>
    public static event Action? Changed;

    public static void Apply(Appearance appearance)
    {
        IsDark = appearance switch
        {
            Appearance.Light => false,
            Appearance.Dark => true,
            _ => !SystemTheme.AppsUseLightTheme,
        };

        var replacement = new ResourceDictionary
        {
            Source = new Uri(IsDark ? "Theme/Palette.Dark.xaml" : "Theme/Palette.Light.xaml", UriKind.Relative),
        };
        var merged = Application.Current.Resources.MergedDictionaries;
        if (palette is not null) merged.Remove(palette);
        else merged.RemoveAt(0);   // the light palette App.xaml starts with
        merged.Insert(0, replacement);
        palette = replacement;

        Changed?.Invoke();
    }

    public static void SetFontScale(double scale) => Metrics.Write(Application.Current.Resources, scale);

    /// <summary>
    /// Titled windows keep their system title bar; this is what makes it follow the palette.
    /// Call once the window has a handle, and again whenever the palette changes.
    /// </summary>
    public static void ApplyTitleBar(Window window)
    {
        var handle = new WindowInteropHelper(window).Handle;
        if (handle != 0) NativeMethods.UseImmersiveDarkMode(handle, IsDark);
    }
}
