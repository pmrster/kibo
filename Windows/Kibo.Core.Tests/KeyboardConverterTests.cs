using System.Diagnostics;
using System.Text;

namespace Kibo.Core.Tests;

public class KeyboardConverterTests
{
    private readonly KeyboardConverter converter = new();

    private string Convert(string input, ConversionMode mode) => converter.Convert(input, mode).Output;

    // MARK: - The documented examples

    /// Every worked example in SPEC.md, which is the contract the app promises on its own tin.
    [Fact]
    public void Spec_examples()
    {
        Assert.Equal("อยากกินกาแฟ", Convert("vpkddbodkca", ConversionMode.EnglishToThai));
        Assert.Equal("thank", Convert("ะ้ฟืา", ConversionMode.ThaiToEnglish));
        Assert.Equal("สวัสดี", Convert("l;ylfu", ConversionMode.EnglishToThai));
        Assert.Equal("hello", Convert("้ำสสน", ConversionMode.ThaiToEnglish));
    }

    /// The behaviour the whole Mixed design exists for: wreckage is fixed, correct text is not,
    /// and everything that is neither is left exactly where it was.
    [Fact]
    public void Mixed_worked_example()
    {
        Assert.Equal("สวัสดี hello ครับ 2024 :)", Convert("l;ylfu ้ำสสน ครับ 2024 :)", ConversionMode.Mixed));
    }

    // MARK: - Result shape

    [Fact]
    public void Result_carries_its_question()
    {
        var result = converter.Convert("l;ylfu", ConversionMode.EnglishToThai);
        Assert.Equal("l;ylfu", result.Input);
        Assert.Equal("สวัสดี", result.Output);
        Assert.Equal(ConversionMode.EnglishToThai, result.Mode);
    }

    [Fact]
    public void Empty_input_converts_to_empty_output_in_every_mode()
    {
        foreach (var mode in ConversionModes.All)
        {
            Assert.True(Convert("", mode) == "", mode.ToString());
        }
    }

    // MARK: - Preservation

    /// AGENTS.md is explicit that unmapped characters are never normalised or dropped. Whitespace
    /// and line structure carry meaning in pasted text, and losing them would be worse than a
    /// wrong conversion because it is invisible.
    [Fact]
    public void Unmapped_characters_are_preserved_exactly()
    {
        foreach (var mode in new[] { ConversionMode.EnglishToThai, ConversionMode.ThaiToEnglish })
        {
            Assert.Equal(" ", Convert(" ", mode));
            Assert.Equal("\n\n", Convert("\n\n", mode));
            Assert.Equal("\t", Convert("\t", mode));
            Assert.Equal("🐈🇹🇭", Convert("🐈🇹🇭", mode));
            Assert.Equal("日本", Convert("日本", mode));
            Assert.EndsWith("é", Convert("café", mode), StringComparison.Ordinal);
        }
    }

    [Fact]
    public void Multiline_input_keeps_its_line_structure()
    {
        Assert.Equal("สวัสดี\nสวัสดี\n\nสวัสดี", Convert("l;ylfu\nl;ylfu\n\nl;ylfu", ConversionMode.EnglishToThai));
    }

    [Fact]
    public void Mixed_preserves_emoji_and_newlines_between_runs()
    {
        Assert.Equal("สวัสดี\n🐈 ครับ", Convert("l;ylfu\n🐈 ครับ", ConversionMode.Mixed));
    }

    /// Swift repairs invalid UTF-8 into U+FFFD when a String is made; `EnumerateRunes` does the
    /// same for a lone surrogate. Pinned so the behaviour is recorded rather than discovered.
    [Fact]
    public void Lone_surrogates_become_U_FFFD_rather_than_crashing()
    {
        var output = Convert("a\uD800b", ConversionMode.EnglishToThai);
        Assert.Contains("�", output, StringComparison.Ordinal);
        Assert.Equal(3, output.EnumerateRunes().Count());
    }

    // MARK: - Direction

    /// The two explicit modes are exact inverses, because the mapping table is a bijection.
    [Fact]
    public void Explicit_modes_round_trip()
    {
        foreach (var sample in new[] { "l;ylfu", "vpkddbodkca", "Hello, World!", "a;sldkfj 123 [];'" })
        {
            var thai = Convert(sample, ConversionMode.EnglishToThai);
            Assert.True(sample == Convert(thai, ConversionMode.ThaiToEnglish), $"round trip of '{sample}'");
        }
    }

    /// Explicit modes are mechanical — they do not consult the orthography gate.
    [Fact]
    public void Explicit_modes_convert_even_well_formed_text()
    {
        Assert.Equal("8iy[", Convert("ครับ", ConversionMode.ThaiToEnglish));
        Assert.NotEqual("hello", Convert("hello", ConversionMode.EnglishToThai));
    }

    /// Text in the wrong script for the mode passes through: there is nothing to map.
    [Fact]
    public void Explicit_modes_ignore_text_from_the_other_script()
    {
        Assert.Equal("สวัสดี", Convert("สวัสดี", ConversionMode.EnglishToThai));
        Assert.Equal("hello", Convert("hello", ConversionMode.ThaiToEnglish));
    }

    // MARK: - Mixed specifics

    [Fact]
    public void Mixed_leaves_correct_text_of_both_scripts_alone()
    {
        Assert.Equal("ครับ hello", Convert("ครับ hello", ConversionMode.Mixed));
    }

    [Fact]
    public void Mixed_converts_each_run_in_its_own_direction()
    {
        Assert.Equal("สวัสดี hello", Convert("l;ylfu ้ำสสน", ConversionMode.Mixed));
    }

    /// A Thai run that arrives with almost no letters after mistyping — `ขอบคุณ` — still gets
    /// fixed, via the letter-poor path in `RunJudge`.
    [Fact]
    public void Mixed_fixes_letter_poor_thai_wreckage()
    {
        Assert.Equal("ขอบคุณ", Convert("-v[86I", ConversionMode.Mixed));
    }

    /// End-to-end precision. The count guard lives in `MeasuredAccuracyTests`.
    [Fact]
    public void Mixed_returns_correct_text_completely_unchanged()
    {
        foreach (var text in AccuracyCorpus.MustSurvive)
        {
            Assert.True(text == Convert(text, ConversionMode.Mixed), $"Mixed mangled correct text: '{text}'");
        }
    }

    // MARK: - Both directions at once

    /// One sentence mistyped in *both* directions, because the layout was switched partway
    /// through. Neither explicit mode can fix it, and Mixed will not.
    [Fact]
    public void Swap_all_fixes_a_sentence_mistyped_in_both_directions()
    {
        // `vtwiot` is อะไรนะ on the US layout; `เพฟิ` is "grab" on the Thai one.
        var input = "vtwiot เพฟิ sinv0twxi5g,]N";
        Assert.Equal("อะไรนะ grab หรือจะไปรถเมล์", Convert(input, ConversionMode.SwapAll));
    }

    [Fact]
    public void Swap_all_sends_each_run_the_way_its_script_implies()
    {
        Assert.Equal("สวัสดี", Convert("l;ylfu", ConversionMode.SwapAll));
        Assert.Equal("l;ylfu", Convert("สวัสดี", ConversionMode.SwapAll));
        Assert.Equal("สวัสดี l;ylfu", Convert("l;ylfu สวัสดี", ConversionMode.SwapAll));
    }

    /// It is mechanical, so it converts correct text too.
    [Fact]
    public void Swap_all_does_not_spare_correct_text()
    {
        Assert.Equal("8iy[", Convert("ครับ", ConversionMode.SwapAll));
        Assert.Equal("ครับ", Convert("ครับ", ConversionMode.Mixed));
    }

    /// Neutral runs are on no layout, so there is no direction to send them in.
    [Fact]
    public void Swap_all_passes_through_what_is_on_no_layout()
    {
        Assert.Equal("  \n\t", Convert("  \n\t", ConversionMode.SwapAll));
        Assert.Equal("🐈 é", Convert("🐈 é", ConversionMode.SwapAll));
    }

    // MARK: - Scale

    /// PLAN.md asks for conversion to stay visually immediate at 100,000 characters, since the
    /// output is recomputed on every keystroke.
    [Fact]
    public void Converts_one_hundred_thousand_characters_quickly()
    {
        var input = string.Concat(Enumerable.Repeat("l;ylfu ้ำสสน ครับ 2024 :) ", 5_000));
        Assert.True(input.EnumerateRunes().Count() > 100_000);

        var stopwatch = Stopwatch.StartNew();
        var output = Convert(input, ConversionMode.Mixed);
        stopwatch.Stop();

        Assert.NotEmpty(output);
        Assert.True(stopwatch.Elapsed.TotalSeconds < 1.0, $"mixed conversion of 100k characters took {stopwatch.Elapsed.TotalSeconds}s");
    }
}
