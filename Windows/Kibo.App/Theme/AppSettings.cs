using System.ComponentModel;

namespace Kibo.App.Theme;

/// <summary>
/// The shell's view of the user's preferences — the port of <c>AppSettings.swift</c>. One
/// instance, bound to by Settings and read by everything else; every setter persists through
/// <see cref="SettingsStore"/> and fans the change out to whatever has to react.
/// </summary>
internal sealed class AppSettings : INotifyPropertyChanged
{
    public static AppSettings Shared { get; private set; } = null!;

    private readonly SettingsStore store;
    private string? hotkeyNote;

    public event PropertyChangedEventHandler? PropertyChanged;

    private AppSettings(SettingsStore store)
    {
        this.store = store;
    }

    public static void Initialize(SettingsStore store)
    {
        Shared = new AppSettings(store);
        ThemeManager.Apply(store.Appearance);
        ThemeManager.SetFontScale(store.FontSize.Factor());
    }

    public Appearance Appearance
    {
        get => store.Appearance;
        set
        {
            store.Appearance = value;
            ThemeManager.Apply(value);
            OnPropertyChanged(nameof(Appearance));
        }
    }

    public FontSize FontSize
    {
        get => store.FontSize;
        set
        {
            store.FontSize = value;
            ThemeManager.SetFontScale(value.Factor());
            OnPropertyChanged(nameof(FontSize));
        }
    }

    public bool ShowBubble
    {
        get => store.ShowBubble;
        set
        {
            store.ShowBubble = value;
            OnPropertyChanged(nameof(ShowBubble));
        }
    }

    public bool HotkeyEnabled
    {
        get => store.HotkeyEnabled;
        set
        {
            store.HotkeyEnabled = value;
            OnPropertyChanged(nameof(HotkeyEnabled));
        }
    }

    /// <summary>Why the hotkey is not working, when it is not — shown under its toggle.</summary>
    public string? HotkeyNote
    {
        get => hotkeyNote;
        set
        {
            hotkeyNote = value;
            OnPropertyChanged(nameof(HotkeyNote));
        }
    }

    /// <summary>Where the bubble was left, in device pixels.</summary>
    public (double X, double Y)? BubblePosition
    {
        get => store.BubblePosition;
        set => store.BubblePosition = value;
    }

    /// <summary>Re-reads the system theme, for Appearance = System after the OS flips.</summary>
    public void RefreshSystemAppearance()
    {
        if (Appearance == Appearance.System) ThemeManager.Apply(Appearance.System);
    }

    private void OnPropertyChanged(string name) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}
