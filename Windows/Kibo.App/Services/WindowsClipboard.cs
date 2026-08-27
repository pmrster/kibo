using System.Runtime.InteropServices;
using static Kibo.App.Services.NativeMethods;

namespace Kibo.App.Services;

/// <summary>
/// The real clipboard, via Win32. The port of <c>SystemClipboard.swift</c>.
/// </summary>
/// <remarks>
/// <para>
/// This type exists only inside the shell, and it is the only code in the app that touches the
/// clipboard at all — no polling, no listener, no history. <see cref="ConverterModel"/> calls
/// <see cref="Read"/> from Paste and Fix clipboard, <see cref="Write"/> from Copy and Fix
/// clipboard, and nothing else calls either.
/// </para>
/// <para>
/// Every write carries three extra formats, the Windows analogue of the <c>ConcealedType</c> and
/// <c>TransientType</c> markers the macOS app sets: <c>ExcludeClipboardContentFromMonitorProcessing</c>
/// tells clipboard managers not to record it, <c>CanIncludeInClipboardHistory</c> = 0 keeps it out
/// of Win+V, and <c>CanUploadToCloudClipboard</c> = 0 keeps it off the user's other devices. Not
/// defensive over-caution: the app's whole use case is text typed with the wrong layout, which
/// routinely means a password.
/// </para>
/// <para>
/// Raw Win32 rather than <c>System.Windows.Clipboard</c> because two of those formats must be an
/// exact four-byte DWORD, and .NET's <c>DataObject</c> no longer serialises arbitrary payloads.
/// </para>
/// </remarks>
internal sealed class WindowsClipboard : IClipboard
{
    private static readonly uint ExcludeFromMonitors = RegisterClipboardFormatW("ExcludeClipboardContentFromMonitorProcessing");
    private static readonly uint CanIncludeInHistory = RegisterClipboardFormatW("CanIncludeInClipboardHistory");
    private static readonly uint CanUploadToCloud = RegisterClipboardFormatW("CanUploadToCloudClipboard");

    public string? Read()
    {
        if (!Open()) return null;
        try
        {
            if (!IsClipboardFormatAvailable(CF_UNICODETEXT)) return null;
            var handle = GetClipboardData(CF_UNICODETEXT);
            if (handle == 0) return null;
            var pointer = GlobalLock(handle);
            if (pointer == 0) return null;
            try
            {
                return Marshal.PtrToStringUni(pointer);
            }
            finally
            {
                GlobalUnlock(handle);
            }
        }
        finally
        {
            CloseClipboard();
        }
    }

    public void Write(string text)
    {
        if (!Open()) return;
        try
        {
            // Emptying first: without it the new value would sit beside whatever formats are
            // already there, and the paste target might pick the stale one.
            EmptyClipboard();
            SetText(text);
            // Presence is the signal for the first; the value is for the other two.
            SetDword(ExcludeFromMonitors, 0);
            SetDword(CanIncludeInHistory, 0);
            SetDword(CanUploadToCloud, 0);
        }
        finally
        {
            CloseClipboard();
        }
    }

    /// <summary>Another app may hold the clipboard for a moment; a few short retries cover it.</summary>
    private static bool Open()
    {
        for (var attempt = 0; attempt < 5; attempt++)
        {
            if (OpenClipboard(0)) return true;
            Thread.Sleep(10);
        }
        return false;
    }

    private static void SetText(string text)
    {
        var bytes = (nuint)((text.Length + 1) * sizeof(char));
        var handle = GlobalAlloc(GMEM_MOVEABLE, bytes);
        if (handle == 0) return;
        var pointer = GlobalLock(handle);
        if (pointer == 0)
        {
            GlobalFree(handle);
            return;
        }
        Marshal.Copy(text.ToCharArray(), 0, pointer, text.Length);
        Marshal.WriteInt16(pointer, text.Length * sizeof(char), 0);
        GlobalUnlock(handle);
        // On success the clipboard owns the memory; on failure it is still ours to free.
        if (SetClipboardData(CF_UNICODETEXT, handle) == 0) GlobalFree(handle);
    }

    private static void SetDword(uint format, uint value)
    {
        if (format == 0) return;
        var handle = GlobalAlloc(GMEM_MOVEABLE, sizeof(uint));
        if (handle == 0) return;
        var pointer = GlobalLock(handle);
        if (pointer == 0)
        {
            GlobalFree(handle);
            return;
        }
        Marshal.WriteInt32(pointer, unchecked((int)value));
        GlobalUnlock(handle);
        if (SetClipboardData(format, handle) == 0) GlobalFree(handle);
    }
}
