namespace Kibo.Core.Tests;

/// Window placement maths in integer device pixels, kept in Core so it is tested here rather
/// than by eye in a VM. The shell converts to and from WPF units around it.
public class PlacementTests
{
    // A 1920×1080 primary screen with a 48 px taskbar at the bottom.
    private static readonly RectPx WorkArea = new(0, 0, 1920, 1032);
    private static readonly SizePx Flyout = new(360, 340);

    [Fact]
    public void Anchors_above_the_point_centred_on_it_when_there_is_room()
    {
        var rect = Placement.AnchorAbove(new PointPx(1700, 1030), Flyout, WorkArea, gap: 8);
        Assert.Equal(new RectPx(1700 - 180, 1030 - 8 - 340, 360, 340), rect);
    }

    /// A taskbar at the top of the screen puts the anchor near y=0; the flyout must open below.
    [Fact]
    public void Flips_below_the_point_when_there_is_no_room_above()
    {
        var topWorkArea = new RectPx(0, 48, 1920, 1032);
        var rect = Placement.AnchorAbove(new PointPx(1700, 40), Flyout, topWorkArea, gap: 8);
        Assert.Equal(48 + 8, rect.Y);
        Assert.Equal(1700 - 180, rect.X);
    }

    [Fact]
    public void Clamps_inside_the_work_area_at_the_right_edge()
    {
        var rect = Placement.AnchorAbove(new PointPx(1910, 1030), Flyout, WorkArea, gap: 8);
        Assert.Equal(1920 - 8 - 360, rect.X);
        Assert.Equal(360, rect.W);
    }

    [Fact]
    public void Clamps_inside_the_work_area_at_the_left_edge()
    {
        var rect = Placement.AnchorAbove(new PointPx(10, 1030), Flyout, WorkArea, gap: 8);
        Assert.Equal(8, rect.X);
    }

    /// A vertical taskbar on the left: the anchor is at x≈30, well inside the work area's
    /// vertical range, so the flyout sits above the cursor and is pushed right of the inset.
    [Fact]
    public void Respects_the_vertical_inset_when_flipped_near_the_bottom()
    {
        var rect = Placement.AnchorAbove(new PointPx(960, 1031), Flyout, WorkArea, gap: 8);
        Assert.True(rect.Y + rect.H <= WorkArea.Y + WorkArea.H - 8);
        Assert.True(rect.Y >= WorkArea.Y + 8);
    }

    [Fact]
    public void A_saved_point_inside_a_screen_is_kept()
    {
        var screens = new[] { WorkArea, new RectPx(1920, 0, 2560, 1400) };
        Assert.Equal(new PointPx(100, 100), Placement.ClampToScreens(new PointPx(100, 100), new SizePx(56, 56), screens));
        Assert.Equal(new PointPx(3000, 500), Placement.ClampToScreens(new PointPx(3000, 500), new SizePx(56, 56), screens));
    }

    /// A monitor that was unplugged since last launch leaves the saved point on no screen.
    [Fact]
    public void A_saved_point_on_no_screen_is_rejected()
    {
        var screens = new[] { WorkArea };
        Assert.Null(Placement.ClampToScreens(new PointPx(3000, 500), new SizePx(56, 56), screens));
        Assert.Null(Placement.ClampToScreens(new PointPx(-500, -500), new SizePx(56, 56), screens));
        Assert.Null(Placement.ClampToScreens(new PointPx(99999, 99999), new SizePx(56, 56), screens));
    }

    /// Partly off-screen still counts as on it, so a bubble nudged against an edge is not reset.
    [Fact]
    public void A_partly_visible_point_is_kept()
    {
        Assert.Equal(new PointPx(1900, 1000), Placement.ClampToScreens(new PointPx(1900, 1000), new SizePx(56, 56), [WorkArea]));
    }
}
