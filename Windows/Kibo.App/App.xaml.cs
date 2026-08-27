using System.IO;
using System.Windows;
using Kibo.App.Services;
using Kibo.App.Theme;

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
    }

    /// <summary>Opens the converter — from the tray, the bubble, the hotkey, or a second launch.</summary>
    public void ShowFlyout()
    {
        // The flyout arrives with the tray icon; until then there is nothing to show.
    }

    protected override void OnExit(ExitEventArgs e)
    {
        singleInstance?.Dispose();
        base.OnExit(e);
    }
}
