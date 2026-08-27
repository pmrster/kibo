using System.Windows.Threading;
using Kibo.App.Theme;

namespace Kibo.App.Controls;

/// <summary>
/// Draws the mascot. The port of <c>KiboView.swift</c>.
/// </summary>
/// <remarks>
/// <b>Never scale-transformed.</b> A scale would stretch the rasterised rectangles and the sprite
/// would come out jagged — the exact failure <c>CLAUDE.md</c> warns about. Instead it draws at
/// whole device pixels: <c>PixelSize</c> is multiplied by the DPI scale, rounded to an integer
/// number of device pixels, and every rectangle lands on a whole pixel with anti-aliasing off.
/// The eyes are holes — those cells are simply not drawn, and the surface behind shows through.
/// </remarks>
internal sealed class KiboSpriteControl : FrameworkElement
{
    public enum MoodKind
    {
        Idle,
        Pleased,
    }

    public static readonly DependencyProperty PixelSizeProperty = DependencyProperty.Register(
        nameof(PixelSize), typeof(int), typeof(KiboSpriteControl),
        new FrameworkPropertyMetadata(2, FrameworkPropertyMetadataOptions.AffectsMeasure | FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty MoodProperty = DependencyProperty.Register(
        nameof(Mood), typeof(MoodKind), typeof(KiboSpriteControl),
        new FrameworkPropertyMetadata(MoodKind.Idle, FrameworkPropertyMetadataOptions.AffectsRender));

    public int PixelSize
    {
        get => (int)GetValue(PixelSizeProperty);
        set => SetValue(PixelSizeProperty, value);
    }

    public MoodKind Mood
    {
        get => (MoodKind)GetValue(MoodProperty);
        set => SetValue(MoodProperty, value);
    }

    private readonly DispatcherTimer timer;
    private double phase;

    public KiboSpriteControl()
    {
        RenderOptions.SetEdgeMode(this, EdgeMode.Aliased);
        SnapsToDevicePixels = true;
        UseLayoutRounding = true;
        // The animation clock, at the same 0.4 s period as the SwiftUI TimelineView.
        timer = new DispatcherTimer(DispatcherPriority.Render) { Interval = TimeSpan.FromSeconds(0.4) };
        timer.Tick += (_, _) => { phase += 0.4; InvalidateVisual(); };
        IsVisibleChanged += (_, _) =>
        {
            if (IsVisible) timer.Start();
            else timer.Stop();
        };
    }

    /// <summary>The cell size in DIP that renders as a whole number of device pixels.</summary>
    private double CellDip(out double bob)
    {
        var scale = VisualTreeHelper.GetDpi(this).DpiScaleX;
        var devicePixels = Math.Max(1, (int)Math.Round(PixelSize * scale));
        var cell = devicePixels / scale;
        // A one-pixel bob with a 3.2 s period, 50% duty — the float from KiboView.
        bob = phase % 3.2 >= 1.6 ? -cell : 0;
        return cell;
    }

    protected override Size MeasureOverride(Size availableSize)
    {
        var cell = CellDip(out _);
        return new Size(KiboSprite.Columns * cell, KiboSprite.Rows * cell);
    }

    protected override void OnRender(DrawingContext dc)
    {
        var cell = CellDip(out var bob);
        var brush = (Brush)FindResource("Brush.Kibo");

        var eyes = Mood == MoodKind.Pleased || IsBlinking()
            ? KiboSprite.Eyes.Shut
            : KiboSprite.Eyes.Open;
        var rows = KiboSprite.RowsFor(eyes);

        for (var y = 0; y < rows.Count; y++)
        {
            var row = rows[y];
            var x = 0;
            while (x < row.Length)
            {
                if (row[x] != 'Y') { x++; continue; }
                // Coalesce a run of body cells into one rectangle so there are no seams.
                var start = x;
                while (x < row.Length && row[x] == 'Y') x++;
                dc.DrawRectangle(brush, null, new Rect(start * cell, y * cell + bob, (x - start) * cell, cell));
            }
        }
    }

    /// <summary>Idle: a 0.4 s blink every 4 s.</summary>
    private bool IsBlinking() => Mood == MoodKind.Idle && phase % 4.0 < 0.4;
}
