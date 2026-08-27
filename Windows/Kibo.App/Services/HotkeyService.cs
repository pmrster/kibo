using System.Runtime.InteropServices;
using System.Windows.Interop;
using Kibo.App.Theme;
using Kibo.App.Views;
using static Kibo.App.Services.NativeMethods;

namespace Kibo.App.Services;

/// <summary>
/// The global Ctrl+Alt+K that opens the converter from any app, and the hook that notices a
/// system theme change. Both hang off one message-only window.
/// </summary>
internal sealed class HotkeyService : IDisposable
{
    private const int HotkeyId = 1;

    private readonly HwndSource source;
    private bool registered;

    public HotkeyService()
    {
        // HWND_MESSAGE (-3): a message-only window, never shown, that still pumps messages.
        source = new HwndSource(new HwndSourceParameters("KiboMessages")
        {
            ParentWindow = new nint(-3),
            WindowStyle = 0,
        });
        source.AddHook(WndProc);
    }

    /// <summary>Registers the hotkey; on failure sets the note the Settings toggle shows.</summary>
    public void Apply(bool enabled)
    {
        Unregister();
        if (!enabled)
        {
            AppSettings.Shared.HotkeyNote = null;
            return;
        }
        if (RegisterHotKey(source.Handle, HotkeyId, MOD_CONTROL | MOD_ALT | MOD_NOREPEAT, VK_K))
        {
            registered = true;
            AppSettings.Shared.HotkeyNote = null;
        }
        else
        {
            AppSettings.Shared.HotkeyNote = Marshal.GetLastPInvokeError() == ERROR_HOTKEY_ALREADY_REGISTERED
                ? "Ctrl+Alt+K is taken by another app."
                : "Ctrl+Alt+K could not be registered.";
        }
    }

    private void Unregister()
    {
        if (!registered) return;
        UnregisterHotKey(source.Handle, HotkeyId);
        registered = false;
    }

    private nint WndProc(nint hwnd, int msg, nint wParam, nint lParam, ref bool handled)
    {
        if (msg == WM_HOTKEY && wParam == HotkeyId)
        {
            Panels.ShowFlyout(FlyoutAnchor.TrayCorner);
            handled = true;
        }
        else if (msg == WM_SETTINGCHANGE)
        {
            // Any personalisation change; re-resolving System appearance is cheap and idempotent.
            AppSettings.Shared.RefreshSystemAppearance();
        }
        return 0;
    }

    public void Dispose()
    {
        Unregister();
        source.Dispose();
    }
}
