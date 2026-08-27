using System.Windows.Input;
using Kibo.App.Theme;

namespace Kibo.App.Views;

/// <summary>Where the flyout goes: on the tray icon, on the bubble, or at the tray corner.</summary>
internal enum FlyoutAnchor
{
    Cursor,
    Bubble,
    TrayCorner,
}

/// <summary>
/// The one place that owns the converter's windows — the port of <c>Panels</c> in
/// <c>FloatingPanel.swift</c>. Every surface shares the one <see cref="ConverterModel"/>, so text
/// and mode are live between the flyout and the pinned window.
/// </summary>
internal static class Panels
{
    public static FlyoutWindow? Flyout { get; set; }
    public static PinnedWindow? Pinned { get; set; }
    public static BubbleWindow? Bubble { get; set; }
    public static SettingsWindow? Settings { get; set; }
    public static AboutWindow? About { get; set; }

    public static void ToggleFlyout(FlyoutAnchor anchor) => Flyout?.Toggle(anchor);

    public static void ShowFlyout(FlyoutAnchor anchor) => Flyout?.ShowAt(anchor);

    public static void TogglePinned() => Pinned?.Toggle();
}
