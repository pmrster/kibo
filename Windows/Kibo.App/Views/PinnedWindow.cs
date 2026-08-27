using System.ComponentModel;
using System.Windows.Interop;
using Kibo.App.Theme;

namespace Kibo.App.Views;

/// <summary>
/// The flyout pinned into a normal, resizable window that stays on top — the port of the pinned
/// <c>FloatingPanel</c>. It hosts a second <see cref="ConverterView"/> over the same model, so the
/// text and mode are shared live with the flyout.
/// </summary>
internal sealed class PinnedWindow : Window
{
    public PinnedWindow(ConverterModel model)
    {
        Title = "Kibo";
        Width = 380;
        Height = 520;
        MinWidth = 340;
        MinHeight = 420;
        Topmost = true;
        ShowInTaskbar = false;
        WindowStyle = WindowStyle.SingleBorderWindow;
        ResizeMode = ResizeMode.CanResize;
        UseLayoutRounding = true;
        SetResourceReference(BackgroundProperty, "Brush.Panel");
        Content = new ConverterView(model, fixedWidth: null);

        SourceInitialized += (_, _) => ThemeManager.ApplyTitleBar(this);
        ThemeManager.Changed += () => ThemeManager.ApplyTitleBar(this);
        Closing += OnClosing;
    }

    private bool reallyClose;

    public void Toggle()
    {
        if (IsVisible) { Hide(); return; }
        if (!WasShown) { WindowStartupLocation = WindowStartupLocation.CenterScreen; WasShown = true; }
        Panels.Flyout?.Hide();
        Show();
        Activate();
    }

    private bool WasShown { get; set; }

    private void OnClosing(object? sender, CancelEventArgs e)
    {
        // Quit closes it for real; the close box just hides it, so no text is ever rebuilt.
        if (reallyClose) return;
        e.Cancel = true;
        Hide();
    }

    public void CloseForReal()
    {
        reallyClose = true;
        Close();
    }
}
