using Kibo.App.Controls;
using Kibo.App.Services;
using Kibo.App.Theme;

namespace Kibo.App.Views;

/// <summary>The Settings panel — the port of <c>SettingsView.swift</c>, with the Windows-only section.</summary>
internal sealed class SettingsWindow : PanelWindow
{
    private readonly ThemedToggle loginToggle = new() { Title = "Open Kibo at login" };
    private readonly TextBlock loginNote = new();
    private readonly TextBlock hotkeyNote = new();

    public SettingsWindow() : base("Settings", 320, 400)
    {
        var settings = AppSettings.Shared;
        var stack = new StackPanel { Margin = new Thickness(20) };

        // Title row
        var titleRow = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 18) };
        titleRow.Children.Add(new KiboSpriteControl { PixelSize = 2, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 8, 0) });
        var title = new TextBlock { Text = "Settings", FontWeight = FontWeights.SemiBold, VerticalAlignment = VerticalAlignment.Center, FontFamily = AppFonts.Ui };
        title.SetResourceReference(TextBlock.FontSizeProperty, "Font.SettingsTitle");
        title.SetResourceReference(TextBlock.ForegroundProperty, "Brush.Text");
        titleRow.Children.Add(title);
        stack.Children.Add(titleRow);

        // APPEARANCE
        stack.Children.Add(SectionHeader("APPEARANCE"));
        var appearance = new ThemedSegmentedControl
        {
            ItemsSource = Appearances.All.Select(a => new SegmentItem(a, AppearanceLabel(a))).ToList(),
            SelectedValue = settings.Appearance,
            Margin = new Thickness(0, 0, 0, 16),
        };
        Bind(appearance, v => settings.Appearance = (Appearance)v);
        stack.Children.Add(appearance);

        // TEXT SIZE
        stack.Children.Add(SectionHeader("TEXT SIZE"));
        var textSize = new ThemedSegmentedControl
        {
            ItemsSource = FontSizes.All.Select(f => new SegmentItem(f, FontSizeLabel(f))).ToList(),
            SelectedValue = settings.FontSize,
            Margin = new Thickness(0, 0, 0, 16),
        };
        Bind(textSize, v => settings.FontSize = (Kibo.Core.FontSize)v);
        stack.Children.Add(textSize);

        // STARTUP
        stack.Children.Add(SectionHeader("STARTUP"));
        loginToggle.Toggled += on => { LaunchAtLogin.Set(on); RefreshLogin(); };
        stack.Children.Add(Card(loginToggle));
        loginNote.SetResourceReference(TextBlock.FontSizeProperty, "Font.Note");
        loginNote.SetResourceReference(TextBlock.ForegroundProperty, "Brush.Dim");
        loginNote.TextWrapping = TextWrapping.Wrap;
        loginNote.Margin = new Thickness(0, 4, 0, 16);
        stack.Children.Add(loginNote);

        // WINDOWS
        stack.Children.Add(SectionHeader("WINDOWS"));
        var bubbleToggle = new ThemedToggle { Title = "Show floating Kibo on the desktop" };
        bubbleToggle.SetOn(settings.ShowBubble);
        bubbleToggle.Toggled += on => { settings.ShowBubble = on; bubbleToggle.SetOn(on); };
        stack.Children.Add(Card(bubbleToggle));

        var hotkeyToggle = new ThemedToggle { Title = "Open with Ctrl+Alt+K", Margin = new Thickness(0, 8, 0, 0) };
        hotkeyToggle.SetOn(settings.HotkeyEnabled);
        hotkeyToggle.Toggled += on => { settings.HotkeyEnabled = on; hotkeyToggle.SetOn(on); };
        stack.Children.Add(Card(hotkeyToggle));
        hotkeyNote.SetResourceReference(TextBlock.FontSizeProperty, "Font.Note");
        hotkeyNote.SetResourceReference(TextBlock.ForegroundProperty, "Brush.Dim");
        hotkeyNote.TextWrapping = TextWrapping.Wrap;
        hotkeyNote.Margin = new Thickness(0, 4, 0, 16);
        stack.Children.Add(hotkeyNote);
        settings.PropertyChanged += (_, e) => { if (e.PropertyName == nameof(AppSettings.HotkeyNote)) UpdateHotkeyNote(); };

        // PREVIEW
        stack.Children.Add(SectionHeader("PREVIEW"));
        var preview = new StackPanel();
        preview.Children.Add(PreviewLine("l;ylfu ้ำสสน ครับ", "Font.PreviewSmall", "Brush.Dim"));
        preview.Children.Add(PreviewLine("สวัสดี hello ครับ", "Font.Thai", "Brush.Text"));
        stack.Children.Add(Card(preview));

        var close = CloseButton();
        close.Margin = new Thickness(0, 18, 0, 0);
        stack.Children.Add(close);

        Content = new ScrollViewer { Content = stack, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
    }

    protected override void OnShown() => RefreshLogin();

    private void RefreshLogin()
    {
        var state = LaunchAtLogin.State();
        loginToggle.SetOn(state != LoginState.Off);
        loginNote.Text = state == LoginState.DisabledByUser
            ? "Enabled here, but turned off under Task Manager → Startup apps."
            : "";
        loginNote.Visibility = loginNote.Text.Length == 0 ? Visibility.Collapsed : Visibility.Visible;
        UpdateHotkeyNote();
    }

    private void UpdateHotkeyNote()
    {
        hotkeyNote.Text = AppSettings.Shared.HotkeyNote ?? "";
        hotkeyNote.Visibility = hotkeyNote.Text.Length == 0 ? Visibility.Collapsed : Visibility.Visible;
    }

    private Border Card(UIElement child)
    {
        var card = new Border { CornerRadius = new CornerRadius(8), Padding = new Thickness(10, 8, 10, 8), Child = child };
        card.SetResourceReference(Border.BackgroundProperty, "Brush.FieldFill");
        return card;
    }

    private static TextBlock PreviewLine(string text, string sizeKey, string brushKey)
    {
        var block = new TextBlock { Text = text, FontFamily = AppFonts.Thai, Margin = new Thickness(0, 2, 0, 2) };
        block.SetResourceReference(TextBlock.FontSizeProperty, sizeKey);
        block.SetResourceReference(TextBlock.ForegroundProperty, brushKey);
        return block;
    }

    private static void Bind(ThemedSegmentedControl control, Action<object> onChange)
    {
        System.ComponentModel.DependencyPropertyDescriptor
            .FromProperty(ThemedSegmentedControl.SelectedValueProperty, typeof(ThemedSegmentedControl))
            .AddValueChanged(control, (_, _) => { if (control.SelectedValue is { } v) onChange(v); });
    }

    private static string AppearanceLabel(Appearance a) => a switch
    {
        Appearance.System => "System",
        Appearance.Light => "Light",
        Appearance.Dark => "Dark",
        _ => "",
    };

    private static string FontSizeLabel(Kibo.Core.FontSize f) => f switch
    {
        Kibo.Core.FontSize.Small => "S",
        Kibo.Core.FontSize.Medium => "M",
        Kibo.Core.FontSize.Large => "L",
        _ => "",
    };
}
