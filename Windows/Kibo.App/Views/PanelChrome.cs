using System.ComponentModel;
using System.Windows.Interop;
using Kibo.App.Controls;
using Kibo.App.Theme;

namespace Kibo.App.Views;

/// <summary>Shared chrome for the two small fixed windows, Settings and About.</summary>
internal abstract class PanelWindow : Window
{
    protected PanelWindow(string title, double width, double height)
    {
        Title = title;
        Width = width;
        Height = height;
        ResizeMode = ResizeMode.NoResize;
        ShowInTaskbar = false;
        Topmost = true;
        WindowStyle = WindowStyle.SingleBorderWindow;
        UseLayoutRounding = true;
        SetResourceReference(BackgroundProperty, "Brush.Panel");

        SourceInitialized += (_, _) => ThemeManager.ApplyTitleBar(this);
        ThemeManager.Changed += () => { if (IsLoaded) ThemeManager.ApplyTitleBar(this); };
        Closing += OnClosing;
    }

    private bool wasShown;
    private bool reallyClose;

    public void ShowCentered()
    {
        if (!wasShown) { WindowStartupLocation = WindowStartupLocation.CenterScreen; wasShown = true; }
        Show();
        Activate();
        OnShown();
    }

    protected virtual void OnShown() { }

    private void OnClosing(object? sender, CancelEventArgs e)
    {
        if (reallyClose) return;
        e.Cancel = true;
        Hide();
    }

    public void CloseForReal()
    {
        reallyClose = true;
        Close();
    }

    /// <summary>The pill "Close" button both panels end with.</summary>
    protected Button CloseButton()
    {
        var label = new TextBlock { Text = "Close", FontWeight = FontWeights.SemiBold };
        label.SetResourceReference(TextBlock.FontSizeProperty, "Font.Body");
        label.SetResourceReference(TextBlock.ForegroundProperty, "Brush.Text");
        var button = new Button
        {
            Content = label,
            Padding = new Thickness(22, 7, 22, 7),
            HorizontalAlignment = HorizontalAlignment.Center,
            Cursor = System.Windows.Input.Cursors.Hand,
            Template = Pill(8),
        };
        button.SetResourceReference(BackgroundProperty, "Brush.Accent18");
        button.Click += (_, _) => Hide();
        AutomationProperties.SetName(button, "Close window");
        return button;
    }

    protected static System.Windows.Controls.ControlTemplate Pill(double radius)
    {
        var template = new System.Windows.Controls.ControlTemplate(typeof(Button));
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

    protected static TextBlock SectionHeader(string text)
    {
        var header = new TextBlock { Text = text, FontWeight = FontWeights.Heavy, Margin = new Thickness(0, 0, 0, 6) };
        header.FontFamily = AppFonts.Ui;
        header.SetResourceReference(TextBlock.FontSizeProperty, "Font.Label");
        header.SetResourceReference(TextBlock.ForegroundProperty, "Brush.Dim");
        return header;
    }
}
