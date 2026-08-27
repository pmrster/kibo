using System.IO;
using Microsoft.Win32;

namespace Kibo.App.Theme;

/// <summary>
/// What Windows is currently set to, read from the Personalize key. Two flags, because Windows
/// keeps two: apps and the taskbar can be themed independently.
/// </summary>
internal static class SystemTheme
{
    private const string PersonalizeKey = @"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize";

    /// <summary>Drives the palette when Appearance is System.</summary>
    public static bool AppsUseLightTheme => ReadFlag("AppsUseLightTheme");

    /// <summary>Drives the tray icon's tint: the taskbar's theme, not the apps'.</summary>
    public static bool SystemUsesLightTheme => ReadFlag("SystemUsesLightTheme");

    /// <summary>A missing value means the light default.</summary>
    private static bool ReadFlag(string name)
    {
        try
        {
            return Registry.GetValue(PersonalizeKey, name, 1) is not int value || value != 0;
        }
        catch (Exception e) when (e is System.Security.SecurityException or IOException)
        {
            return true;
        }
    }
}
