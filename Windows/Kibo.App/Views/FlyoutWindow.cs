using System.Windows.Input;
using System.Windows.Interop;
using Kibo.App.Services;
using Kibo.App.Theme;
using static Kibo.App.Services.NativeMethods;

namespace Kibo.App.Views;

/// <summary>
/// The transient converter popup, anchored above the tray icon or the bubble. The rough port of
/// <c>NSPopover</c> from <c>AppChrome.swift</c>.
/// </summary>
/// <remarks>
/// <c>AllowsTransparency</c> is deliberately off: a layered window loses ClearType, and the Thai
/// vowel marks at 13pt are the whole product. Rounded corners come from DWM instead. It hides on
/// deactivate, and remembers when, so a click on the tray icon while it is open closes it rather
/// than reopening.
/// </remarks>
internal sealed class FlyoutWindow : Window
{
    private const int Gap = 8;

    private readonly ConverterView view;

    public long LastHiddenAt { get; private set; }

    public FlyoutWindow(ConverterModel model)
    {
        WindowStyle = WindowStyle.None;
        ResizeMode = ResizeMode.NoResize;
        Topmost = true;
        ShowInTaskbar = false;
        AllowsTransparency = false;
        SizeToContent = SizeToContent.WidthAndHeight;
        UseLayoutRounding = true;
        SetResourceReference(BackgroundProperty, "Brush.Panel");

        view = new ConverterView(model, fixedWidth: 360);
        Content = view;

        SourceInitialized += (_, _) =>
        {
            var hwnd = new WindowInteropHelper(this).Handle;
            UseRoundedCorners(hwnd);
        };
        Deactivated += (_, _) => Hide();
    }

    public new void Hide()
    {
        if (!IsVisible) return;
        LastHiddenAt = Environment.TickCount64;
        base.Hide();
    }

    public void Toggle(FlyoutAnchor anchor)
    {
        if (IsVisible) { Hide(); return; }
        // A click on the tray icon that is closing an open flyout arrives just after Deactivated
        // hid it; swallow the immediate reopen.
        if (Environment.TickCount64 - LastHiddenAt < 250) return;
        ShowAt(anchor);
    }

    public void ShowAt(FlyoutAnchor anchor)
    {
        var handle = new WindowInteropHelper(this).EnsureHandle();
        Measure(new Size(double.PositiveInfinity, double.PositiveInfinity));

        var point = AnchorPoint(anchor);
        var monitor = MonitorFromPoint(point, MONITOR_DEFAULTTONEAREST);
        GetDpiForMonitor(monitor, MDT_EFFECTIVE_DPI, out var dpi, out _);
        var scale = dpi / 96.0;

        var size = new SizePx((int)Math.Ceiling(DesiredSize.Width * scale), (int)Math.Ceiling(DesiredSize.Height * scale));
        var screen = Forms.Screen.FromPoint(new System.Drawing.Point(point.X, point.Y)).WorkingArea;
        var work = new RectPx(screen.X, screen.Y, screen.Width, screen.Height);
        var rect = Placement.AnchorAbove(new PointPx(point.X, point.Y), size, work, Gap);

        SetWindowPos(handle, HWND_TOPMOST, rect.X, rect.Y, rect.W, rect.H, SWP_SHOWWINDOW);
        Show();
        Activate();
        view.FocusInput();
    }

    private POINT AnchorPoint(FlyoutAnchor anchor)
    {
        switch (anchor)
        {
            case FlyoutAnchor.Bubble when Panels.Bubble is { } bubble:
                return bubble.TopCentreDevicePoint();
            case FlyoutAnchor.TrayCorner:
                var wa = Forms.Screen.PrimaryScreen!.WorkingArea;
                return new POINT { X = wa.Right - 8, Y = wa.Bottom - 8 };
            default:
                GetCursorPos(out var cursor);
                return cursor;
        }
    }
}
