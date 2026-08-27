using System.Windows.Input;
using System.Windows.Interop;
using Kibo.App.Controls;
using Kibo.App.Theme;
using static Kibo.App.Services.NativeMethods;

namespace Kibo.App.Views;

/// <summary>
/// The always-on-top mascot on the desktop — the presence the user asked for, so Kibo is reachable
/// even when the tray icon is hidden in the overflow. Left-click opens the flyout beside it;
/// drag moves it; right-click shows the tray menu. It never takes focus, so the app whose text is
/// being fixed keeps it.
/// </summary>
internal sealed class BubbleWindow : Window
{
    private readonly KiboSpriteControl mascot;
    private System.Windows.Point pressOrigin;
    private bool dragging;

    public BubbleWindow()
    {
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        Topmost = true;
        ShowInTaskbar = false;
        ResizeMode = ResizeMode.NoResize;
        ShowActivated = false;
        SizeToContent = SizeToContent.WidthAndHeight;
        UseLayoutRounding = true;

        mascot = new KiboSpriteControl { PixelSize = 3, Margin = new Thickness(4) };
        Content = mascot;

        SourceInitialized += OnSourceInitialized;
        MouseLeftButtonDown += OnMouseDown;
        MouseLeftButtonUp += OnMouseUp;
        MouseRightButtonUp += (_, _) => { if (TrayMenu() is { } menu) menu.Show(Forms.Cursor.Position); };
        LocationChanged += (_, _) => Persist();
    }

    private void OnSourceInitialized(object? sender, EventArgs e)
    {
        var hwnd = new WindowInteropHelper(this).Handle;
        // Never activate: dragging still works, but the app being fixed keeps keyboard focus.
        var ex = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
        SetWindowLongPtr(hwnd, GWL_EXSTYLE, (nint)((long)ex | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW));
        RestorePosition();
    }

    private void OnMouseDown(object sender, MouseButtonEventArgs e)
    {
        pressOrigin = e.GetPosition(this);
        dragging = false;
        CaptureMouse();
        MouseMove += OnMouseMove;
    }

    private void OnMouseMove(object sender, MouseEventArgs e)
    {
        if (e.LeftButton != MouseButtonState.Pressed) return;
        var now = e.GetPosition(this);
        if (!dragging && (Math.Abs(now.X - pressOrigin.X) > 4 || Math.Abs(now.Y - pressOrigin.Y) > 4))
        {
            dragging = true;
            try { DragMove(); } catch { /* DragMove throws if the button was already released */ }
        }
    }

    private void OnMouseUp(object sender, MouseButtonEventArgs e)
    {
        MouseMove -= OnMouseMove;
        ReleaseMouseCapture();
        if (!dragging)
        {
            Panels.ToggleFlyout(FlyoutAnchor.Bubble);
        }
        dragging = false;
    }

    private static Forms.ContextMenuStrip? TrayMenu() =>
        ((KiboApplication)System.Windows.Application.Current).Tray?.Menu;

    /// <summary>The top-centre of the bubble in device pixels, for anchoring the flyout to it.</summary>
    public POINT TopCentreDevicePoint()
    {
        var source = PresentationSource.FromVisual(this);
        var transform = source?.CompositionTarget?.TransformToDevice ?? Matrix.Identity;
        var topCentre = PointToScreen(new System.Windows.Point(ActualWidth / 2, 0));
        return new POINT { X = (int)Math.Round(topCentre.X), Y = (int)Math.Round(topCentre.Y) };
    }

    /// <summary>A wordless confirmation after a clipboard fix, matching the flyout's boo~.</summary>
    public void CelebrateFix()
    {
        mascot.Mood = KiboSpriteControl.MoodKind.Pleased;
        var timer = new System.Windows.Threading.DispatcherTimer { Interval = TimeSpan.FromSeconds(1.6) };
        timer.Tick += (_, _) => { timer.Stop(); mascot.Mood = KiboSpriteControl.MoodKind.Idle; };
        timer.Start();
    }

    public void ApplyVisibility(bool show)
    {
        if (show) { RestorePosition(); Show(); }
        else Hide();
    }

    private void RestorePosition()
    {
        var size = new SizePx((int)Math.Max(ActualWidth, 56), (int)Math.Max(ActualHeight, 56));
        var screens = Forms.Screen.AllScreens.Select(s => new RectPx(s.WorkingArea.X, s.WorkingArea.Y, s.WorkingArea.Width, s.WorkingArea.Height)).ToList();

        if (AppSettings.Shared.BubblePosition is { } saved
            && Placement.ClampToScreens(new PointPx((int)saved.X, (int)saved.Y), size, screens) is { } point)
        {
            MoveToDevice(point.X, point.Y);
            return;
        }
        var wa = Forms.Screen.PrimaryScreen!.WorkingArea;
        MoveToDevice(wa.Right - 24 - size.W, wa.Bottom - 24 - size.H);
    }

    private void MoveToDevice(int x, int y)
    {
        var source = PresentationSource.FromVisual(this);
        var m = source?.CompositionTarget?.TransformFromDevice ?? Matrix.Identity;
        var p = m.Transform(new System.Windows.Point(x, y));
        Left = p.X;
        Top = p.Y;
    }

    private void Persist()
    {
        if (!IsLoaded) return;
        var topLeft = PointToScreen(new System.Windows.Point(0, 0));
        AppSettings.Shared.BubblePosition = (topLeft.X, topLeft.Y);
    }
}
