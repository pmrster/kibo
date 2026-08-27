namespace Kibo.Core.Tests;

/// The mirror of `ThaiOrthography`: does this ASCII run read as English, or as Thai typed with
/// the US layout on?
public class LatinOrthographyTests
{
    private static void AssertWellFormed(params string[] inputs)
    {
        foreach (var input in inputs)
        {
            Assert.True(LatinOrthography.IsWellFormed(input), $"'{input}' should read as well-formed");
        }
    }

    private static void AssertMalformed(params string[] inputs)
    {
        foreach (var input in inputs)
        {
            Assert.False(LatinOrthography.IsWellFormed(input), $"'{input}' should read as malformed");
        }
    }

    // MARK: - Real English stays put

    [Fact]
    public void English_words_are_well_formed()
    {
        AssertWellFormed("hello", "world", "wet", "email", "meeting", "thank", "rhythm", "don't");
    }

    /// The reason `2024` and `:)` survive Mixed mode: with no letters there is nothing to judge.
    [Fact]
    public void Runs_without_letters_are_well_formed()
    {
        AssertWellFormed("2024", ":)", "!!!", "...", "42", "-", "3.14", "100%");
    }

    /// Two letters is not enough evidence to call something mistyped.
    [Fact]
    public void Short_runs_are_left_alone()
    {
        AssertWellFormed("PM", "TV", "ok", "a", "I", "hi", "");
    }

    // MARK: - Wreckage gets converted

    /// `;` never sits inside an English word, but it is the `ว` key.
    [Fact]
    public void Semicolon_between_letters_is_malformed()
    {
        AssertMalformed("l;ylfu", "ab;cd");
    }

    /// A pile of consonants with no vowel to break it up is not an English word.
    [Fact]
    public void Long_consonant_clusters_are_malformed()
    {
        AssertMalformed("vpkddbodkca", "bcdfghj", "bcdfghjk");
    }

    [Fact]
    public void Long_words_with_no_vowel_at_all_are_malformed()
    {
        AssertMalformed("bcdfgh", "kkkkkk");
    }

    /// Thai words whose mistyping is caught on English shape alone.
    [Fact]
    public void Thai_words_whose_mistyping_is_caught_on_shape()
    {
        foreach (var word in new[] { "สวัสดี", "อยากกินกาแฟ" })
        {
            var mistyped = AccuracyCorpus.MistypedOnUSLayout(word);
            Assert.False(LatinOrthography.IsWellFormed(mistyped), $"'{word}' mistypes to '{mistyped}', which the gate thinks is fine");
        }
    }

    /// Known limitations: `ขอบคุณ` → `-v[86I` has two letters (RunJudge's letter-poor path catches
    /// it instead); `โรงเรียน` → `Fi'giupo` is genuinely English-shaped and nothing catches it.
    [Fact]
    public void Known_limitation_some_mistypings_are_english_shaped()
    {
        AssertWellFormed(AccuracyCorpus.MistypedOnUSLayout("ขอบคุณ"));    // -v[86I
        AssertWellFormed(AccuracyCorpus.MistypedOnUSLayout("โรงเรียน"));  // Fi'giupo
    }

    /// `IsWellFormed` returning true is overloaded: "reads as English" or "too few letters to
    /// judge". This is how `RunJudge` tells the two apart.
    [Fact]
    public void Has_too_few_letters_to_judge_below_three_letters()
    {
        Assert.True(LatinOrthography.HasTooFewLettersToJudge("-v[86I"));
        Assert.True(LatinOrthography.HasTooFewLettersToJudge("2024"));
        Assert.True(LatinOrthography.HasTooFewLettersToJudge(""));
        Assert.False(LatinOrthography.HasTooFewLettersToJudge("abc"));
        Assert.False(LatinOrthography.HasTooFewLettersToJudge("rhythm"));
    }

    // MARK: - Things that must not be mangled

    /// The letters-only projection joins across punctuation, so a path or URL could invent a
    /// consonant cluster that was never really there.
    [Fact]
    public void Urls_and_filenames_survive()
    {
        AssertWellFormed("http://example.com", "https://example.com", "README.md",
                         "index.html", "user@example.com", "v1.2.3");
    }

    /// Regression: every one of these was converted into Thai by an earlier, more aggressive
    /// version of this gate.
    [Fact]
    public void Regression_correct_text_that_was_previously_mangled()
    {
        AssertWellFormed(
            "HTML", "XML", "SQL", "PDF", "SMS",   // all-caps acronyms, no vowels
            "npm", "nth",                          // short and vowel-less, but real
            "https://example.com",                 // `https` is a five-consonant run
            "array[i]", "C:\\Users\\alice",        // brackets and backslashes are code, not Thai
            "let x = 1;", "foo(bar)");
    }
}
