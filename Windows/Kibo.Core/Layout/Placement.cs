namespace Kibo.Core;

/// <summary>A point in device pixels.</summary>
public readonly record struct PointPx(int X, int Y);

/// <summary>A size in device pixels.</summary>
public readonly record struct SizePx(int W, int H);

/// <summary>A rectangle in device pixels.</summary>
public readonly record struct RectPx(int X, int Y, int W, int H)
{
    public int Right => X + W;
    public int Bottom => Y + H;

    public bool Intersects(RectPx other) =>
        X < other.Right && other.X < Right && Y < other.Bottom && other.Y < Bottom;
}

/// <summary>
/// Window placement maths, in integer device pixels and free of WPF types so it is tested here
/// rather than by eye in a VM. The shell converts to and from WPF units around it.
/// </summary>
public static class Placement
{
    /// <summary>Keeps a window off the very edge of the work area.</summary>
    private const int Inset = 8;

    /// <summary>
    /// Where a flyout goes for an anchor point (the tray icon under the cursor, or the top of the
    /// bubble): centred on it horizontally, its bottom edge <paramref name="gap"/> pixels above it.
    /// When that would leave the top of the work area — a taskbar along the top of the screen —
    /// it opens below the anchor instead. Either way it is then clamped inside the work area.
    /// </summary>
    public static RectPx AnchorAbove(PointPx anchor, SizePx size, RectPx workArea, int gap)
    {
        var x = anchor.X - size.W / 2;
        var y = anchor.Y - gap - size.H;
        if (y < workArea.Y + Inset)
        {
            y = anchor.Y + gap;
        }
        x = Math.Clamp(x, workArea.X + Inset, Math.Max(workArea.X + Inset, workArea.Right - Inset - size.W));
        y = Math.Clamp(y, workArea.Y + Inset, Math.Max(workArea.Y + Inset, workArea.Bottom - Inset - size.H));
        return new RectPx(x, y, size.W, size.H);
    }

    /// <summary>
    /// A saved window position, if it still lands on a screen. <c>null</c> when it intersects no
    /// work area — a monitor was unplugged, or the file was edited — so the caller falls back to
    /// its default spot instead of showing the window somewhere nobody can see.
    /// </summary>
    public static PointPx? ClampToScreens(PointPx saved, SizePx size, IReadOnlyList<RectPx> workAreas)
    {
        var rect = new RectPx(saved.X, saved.Y, size.W, size.H);
        foreach (var area in workAreas)
        {
            if (rect.Intersects(area)) return saved;
        }
        return null;
    }
}
