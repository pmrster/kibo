namespace Kibo.Core.Tests;

public class SettingsStoreTests
{
    private static (SettingsStore Store, InMemoryKeyValueStore Backing) MakeStore()
    {
        var backing = new InMemoryKeyValueStore();
        return (new SettingsStore(backing), backing);
    }

    [Fact]
    public void Defaults_when_nothing_is_stored()
    {
        var (store, _) = MakeStore();
        Assert.Equal(Appearance.System, store.Appearance);
        Assert.Equal(FontSize.Small, store.FontSize);
        Assert.Equal(ConversionMode.SwapAll, store.LastMode);
        Assert.True(store.ShowBubble);
        Assert.True(store.HotkeyEnabled);
        Assert.Null(store.BubblePosition);
    }

    [Fact]
    public void Values_round_trip()
    {
        var (store, _) = MakeStore();
        store.Appearance = Appearance.Dark;
        store.FontSize = FontSize.Large;
        store.LastMode = ConversionMode.ThaiToEnglish;
        store.ShowBubble = false;
        store.HotkeyEnabled = false;
        store.BubblePosition = (1812.5, 980);

        Assert.Equal(Appearance.Dark, store.Appearance);
        Assert.Equal(FontSize.Large, store.FontSize);
        Assert.Equal(ConversionMode.ThaiToEnglish, store.LastMode);
        Assert.False(store.ShowBubble);
        Assert.False(store.HotkeyEnabled);
        Assert.Equal((1812.5, 980), store.BubblePosition);
    }

    /// The keys are the file format. A user who edits `settings.json` by hand, or a newer build
    /// reading an older file, relies on them not changing.
    [Fact]
    public void Values_are_stored_under_stable_keys_as_raw_strings()
    {
        var (store, backing) = MakeStore();
        store.Appearance = Appearance.Light;
        store.FontSize = FontSize.Medium;
        store.LastMode = ConversionMode.Mixed;
        store.ShowBubble = false;
        store.HotkeyEnabled = true;
        store.BubblePosition = (12, 34.5);

        Assert.Equal("light", backing.Get("appearance"));
        Assert.Equal("medium", backing.Get("fontSize"));
        Assert.Equal("mixed", backing.Get("lastMode"));
        Assert.Equal("false", backing.Get("showBubble"));
        Assert.Equal("true", backing.Get("hotkeyEnabled"));
        Assert.Equal("12", backing.Get("bubbleX"));
        Assert.Equal("34.5", backing.Get("bubbleY"));
    }

    /// A value written by a newer build, or corrupted by hand, must not crash an older one.
    [Fact]
    public void Unrecognised_stored_values_fall_back_to_defaults()
    {
        var (store, backing) = MakeStore();
        backing.Set("appearance", "chartreuse");
        backing.Set("fontSize", "enormous");
        backing.Set("lastMode", "telepathy");
        backing.Set("showBubble", "maybe");
        backing.Set("hotkeyEnabled", "1");
        backing.Set("bubbleX", "far");
        backing.Set("bubbleY", "12");

        Assert.Equal(Appearance.System, store.Appearance);
        Assert.Equal(FontSize.Small, store.FontSize);
        Assert.Equal(ConversionMode.SwapAll, store.LastMode);
        Assert.True(store.ShowBubble);
        Assert.True(store.HotkeyEnabled);
        Assert.Null(store.BubblePosition);
    }

    /// Half a position is no position: the bubble goes to its default rather than to x=0.
    [Fact]
    public void A_bubble_position_needs_both_coordinates()
    {
        var (store, backing) = MakeStore();
        backing.Set("bubbleX", "100");
        Assert.Null(store.BubblePosition);

        store.BubblePosition = null;
        Assert.Null(backing.Get("bubbleX"));
        Assert.Null(backing.Get("bubbleY"));
    }

    /// `double.Parse` follows the current culture, and a German locale would write `1812,5`.
    [Fact]
    public void Bubble_position_is_culture_invariant()
    {
        var (store, backing) = MakeStore();
        backing.Set("bubbleX", "1812,5");
        backing.Set("bubbleY", "980");
        Assert.Null(store.BubblePosition);
    }

    [Fact]
    public void Store_is_the_mode_memory_the_model_uses()
    {
        var (store, _) = MakeStore();
        IModeMemory memory = store;
        Assert.Equal(ConversionMode.SwapAll, memory.LoadMode());
        memory.SaveMode(ConversionMode.Mixed);
        Assert.Equal(ConversionMode.Mixed, store.LastMode);
        Assert.Equal(ConversionMode.Mixed, memory.LoadMode());
    }
}
