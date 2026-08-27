using System.ComponentModel;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using Kibo.App.Controls;
using Kibo.App.Theme;

namespace Kibo.App.Views;

/// <summary>
/// The converter surface — the port of <c>ConverterView.swift</c>. Built in code rather than XAML
/// so its bindings are checked by the compiler. The flyout hosts it at a fixed 360 DIP width; the
/// pinned window hosts a second instance over the same model, filling the window.
/// </summary>
internal sealed class ConverterView : UserControl
{
    private readonly ConverterModel model;
    private readonly TextBox input = new();
    private readonly TextBlock resultText = new();
    private readonly TextBlock placeholder = new();
    private readonly KiboSpriteControl mascot = new() { PixelSize = 2, Margin = new Thickness(0, 0, 14, -4) };
    private readonly TextBlock badge = new();
    private readonly Button copyButton = new();
    private readonly TextBlock copyLabel = new();
    private readonly ThemedSegmentedControl modePicker = new() { NumberKeyShortcuts = true };
    private readonly DispatcherTimer copyResetTimer;

    public ConverterView(ConverterModel model, double? fixedWidth)
    {
        this.model = model;
        copyResetTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1.6) };
        copyResetTimer.Tick += (_, _) => { copyResetTimer.Stop(); model.DismissCopyConfirmation(); };

        Build(fixedWidth);
        model.PropertyChanged += OnModelChanged;
        Sync();
        Loaded += (_, _) => input.Focus();
    }

    private void Build(double? fixedWidth)
    {
        SetResourceReference(BackgroundProperty, "Brush.Panel");
        if (fixedWidth is { } w) Width = w;

        var stack = new StackPanel { Margin = new Thickness(14) };
        stack.Children.Add(Header());
        stack.Children.Add(ModeRow());
        stack.Children.Add(Field("INPUT", InputEditor(), mascot));
        stack.Children.Add(Field("RESULT", ResultPanel(), badge));
        stack.Children.Add(ActionRow());
        stack.Children.Add(new PrivacyCapsule { Margin = new Thickness(0, 12, 0, 0) });
        Content = stack;

        InstallShortcuts();
    }

    // ── Header ───────────────────────────────────────────────────────────────────────────────

    private UIElement Header()
    {
        var title = new TextBlock { Text = "Kibo", FontWeight = FontWeights.SemiBold, VerticalAlignment = VerticalAlignment.Center };
        title.FontFamily = AppFonts.Ui;
        title.SetResourceReference(TextBlock.FontSizeProperty, "Font.Title");

        var pin = IconButton("", "Float above other apps, so it stays open while you paste (Ctrl+Shift+P)", () => Panels.TogglePinned());
        AutomationProperties.SetName(pin, "Pin as floating window");

        var row = new DockPanel { Margin = new Thickness(0, 0, 0, 12), LastChildFill = false };
        DockPanel.SetDock(title, Dock.Left);
        DockPanel.SetDock(pin, Dock.Right);
        row.Children.Add(title);
        row.Children.Add(pin);
        return row;
    }

    // ── Mode row ─────────────────────────────────────────────────────────────────────────────

    private UIElement ModeRow()
    {
        modePicker.ItemsSource = ConversionModes.All
            .Select(m => new SegmentItem(m, ModeLabels.Label(m), ModeLabels.HelpText(m)))
            .ToList();
        modePicker.SelectedValue = model.Mode;
        modePicker.SetValue(DockPanel.DockProperty, Dock.Left);
        DependencyPropertyDescriptor
            .FromProperty(ThemedSegmentedControl.SelectedValueProperty, typeof(ThemedSegmentedControl))
            .AddValueChanged(modePicker, (_, _) =>
            {
                if (modePicker.SelectedValue is ConversionMode m) model.Mode = m;
            });

        var swap = IconButton("", "Swap direction (Ctrl+Shift+S)", () => model.SwapDirection());
        AutomationProperties.SetName(swap, "Swap direction");

        var grid = new Grid { Margin = new Thickness(0, 0, 0, 12) };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        Grid.SetColumn(modePicker, 0);
        Grid.SetColumn(swap, 1);
        swap.Margin = new Thickness(8, 0, 0, 0);
        grid.Children.Add(modePicker);
        grid.Children.Add(swap);
        return grid;
    }

    // ── Fields ───────────────────────────────────────────────────────────────────────────────

    private UIElement Field(string label, UIElement content, UIElement accessory)
    {
        var caption = new TextBlock { Text = label, FontWeight = FontWeights.Heavy };
        caption.FontFamily = AppFonts.Ui;
        caption.SetResourceReference(TextBlock.FontSizeProperty, "Font.Label");
        caption.SetResourceReference(TextBlock.ForegroundProperty, "Brush.Dim");
        caption.VerticalAlignment = VerticalAlignment.Bottom;

        var header = new DockPanel { LastChildFill = false, Margin = new Thickness(0, 0, 0, 4) };
        DockPanel.SetDock(caption, Dock.Left);
        DockPanel.SetDock(accessory, Dock.Right);
        header.Children.Add(caption);
        header.Children.Add(accessory);

        var stack = new StackPanel { Margin = new Thickness(0, 0, 0, 12) };
        stack.Children.Add(header);   // the mascot perches here, above the field, tucked over its top edge
        stack.Children.Add(content);
        return stack;
    }

    private UIElement InputEditor()
    {
        input.AcceptsReturn = true;
        input.TextWrapping = TextWrapping.Wrap;
        input.VerticalScrollBarVisibility = ScrollBarVisibility.Auto;
        input.FontFamily = AppFonts.Thai;
        input.BorderThickness = new Thickness(0);
        input.Padding = new Thickness(6);
        input.SetResourceReference(TextBox.FontSizeProperty, "Font.Thai");
        input.SetResourceReference(ForegroundProperty, "Brush.Text");
        input.SetResourceReference(BackgroundProperty, "Brush.FieldFill");
        SpellCheck.SetIsEnabled(input, false);
        input.SetBinding(HeightProperty, ResourceBinding("Metric.FieldHeight"));
        input.TextChanged += (_, _) => { if (model.Input != input.Text) model.Input = input.Text; };
        AutomationProperties.SetName(input, "Text you typed");

        return RoundedHost(input);
    }

    private UIElement ResultPanel()
    {
        resultText.FontFamily = AppFonts.Thai;
        resultText.TextWrapping = TextWrapping.Wrap;
        resultText.SetResourceReference(TextBlock.FontSizeProperty, "Font.Thai");
        resultText.SetResourceReference(TextBlock.ForegroundProperty, "Brush.Text");

        placeholder.Text = "The corrected text appears here";
        placeholder.FontFamily = AppFonts.Thai;
        placeholder.SetResourceReference(TextBlock.FontSizeProperty, "Font.Thai");
        placeholder.SetResourceReference(TextBlock.ForegroundProperty, "Brush.Dim");

        var layers = new Grid();
        layers.Children.Add(placeholder);
        layers.Children.Add(resultText);

        var scroll = new ScrollViewer
        {
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            Content = layers,
            Padding = new Thickness(6),
            Background = Brushes.Transparent,
        };
        scroll.SetBinding(HeightProperty, ResourceBinding("Metric.FieldHeight"));
        AutomationProperties.SetName(scroll, "Result");
        return RoundedHost(scroll);
    }

    private Border RoundedHost(UIElement child)
    {
        var host = new Border { CornerRadius = new CornerRadius(8), Child = child };
        host.SetResourceReference(Border.BackgroundProperty, "Brush.FieldFill");
        return host;
    }

    // ── Action row ───────────────────────────────────────────────────────────────────────────

    private UIElement ActionRow()
    {
        var paste = SecondaryButton("", "Paste", "Reads the clipboard only when you press this (Ctrl+Shift+V)", () => model.Paste());
        var clear = SecondaryButton("", "Clear", "Clear the input (Ctrl+Shift+K)", () => model.Clear());

        copyLabel.Text = "Copy";
        copyLabel.FontWeight = FontWeights.SemiBold;
        copyLabel.VerticalAlignment = VerticalAlignment.Center;
        copyLabel.SetResourceReference(TextBlock.FontSizeProperty, "Font.Body");
        copyButton.Content = copyLabel;
        copyButton.Padding = new Thickness(14, 6, 14, 6);
        copyButton.Cursor = Cursors.Hand;
        copyButton.Template = FlatButtonTemplate(8);
        copyButton.SetResourceReference(BackgroundProperty, "Brush.Accent15");
        copyLabel.SetResourceReference(TextBlock.ForegroundProperty, "Brush.Accent");
        copyButton.Click += (_, _) => model.CopyOutput();
        copyButton.ToolTip = "Copy the result (Ctrl+Shift+C)";
        AutomationProperties.SetName(copyButton, "Copy result");

        var row = new DockPanel { LastChildFill = false };
        var left = new StackPanel { Orientation = Orientation.Horizontal };
        clear.Margin = new Thickness(8, 0, 0, 0);
        left.Children.Add(paste);
        left.Children.Add(clear);
        DockPanel.SetDock(left, Dock.Left);
        DockPanel.SetDock(copyButton, Dock.Right);
        row.Children.Add(left);
        row.Children.Add(copyButton);
        return row;
    }

    // ── Small builders ───────────────────────────────────────────────────────────────────────

    private Button IconButton(string glyph, string tooltip, Action action)
    {
        var text = new TextBlock { Text = glyph, FontFamily = new FontFamily("Segoe MDL2 Assets"), FontSize = 12 };
        text.SetResourceReference(TextBlock.ForegroundProperty, "Brush.Dim");
        var button = new Button { Content = text, Template = FlatButtonTemplate(6), Padding = new Thickness(6), Cursor = Cursors.Hand, ToolTip = tooltip };
        button.Background = Brushes.Transparent;
        button.Click += (_, _) => action();
        return button;
    }

    private Button SecondaryButton(string glyph, string label, string tooltip, Action action)
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal };
        row.Children.Add(new TextBlock { Text = glyph, FontFamily = new FontFamily("Segoe MDL2 Assets"), FontSize = 11, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 4, 0) });
        var text = new TextBlock { Text = label, VerticalAlignment = VerticalAlignment.Center };
        text.SetResourceReference(TextBlock.FontSizeProperty, "Font.Button");
        text.SetResourceReference(TextBlock.ForegroundProperty, "Brush.Text");
        row.Children.Add(text);

        var button = new Button { Content = row, Template = FlatButtonTemplate(7), Padding = new Thickness(10, 5, 10, 5), Cursor = Cursors.Hand, ToolTip = tooltip };
        button.SetResourceReference(BackgroundProperty, "Brush.PanelEdge70");
        button.Click += (_, _) => action();
        AutomationProperties.SetName(button, label);
        return button;
    }

    private static ControlTemplate FlatButtonTemplate(double radius)
    {
        var template = new ControlTemplate(typeof(Button));
        var border = new FrameworkElementFactory(typeof(Border));
        border.SetValue(Border.CornerRadiusProperty, new CornerRadius(radius));
        border.SetValue(Border.BackgroundProperty, new TemplateBindingExtension(BackgroundProperty));
        border.SetValue(Border.PaddingProperty, new TemplateBindingExtension(PaddingProperty));
        var presenter = new FrameworkElementFactory(typeof(ContentPresenter));
        presenter.SetValue(HorizontalAlignmentProperty, HorizontalAlignment.Center);
        presenter.SetValue(VerticalAlignmentProperty, VerticalAlignment.Center);
        border.AppendChild(presenter);
        template.VisualTree = border;
        return template;
    }

    private static System.Windows.Data.Binding ResourceBinding(string key) =>
        new() { Source = Application.Current.Resources, Path = new PropertyPath("[" + key + "]"), Mode = System.Windows.Data.BindingMode.OneWay };

    // ── Shortcuts ────────────────────────────────────────────────────────────────────────────

    private void InstallShortcuts()
    {
        void Bind(Key key, ModifierKeys mods, Action action)
        {
            var command = new DelegateCommand(action);
            InputBindings.Add(new KeyBinding(command, key, mods));
        }
        // Ctrl+1..4 select modes; the other actions use Ctrl+Shift because the input owns Ctrl+V/C.
        var keys = new[] { Key.D1, Key.D2, Key.D3, Key.D4 };
        for (var i = 0; i < ConversionModes.All.Count && i < keys.Length; i++)
        {
            var mode = ConversionModes.All[i];
            Bind(keys[i], ModifierKeys.Control, () => model.Mode = mode);
        }
        Bind(Key.V, ModifierKeys.Control | ModifierKeys.Shift, () => model.Paste());
        Bind(Key.K, ModifierKeys.Control | ModifierKeys.Shift, () => model.Clear());
        Bind(Key.C, ModifierKeys.Control | ModifierKeys.Shift, () => model.CopyOutput());
        Bind(Key.S, ModifierKeys.Control | ModifierKeys.Shift, () => model.SwapDirection());
        Bind(Key.P, ModifierKeys.Control | ModifierKeys.Shift, () => Panels.TogglePinned());
    }

    // ── Model sync ───────────────────────────────────────────────────────────────────────────

    /// <summary>Puts the caret in the input, for when the flyout opens.</summary>
    public void FocusInput() => input.Focus();

    private void OnModelChanged(object? sender, PropertyChangedEventArgs e) => Sync();

    private void Sync()
    {
        if (input.Text != model.Input) input.Text = model.Input;
        resultText.Text = model.Output;
        placeholder.Visibility = model.Output.Length == 0 ? Visibility.Visible : Visibility.Collapsed;
        modePicker.SelectedValue = model.Mode;
        badge.Text = ModeLabels.Badge(model.Mode);

        mascot.Mood = model.DidCopy ? KiboSpriteControl.MoodKind.Pleased : KiboSpriteControl.MoodKind.Idle;
        copyLabel.Text = model.DidCopy ? "Copied" : "Copy";
        copyButton.SetResourceReference(BackgroundProperty, model.DidCopy ? "Brush.Green15" : "Brush.Accent15");
        copyLabel.SetResourceReference(TextBlock.ForegroundProperty, model.DidCopy ? "Brush.Green" : "Brush.Accent");
        if (model.DidCopy) { copyResetTimer.Stop(); copyResetTimer.Start(); }

        badge.FontWeight = FontWeights.SemiBold;
        badge.SetResourceReference(TextBlock.FontSizeProperty, "Font.Badge");
        badge.SetResourceReference(TextBlock.ForegroundProperty, "Brush.Dim");
    }
}
