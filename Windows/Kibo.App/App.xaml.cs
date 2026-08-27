using System.IO;
using Kibo.App.Services;
using Kibo.App.Theme;
using Kibo.App.Views;

namespace Kibo.App;

/// <summary>
/// The application object — the port of <c>KiboApp.swift</c>'s <c>AppDelegate</c>. Named
/// <c>KiboApplication</c> rather than <c>App</c> so it never collides with the <c>Kibo.App</c>
/// namespace.
/// </summary>
public partial class KiboApplication : Application
{
    private SingleInstance? singleInstance;

    /// <summary>The one model behind every converter surface.</summary>
    public ConverterModel Model { get; private set; } = null!;

    /// <summary>The tray icon, so menu actions can reach it for balloon tips.</summary>
    internal TrayIcon? Tray { get; private set; }
    private HotkeyService? hotkeys;

    /// <summary>
    /// <c>%LOCALAPPDATA%\Kibo\settings.json</c> — display preferences and the last mode, nothing
    /// else. There is nowhere in it to put entered or converted text.
    /// </summary>
    private static string SettingsPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Kibo", "settings.json");

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // A second launch hands over to the first — which opens its flyout — and exits.
        singleInstance = SingleInstance.TryAcquire(ShowFlyout);
        if (singleInstance is null)
        {
            Shutdown();
            return;
        }

        Forms.Application.EnableVisualStyles();

        var store = new SettingsStore(new JsonFileKeyValueStore(SettingsPath));
        AppSettings.Initialize(store);

        // No mode passed: the model opens in the remembered one, or in Both on a fresh install.
        Model = new ConverterModel(new WindowsClipboard(), memory: store);

        Panels.Flyout = new FlyoutWindow(Model);
        Panels.Pinned = new PinnedWindow(Model);
        Panels.Bubble = new BubbleWindow();
        Panels.Settings = new SettingsWindow();
        Panels.About = new AboutWindow();
        if (store.ShowBubble) Panels.Bubble.ApplyVisibility(true);

        // The tray icon last, so nothing it points at is null when a click arrives.
        Tray = new TrayIcon();

        hotkeys = new HotkeyService();
        hotkeys.Apply(store.HotkeyEnabled);

        // The two Windows-only toggles drive the bubble and the hotkey live.
        AppSettings.Shared.PropertyChanged += (_, args) =>
        {
            if (args.PropertyName == nameof(AppSettings.ShowBubble)) Panels.Bubble?.ApplyVisibility(AppSettings.Shared.ShowBubble);
            else if (args.PropertyName == nameof(AppSettings.HotkeyEnabled)) hotkeys?.Apply(AppSettings.Shared.HotkeyEnabled);
        };
    }

    /// <summary>Opens the converter — from a second launch's signal.</summary>
    public void ShowFlyout() => Panels.ShowFlyout(FlyoutAnchor.TrayCorner);

    protected override void OnExit(ExitEventArgs e)
    {
        hotkeys?.Dispose();
        Tray?.Dispose();
        Panels.Pinned?.CloseForReal();
        Panels.Settings?.CloseForReal();
        Panels.About?.CloseForReal();
        singleInstance?.Dispose();
        base.OnExit(e);
    }
}
