using System.Runtime.InteropServices;

namespace Kibo.App.Services;

/// <summary>
/// Every Win32 call the shell makes, in one place, so the surface the app touches can be read in
/// a minute. Nothing here reaches the network; <c>NoNetworkTests</c> scans the built assembly to
/// prove it.
/// </summary>
internal static partial class NativeMethods
{
    // ── Clipboard ────────────────────────────────────────────────────────────────────────────

    public const uint CF_UNICODETEXT = 13;
    public const uint GMEM_MOVEABLE = 0x0002;

    [LibraryImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool OpenClipboard(nint hWndNewOwner);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool CloseClipboard();

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool EmptyClipboard();

    [LibraryImport("user32.dll", SetLastError = true)]
    public static partial nint SetClipboardData(uint uFormat, nint hMem);

    [LibraryImport("user32.dll")]
    public static partial nint GetClipboardData(uint uFormat);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool IsClipboardFormatAvailable(uint format);

    [LibraryImport("user32.dll", StringMarshalling = StringMarshalling.Utf16)]
    public static partial uint RegisterClipboardFormatW(string lpszFormat);

    [LibraryImport("kernel32.dll")]
    public static partial nint GlobalAlloc(uint uFlags, nuint dwBytes);

    [LibraryImport("kernel32.dll")]
    public static partial nint GlobalFree(nint hMem);

    [LibraryImport("kernel32.dll")]
    public static partial nint GlobalLock(nint hMem);

    [LibraryImport("kernel32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool GlobalUnlock(nint hMem);

    // ── Desktop Window Manager ───────────────────────────────────────────────────────────────

    private const int DWMWA_USE_IMMERSIVE_DARK_MODE = 20;
    private const int DWMWA_WINDOW_CORNER_PREFERENCE = 33;
    private const int DWMWA_BORDER_COLOR = 34;
    public const int DWMWCP_ROUND = 2;

    [LibraryImport("dwmapi.dll")]
    private static partial int DwmSetWindowAttribute(nint hwnd, int attribute, ref int value, int size);

    /// <summary>Makes a titled window's title bar follow the palette. Silently a no-op before Windows 10 1809.</summary>
    public static void UseImmersiveDarkMode(nint hwnd, bool dark)
    {
        var value = dark ? 1 : 0;
        _ = DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, ref value, sizeof(int));
    }

    /// <summary>Rounded corners on a borderless window, Windows 11 only; square on 10, which is fine.</summary>
    public static void UseRoundedCorners(nint hwnd)
    {
        var preference = DWMWCP_ROUND;
        _ = DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, ref preference, sizeof(int));
    }

    /// <summary>A one-pixel border in a COLORREF (0x00BBGGRR), Windows 11 only.</summary>
    public static void SetBorderColor(nint hwnd, byte r, byte g, byte b)
    {
        var colorref = r | (g << 8) | (b << 16);
        _ = DwmSetWindowAttribute(hwnd, DWMWA_BORDER_COLOR, ref colorref, sizeof(int));
    }

    // ── Monitors, DPI, placement ─────────────────────────────────────────────────────────────

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT
    {
        public int X;
        public int Y;
    }

    public const uint MONITOR_DEFAULTTONEAREST = 2;
    public const int MDT_EFFECTIVE_DPI = 0;
    public const int SM_CXSMICON = 49;
    public static readonly nint HWND_TOPMOST = -1;
    public const uint SWP_NOACTIVATE = 0x0010;
    public const uint SWP_SHOWWINDOW = 0x0040;

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool GetCursorPos(out POINT point);

    [LibraryImport("user32.dll")]
    public static partial nint MonitorFromPoint(POINT point, uint flags);

    [LibraryImport("shcore.dll")]
    public static partial int GetDpiForMonitor(nint monitor, int dpiType, out uint dpiX, out uint dpiY);

    [LibraryImport("user32.dll")]
    public static partial int GetSystemMetricsForDpi(int index, uint dpi);

    [LibraryImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool SetWindowPos(nint hWnd, nint hWndInsertAfter, int x, int y, int cx, int cy, uint flags);

    // ── Window styles ────────────────────────────────────────────────────────────────────────

    public const int GWL_EXSTYLE = -20;
    public const long WS_EX_TOOLWINDOW = 0x00000080;
    public const long WS_EX_NOACTIVATE = 0x08000000;

    [LibraryImport("user32.dll", EntryPoint = "GetWindowLongPtrW", SetLastError = true)]
    public static partial nint GetWindowLongPtr(nint hWnd, int index);

    [LibraryImport("user32.dll", EntryPoint = "SetWindowLongPtrW", SetLastError = true)]
    public static partial nint SetWindowLongPtr(nint hWnd, int index, nint newLong);

    // ── Hotkeys ──────────────────────────────────────────────────────────────────────────────

    public const uint MOD_ALT = 0x0001;
    public const uint MOD_CONTROL = 0x0002;
    public const uint MOD_NOREPEAT = 0x4000;
    public const uint VK_K = 0x4B;
    public const int WM_HOTKEY = 0x0312;
    public const int WM_SETTINGCHANGE = 0x001A;
    public const int ERROR_HOTKEY_ALREADY_REGISTERED = 1409;

    [LibraryImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool RegisterHotKey(nint hWnd, int id, uint fsModifiers, uint vk);

    [LibraryImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool UnregisterHotKey(nint hWnd, int id);

    // ── Icons ────────────────────────────────────────────────────────────────────────────────

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool DestroyIcon(nint hIcon);
}
