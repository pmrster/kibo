using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Media.Animation;
using System.Windows.Shapes;

namespace Kibo.App.Controls;

/// <summary>
/// The switch from <c>SharedViews.swift</c>. Like the segmented control, it exists so the "on"
/// state paints with <c>Brush.Accent</c> rather than the system accent a WPF <c>CheckBox</c> or
/// the WinUI toggle would use.
/// </summary>
/// <remarks>
/// It reports its taps through <see cref="Toggled"/> rather than a two-way binding, because for
/// Open-at-login the real state is read back from the registry after the request — the toggle is
/// told what happened, it does not decide it. <see cref="SetOn"/> is how the caller sets the
/// visual state from that read-back.
/// </remarks>
internal sealed class ThemedToggle : ButtonBase
{
    public static readonly DependencyProperty TitleProperty = DependencyProperty.Register(
        nameof(Title), typeof(string), typeof(ThemedToggle), new PropertyMetadata(""));

    public string Title
    {
        get => (string)GetValue(TitleProperty);
        set => SetValue(TitleProperty, value);
    }

    public event Action<bool>? Toggled;

    private readonly Border track;
    private readonly Ellipse thumb;
    private bool isOn;

    public ThemedToggle()
    {
        Cursor = Cursors.Hand;
        Background = Brushes.Transparent;
        BorderThickness = new Thickness(0);

        var title = new TextBlock { VerticalAlignment = VerticalAlignment.Center };
        title.SetResourceReference(TextBlock.FontSizeProperty, "Font.Body");
        title.SetResourceReference(TextBlock.ForegroundProperty, "Brush.Text");
        title.SetBinding(TextBlock.TextProperty, new System.Windows.Data.Binding(nameof(Title)) { Source = this });

        thumb = new Ellipse { Width = 16, Height = 16, HorizontalAlignment = HorizontalAlignment.Left, Margin = new Thickness(2) };
        thumb.SetResourceReference(Shape.FillProperty, "Brush.Panel");

        track = new Border { Width = 34, Height = 20, CornerRadius = new CornerRadius(10), Child = thumb };
        track.SetResourceReference(Border.BackgroundProperty, "Brush.Track");

        var row = new DockPanel { LastChildFill = false };
        DockPanel.SetDock(title, Dock.Left);
        DockPanel.SetDock(track, Dock.Right);
        row.Children.Add(title);
        row.Children.Add(track);

        Content = row;
        Template = ContentOnlyTemplate();
        Click += (_, _) => Toggled?.Invoke(!isOn);
        AutomationProperties.SetName(this, Title);
    }

    private static ControlTemplate ContentOnlyTemplate()
    {
        var template = new ControlTemplate(typeof(ThemedToggle));
        var presenter = new FrameworkElementFactory(typeof(ContentPresenter));
        template.VisualTree = presenter;
        return template;
    }

    /// <summary>Sets the visual state to match what was actually read back.</summary>
    public void SetOn(bool on)
    {
        isOn = on;
        thumb.HorizontalAlignment = on ? HorizontalAlignment.Right : HorizontalAlignment.Left;
        track.SetResourceReference(Border.BackgroundProperty, on ? "Brush.Accent" : "Brush.Track");
        AutomationProperties.SetHelpText(this, on ? "On" : "Off");
    }
}
