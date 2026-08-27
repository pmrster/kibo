namespace Kibo.Core.Tests;

/// The Swift enum carries these facts implicitly (`CaseIterable`, `RawRepresentable`); C# has to
/// spell them out, so they get tests of their own.
public class ConversionModeTests
{
    /// Declaration order is picker order — most-used first — and sets the Ctrl+1–4 shortcuts.
    [Fact]
    public void All_lists_the_modes_in_picker_order()
    {
        Assert.Equal(
            [ConversionMode.SwapAll, ConversionMode.EnglishToThai, ConversionMode.ThaiToEnglish, ConversionMode.Mixed],
            ConversionModes.All.ToArray());
    }

    /// Spelled `SwapAll` rather than `All[0]`, which would assert nothing: a first launch landing
    /// in the mode that converts *everything* is a product decision.
    [Fact]
    public void Default_is_swap_all()
    {
        Assert.Equal(ConversionMode.SwapAll, ConversionModes.Default);
    }

    [Fact]
    public void Swapped_exchanges_only_the_explicit_directions()
    {
        Assert.Equal(ConversionMode.ThaiToEnglish, ConversionMode.EnglishToThai.Swapped());
        Assert.Equal(ConversionMode.EnglishToThai, ConversionMode.ThaiToEnglish.Swapped());
        Assert.Equal(ConversionMode.Mixed, ConversionMode.Mixed.Swapped());
        Assert.Equal(ConversionMode.SwapAll, ConversionMode.SwapAll.Swapped());
    }

    [Fact]
    public void Has_direction_only_for_the_explicit_directions()
    {
        Assert.True(ConversionMode.EnglishToThai.HasDirection());
        Assert.True(ConversionMode.ThaiToEnglish.HasDirection());
        Assert.False(ConversionMode.Mixed.HasDirection());
        Assert.False(ConversionMode.SwapAll.HasDirection());
    }

    /// The raw values are the mode identifiers in Fixtures/conversion-cases.json and the strings
    /// SettingsStore persists, so they are fixed by contract, not by the C# names.
    [Fact]
    public void Raw_values_match_the_fixture_identifiers()
    {
        Assert.Equal("swapAll", ConversionMode.SwapAll.RawValue());
        Assert.Equal("englishToThai", ConversionMode.EnglishToThai.RawValue());
        Assert.Equal("thaiToEnglish", ConversionMode.ThaiToEnglish.RawValue());
        Assert.Equal("mixed", ConversionMode.Mixed.RawValue());
    }

    [Fact]
    public void Raw_values_round_trip_through_try_parse()
    {
        foreach (var mode in ConversionModes.All)
        {
            Assert.True(ConversionModes.TryParse(mode.RawValue(), out var parsed));
            Assert.Equal(mode, parsed);
        }
    }

    /// `Enum.TryParse` would accept `"3"` and, case-insensitively, `"SwapAll"`. A stored value
    /// written by a newer build must fall back to the default, not land on a mode by accident.
    [Fact]
    public void Try_parse_rejects_anything_but_the_exact_raw_values()
    {
        foreach (var raw in new[] { "3", "SwapAll", "SWAPALL", "", " swapAll", "telepathy" })
        {
            Assert.False(ConversionModes.TryParse(raw, out _), $"parsed '{raw}'");
        }
        Assert.False(ConversionModes.TryParse(null, out _));
    }

    [Fact]
    public void Conversion_result_carries_input_output_and_mode()
    {
        var result = new ConversionResult("l;ylfu", "สวัสดี", ConversionMode.EnglishToThai);
        Assert.Equal("l;ylfu", result.Input);
        Assert.Equal("สวัสดี", result.Output);
        Assert.Equal(ConversionMode.EnglishToThai, result.Mode);
        Assert.Equal(result, new ConversionResult("l;ylfu", "สวัสดี", ConversionMode.EnglishToThai));
    }
}

public class SettingsEnumTests
{
    [Fact]
    public void Appearance_raw_values_round_trip()
    {
        Assert.Equal(["system", "light", "dark"], Appearances.All.ToArray().Select(a => a.RawValue()));
        foreach (var appearance in Appearances.All)
        {
            Assert.True(Appearances.TryParse(appearance.RawValue(), out var parsed));
            Assert.Equal(appearance, parsed);
        }
        Assert.False(Appearances.TryParse("chartreuse", out _));
        Assert.False(Appearances.TryParse("Dark", out _));
    }

    [Fact]
    public void Font_size_raw_values_round_trip()
    {
        Assert.Equal(["small", "medium", "large"], FontSizes.All.ToArray().Select(f => f.RawValue()));
        foreach (var size in FontSizes.All)
        {
            Assert.True(FontSizes.TryParse(size.RawValue(), out var parsed));
            Assert.Equal(size, parsed);
        }
        Assert.False(FontSizes.TryParse("enormous", out _));
    }

    /// `small` is 1.0 so the app is pixel-identical to its designed size; presets only grow.
    [Fact]
    public void Font_size_factors_only_grow()
    {
        Assert.Equal(1.0, FontSize.Small.Factor());
        Assert.True(FontSize.Small.Factor() < FontSize.Medium.Factor());
        Assert.True(FontSize.Medium.Factor() < FontSize.Large.Factor());
    }
}
