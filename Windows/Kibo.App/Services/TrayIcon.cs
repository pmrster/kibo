using Microsoft.Win32;
using Kibo.App.Theme;
using Kibo.App.Views;
using System.Drawing;

namespace Kibo.App.Services;

/// <summary>
/// The notification-area icon and its menu — Windows' equivalent of the macOS status item. Uses
/// <see cref="Forms.NotifyIcon"/>, which is in-box under UseWindowsForms and already re-adds the
/// icon after Explorer restarts and performs the foreground dance a tray menu needs to dismiss.
/// </summary>
/// <remarks>
/// It has no way to report its own rectangle, so the flyout anchors on the cursor at mouse-up —
/// which is on the icon by definition. Left-click opens the flyout; right-click opens the menu,
/// which the desktop bubble shares.
/// </remarks>
internal sealed class TrayIcon : IDisposable
{
    private readonly Forms.NotifyIcon icon;
    private Icon? current;

    public Forms.ContextMenuStrip Menu { get; }

    public TrayIcon()
    {
        Menu = BuildMenu();
        icon = new Forms.NotifyIcon
        {
            Text = "Kibo",
            Visible = true,
            ContextMenuStrip = Menu,
        };
        icon.MouseUp += OnMouseUp;

        RefreshIcon();
        SystemEvents.UserPreferenceChanged += (_, _) => RefreshIcon();
        SystemEvents.DisplaySettingsChanged += (_, _) => RefreshIcon();
    }

    public void ShowBalloon(string message) =>
        icon.ShowBalloonTip(1500, "Kibo", message, Forms.ToolTipIcon.Info);

    private void OnMouseUp(object? sender, Forms.MouseEventArgs e)
    {
        if (e.Button == Forms.MouseButtons.Left)
        {
            Panels.ToggleFlyout(FlyoutAnchor.Cursor);
        }
    }

    private Forms.ContextMenuStrip BuildMenu()
    {
        var menu = new Forms.ContextMenuStrip();
        AddItem(menu, "Open Kibo", () => Panels.ShowFlyout(FlyoutAnchor.TrayCorner), "Ctrl+Alt+K");
        AddItem(menu, "Fix clipboard", FixClipboard);
        showBubbleItem = AddItem(menu, "Show floating Kibo", ToggleBubble);
        showBubbleItem.CheckOnClick = false;
        menu.Items.Add(new Forms.ToolStripSeparator());
        AddItem(menu, "About Kibo", () => Panels.About?.ShowCentered());
        AddItem(menu, "Settings…", () => Panels.Settings?.ShowCentered());
        menu.Items.Add(new Forms.ToolStripSeparator());
        AddItem(menu, "Quit Kibo", () => System.Windows.Application.Current.Shutdown());
        menu.Opening += (_, _) => showBubbleItem!.Checked = AppSettings.Shared.ShowBubble;
        return menu;
    }

    private Forms.ToolStripMenuItem? showBubbleItem;

    private static Forms.ToolStripMenuItem AddItem(Forms.ContextMenuStrip menu, string text, Action action, string? shortcut = null)
    {
        var item = new Forms.ToolStripMenuItem(text) { ShortcutKeyDisplayString = shortcut };
        item.Click += (_, _) => action();
        menu.Items.Add(item);
        return item;
    }

    private static void FixClipboard()
    {
        var app = (KiboApplication)System.Windows.Application.Current;
        var outcome = app.Model.FixClipboard();
        var message = outcome switch
        {
            FixClipboardOutcome.Fixed => "Clipboard fixed",
            FixClipboardOutcome.Unchanged => $"Nothing to fix in {Views.ModeLabels.Label(app.Model.Mode)}",
            _ => "The clipboard has no text",
        };
        if (outcome == FixClipboardOutcome.Fixed) Panels.Bubble?.CelebrateFix();
        app.Tray?.ShowBalloon(message);
    }

    private static void ToggleBubble() => AppSettings.Shared.ShowBubble = !AppSettings.Shared.ShowBubble;

    private void RefreshIcon()
    {
        var replacement = TrayIconRenderer.Render(SystemTheme.SystemUsesLightTheme, 96);
        icon.Icon = replacement;
        current?.Dispose();
        current = replacement;
    }

    public void Dispose()
    {
        icon.Visible = false;
        icon.Dispose();
        current?.Dispose();
    }
}
