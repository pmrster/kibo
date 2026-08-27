using System.Globalization;

namespace Kibo.Core;

/// <summary>
/// The user's preferences. The port of <c>SettingsStore.swift</c>, plus the three values only the
/// Windows shell has: whether the floating bubble shows, whether the hotkey is registered, and
/// where the bubble was left.
/// </summary>
/// <remarks>
/// Everything here is a display preference or the last mode picked — deliberately nothing about
/// what was converted. Unknown or missing values fall back to the defaults, so a value written by
/// a newer build, or corrupted by hand, never crashes an older one. Launch-at-login is
/// deliberately <b>not</b> here: the registry Run key is the source of truth, as
/// <c>SMAppService</c> is on macOS, and it is read back rather than remembered.
/// </remarks>
public sealed class SettingsStore(IKeyValueStore store) : IModeMemory
{
    private static class Key
    {
        public const string Appearance = "appearance";
        public const string FontSize = "fontSize";
        public const string LastMode = "lastMode";
        public const string ShowBubble = "showBubble";
        public const string HotkeyEnabled = "hotkeyEnabled";
        public const string BubbleX = "bubbleX";
        public const string BubbleY = "bubbleY";
    }

    public Appearance Appearance
    {
        get => Appearances.TryParse(store.Get(Key.Appearance), out var value) ? value : Appearance.System;
        set => store.Set(Key.Appearance, value.RawValue());
    }

    public FontSize FontSize
    {
        get => FontSizes.TryParse(store.Get(Key.FontSize), out var value) ? value : FontSize.Small;
        set => store.Set(Key.FontSize, value.RawValue());
    }

    /// <summary>
    /// Reopening the converter in the mode you left it in. See <see cref="ConversionModes.Default"/>
    /// for what a first launch gets, and why.
    /// </summary>
    public ConversionMode LastMode
    {
        get => ConversionModes.TryParse(store.Get(Key.LastMode), out var value) ? value : ConversionModes.Default;
        set => store.Set(Key.LastMode, value.RawValue());
    }

    /// <summary>The floating mascot on the desktop. On by default — it is how Kibo is found.</summary>
    public bool ShowBubble
    {
        get => ParseBool(store.Get(Key.ShowBubble)) ?? true;
        set => store.Set(Key.ShowBubble, value ? "true" : "false");
    }

    /// <summary>Whether Ctrl+Alt+K opens the converter. On by default, off for users it conflicts with.</summary>
    public bool HotkeyEnabled
    {
        get => ParseBool(store.Get(Key.HotkeyEnabled)) ?? true;
        set => store.Set(Key.HotkeyEnabled, value ? "true" : "false");
    }

    /// <summary>
    /// Where the bubble was left, in device pixels. <c>null</c> until it has been moved, and
    /// <c>null</c> again if either half fails to parse — half a position is no position. Written
    /// and read with the invariant culture, because <c>double.Parse</c> follows the user's locale
    /// and a German one writes <c>1812,5</c>.
    /// </summary>
    public (double X, double Y)? BubblePosition
    {
        get
        {
            if (double.TryParse(store.Get(Key.BubbleX), NumberStyles.Float, CultureInfo.InvariantCulture, out var x)
                && double.TryParse(store.Get(Key.BubbleY), NumberStyles.Float, CultureInfo.InvariantCulture, out var y))
            {
                return (x, y);
            }
            return null;
        }
        set
        {
            store.Set(Key.BubbleX, value?.X.ToString("R", CultureInfo.InvariantCulture));
            store.Set(Key.BubbleY, value?.Y.ToString("R", CultureInfo.InvariantCulture));
        }
    }

    public ConversionMode LoadMode() => LastMode;

    public void SaveMode(ConversionMode mode) => LastMode = mode;

    /// <summary>Exactly <c>"true"</c> or <c>"false"</c>; anything else is garbage, not a guess.</summary>
    private static bool? ParseBool(string? raw) => raw switch
    {
        "true" => true,
        "false" => false,
        _ => null,
    };
}
