using System.IO;
using Microsoft.Win32;

namespace Kibo.App.Services;

/// <summary>Whether Kibo starts with Windows. The port of <c>LaunchAtLogin.swift</c>.</summary>
internal enum LoginState
{
    On,
    Off,
    /// <summary>Enabled in the Run key, but the user switched it off under Task Manager → Startup apps.</summary>
    DisabledByUser,
}

/// <summary>
/// Start-at-login via <c>HKCU\…\CurrentVersion\Run</c>. Like <c>SMAppService</c> on macOS, the
/// registry is the source of truth: the state is read back after every write, never trusted, and
/// no defaults key mirrors it.
/// </summary>
internal static class LaunchAtLogin
{
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string StartupApprovedKey = @"Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run";
    private const string ValueName = "Kibo";

    /// <summary>The single-file bundle's own path, quoted.</summary>
    private static string Command => $"\"{Environment.ProcessPath}\"";

    public static void Set(bool enabled)
    {
        try
        {
            using var key = Registry.CurrentUser.CreateSubKey(RunKey);
            if (enabled) key.SetValue(ValueName, Command);
            else key.DeleteValue(ValueName, throwOnMissingValue: false);
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or System.Security.SecurityException)
        {
            // Read back regardless; State reports what actually happened.
        }
    }

    public static LoginState State()
    {
        try
        {
            using var run = Registry.CurrentUser.OpenSubKey(RunKey);
            if (run?.GetValue(ValueName) is null) return LoginState.Off;

            // The first byte of the StartupApproved blob is 0x03 when a user has disabled the item
            // in Task Manager while leaving the Run value in place.
            using var approved = Registry.CurrentUser.OpenSubKey(StartupApprovedKey);
            if (approved?.GetValue(ValueName) is byte[] { Length: > 0 } blob && (blob[0] & 0x01) != 0)
            {
                return LoginState.DisabledByUser;
            }
            return LoginState.On;
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or System.Security.SecurityException)
        {
            return LoginState.Off;
        }
    }
}
