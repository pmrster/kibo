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
        Panels.Settings = new SettingsWindow();
        Panels.About = new AboutWindow();

        // The tray icon last, so nothing it points at is null when a click arrives.
        Tray = new TrayIcon();
    }

    /// <summary>Opens the converter — from a second launch's signal.</summary>
    public void ShowFlyout() => Panels.ShowFlyout(FlyoutAnchor.TrayCorner);

    protected override void OnExit(ExitEventArgs e)
    {
        Tray?.Dispose();
        singleInstance?.Dispose();
        base.OnExit(e);
    }
}
