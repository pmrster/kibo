using System.Collections;
using System.Windows.Controls.Primitives;
using System.Windows.Data;
using System.Windows.Input;
using Kibo.App.Theme;

namespace Kibo.App.Controls;

/// <summary>One option in a <see cref="ThemedSegmentedControl"/>.</summary>
internal sealed record SegmentItem(object Value, string Label, string? Tooltip = null);

/// <summary>
/// The hand-rolled segmented control from <c>SharedViews.swift</c>. It exists because WPF's own
/// selection chrome, like AppKit's <c>.pickerStyle(.segmented)</c>, paints with the system accent
/// — whatever the user set in Windows personalisation — which wrecks the near-monochrome palette.
/// This one paints the selected segment with <c>Brush.Accent</c> and the panel colour on top, and
/// it renders in a snapshot, which the system control never did.
/// </summary>
/// <remarks>
/// Built from <see cref="RadioButton"/>s so keyboard navigation and UI Automation come for free.
/// Used for the four modes, and for Appearance and Text size in Settings.
/// </remarks>
internal sealed class ThemedSegmentedControl : Control
{
    public static readonly DependencyProperty ItemsSourceProperty = DependencyProperty.Register(
        nameof(ItemsSource), typeof(IEnumerable), typeof(ThemedSegmentedControl),
        new PropertyMetadata(null, (d, _) => ((ThemedSegmentedControl)d).Rebuild()));

    public static readonly DependencyProperty SelectedValueProperty = DependencyProperty.Register(
        nameof(SelectedValue), typeof(object), typeof(ThemedSegmentedControl),
        new FrameworkPropertyMetadata(null, FrameworkPropertyMetadataOptions.BindsTwoWayByDefault,
            (d, _) => ((ThemedSegmentedControl)d).SyncSelection()));

    /// <summary>Adds a Ctrl+1..4 shortcut per segment, as the mode picker has.</summary>
    public static readonly DependencyProperty NumberKeyShortcutsProperty = DependencyProperty.Register(
        nameof(NumberKeyShortcuts), typeof(bool), typeof(ThemedSegmentedControl), new PropertyMetadata(false));

    public IEnumerable? ItemsSource
    {
        get => (IEnumerable?)GetValue(ItemsSourceProperty);
        set => SetValue(ItemsSourceProperty, value);
    }

    public object? SelectedValue
    {
        get => GetValue(SelectedValueProperty);
        set => SetValue(SelectedValueProperty, value);
    }

    public bool NumberKeyShortcuts
    {
        get => (bool)GetValue(NumberKeyShortcutsProperty);
        set => SetValue(NumberKeyShortcutsProperty, value);
    }

    private readonly UniformGrid grid = new() { Rows = 1 };
    private readonly List<(SegmentItem Item, ToggleButton Button)> segments = [];
    private bool syncing;

    public ThemedSegmentedControl()
    {
        var track = new Border
        {
            CornerRadius = new CornerRadius(8),
            Padding = new Thickness(2),
            Child = grid,
        };
        track.SetResourceReference(Border.BackgroundProperty, "Brush.FieldFill");
        AddVisualChild(track);
        content = track;
    }

    private readonly Border content;

    protected override int VisualChildrenCount => 1;

    protected override Visual GetVisualChild(int index) => content;

    protected override Size MeasureOverride(Size constraint)
    {
        content.Measure(constraint);
        return content.DesiredSize;
    }

    protected override Size ArrangeOverride(Size arrangeBounds)
    {
        content.Arrange(new Rect(arrangeBounds));
        return arrangeBounds;
    }

    private void Rebuild()
    {
        grid.Children.Clear();
        segments.Clear();
        if (ItemsSource is null) return;

        var index = 0;
        foreach (SegmentItem item in ItemsSource)
        {
            var button = BuildSegment(item, index);
            segments.Add((item, button));
            grid.Children.Add(button);
            index++;
        }
        SyncSelection();
    }

    private ToggleButton BuildSegment(SegmentItem item, int index)
    {
        var label = new TextBlock
        {
            Text = item.Label,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
        };
        label.SetResourceReference(TextBlock.FontSizeProperty, "Font.Button");

        var fill = new Border { CornerRadius = new CornerRadius(6), Child = label, Padding = new Thickness(0, 4, 0, 4) };

        var button = new ToggleButton
        {
            Content = fill,
            Background = Brushes.Transparent,
            BorderThickness = new Thickness(0),
            Cursor = Cursors.Hand,
            Focusable = true,
            Template = TransparentToggleTemplate(),
        };
        button.SetValue(Grid.ColumnProperty, index);
        button.Checked += (_, _) => Select(item);
        button.PreviewMouseLeftButtonDown += (_, e) => { Select(item); e.Handled = true; };

        var tooltip = item.Tooltip ?? item.Label;
        if (NumberKeyShortcuts && index < 9) tooltip += $" (Ctrl+{index + 1})";
        button.ToolTip = tooltip;
        AutomationProperties.SetName(button, item.Label);
        AutomationProperties.SetHelpText(button, item.Tooltip ?? item.Label);

        // Selected/unselected look, driven by IsChecked.
        button.Tag = (fill, label);
        return button;
    }

    private static ControlTemplate TransparentToggleTemplate()
    {
        var template = new ControlTemplate(typeof(ToggleButton));
        var presenter = new FrameworkElementFactory(typeof(ContentPresenter));
        presenter.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Stretch);
        template.VisualTree = presenter;
        return template;
    }

    private void Select(SegmentItem item)
    {
        if (syncing) return;
        SelectedValue = item.Value;
    }

    private void SyncSelection()
    {
        syncing = true;
        foreach (var (item, button) in segments)
        {
            var selected = Equals(item.Value, SelectedValue);
            button.IsChecked = selected;
            if (button.Tag is (Border fill, TextBlock label))
            {
                if (selected)
                {
                    fill.SetResourceReference(Border.BackgroundProperty, "Brush.Accent");
                    label.SetResourceReference(TextBlock.ForegroundProperty, "Brush.Panel");
                    label.FontWeight = FontWeights.SemiBold;
                }
                else
                {
                    fill.Background = Brushes.Transparent;
                    label.SetResourceReference(TextBlock.ForegroundProperty, "Brush.Text");
                    label.FontWeight = FontWeights.Normal;
                }
            }
        }
        syncing = false;
    }
}
