namespace Kibo.Core.Tests;

/// The per-run convert-or-keep decision that makes Mixed mode different from the explicit modes.
public class RunJudgeTests
{
    private static bool Judge(Script script, string text) => RunJudge.ShouldConvert(new Run(script, text));

    [Fact]
    public void Neutral_runs_are_never_converted()
    {
        Assert.False(Judge(Script.Neutral, " "));
        Assert.False(Judge(Script.Neutral, "\n\t"));
        Assert.False(Judge(Script.Neutral, "🐈"));
        Assert.False(Judge(Script.Neutral, "日本"));
    }

    [Fact]
    public void Malformed_thai_is_converted_and_real_thai_is_not()
    {
        Assert.True(Judge(Script.Thai, "ไำะ"));
        Assert.False(Judge(Script.Thai, "ครับ"));
        Assert.False(Judge(Script.Thai, "สวัสดี"));
    }

    [Fact]
    public void Malformed_latin_is_converted_and_real_english_is_not()
    {
        Assert.True(Judge(Script.Latin, "l;ylfu"));
        Assert.True(Judge(Script.Latin, "vpkddbodkca"));
        Assert.False(Judge(Script.Latin, "hello"));
        Assert.False(Judge(Script.Latin, "wet"));
    }

    // MARK: - The letter-poor path

    /// Thai consonants sit on digit and punctuation keys, so a mistyped Thai word can arrive with
    /// almost no letters in it. `LatinOrthography` abstains on those; this is the test that
    /// catches them, by asking whether the run turns into convincing Thai.
    [Fact]
    public void Letter_poor_runs_that_convert_into_convincing_thai_are_converted()
    {
        // ขอบคุณ mistyped on the US layout — two letters, and it must still be caught.
        Assert.True(Judge(Script.Latin, "-v[86I"));
    }

    /// The guards that keep the letter-poor path from eating ordinary text.
    [Fact]
    public void Letter_poor_runs_that_are_not_thai_in_disguise_are_kept()
    {
        Assert.False(Judge(Script.Latin, "2024"), "converts to half-ASCII, so it is a number");
        Assert.False(Judge(Script.Latin, ":)"), "too short to carry evidence");
        Assert.False(Judge(Script.Latin, "!!!"), "converts to ASCII, not Thai");
        Assert.False(Judge(Script.Latin, "..."), "too short to carry evidence");
        Assert.False(Judge(Script.Latin, "a/b"), "too short to carry evidence");
        Assert.False(Judge(Script.Latin, "100%"), "converts to malformed Thai");
        Assert.False(Judge(Script.Latin, "3.14"));
        Assert.False(Judge(Script.Latin, "42"));
        Assert.False(Judge(Script.Latin, "PM"));
        Assert.False(Judge(Script.Latin, "ok"));
    }

    /// The letter-poor test must never be applied to runs that have enough letters to judge on
    /// English shape — `rhythm` converts to well-formed Thai and is emphatically not a mistyping.
    [Fact]
    public void English_words_never_reach_the_letter_poor_path()
    {
        Assert.False(Judge(Script.Latin, "rhythm"));
        Assert.False(Judge(Script.Latin, "world"));
        Assert.False(Judge(Script.Latin, "don't"));
        Assert.False(Judge(Script.Latin, "http://example.com"));
        Assert.False(Judge(Script.Latin, "https://example.com"));
        Assert.False(Judge(Script.Latin, "README.md"));
        Assert.False(Judge(Script.Latin, "index.html"));
    }

    /// The disguise test maps with the *unfolded* table: a curled quote inside a letter-poor run
    /// is on no key and aborts the test, exactly as in Swift.
    [Fact]
    public void A_substitute_inside_a_letter_poor_run_aborts_the_disguise_test()
    {
        Assert.False(Judge(Script.Latin, "-v[8’I"));
    }
}
