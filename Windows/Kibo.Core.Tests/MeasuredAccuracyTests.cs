namespace Kibo.Core.Tests;

/// The accuracy table in CLAUDE.md, asserted — for the port, against the same corpus.
///
/// It measures **end to end through `KeyboardConverter` in Mixed mode**, which is what the user
/// actually experiences: a gate verdict is not a promise about the output. If you change
/// `RunJudge`, expect to change the numbers here. Do not raise recall without reading what
/// `Precision_correct_text_is_returned_completely_unchanged` then says.
public class MeasuredAccuracyTests
{
    private readonly KeyboardConverter converter = new();

    private string Mixed(string text) => converter.Convert(text, ConversionMode.Mixed).Output;

    // MARK: - Precision — 36 of 36

    /// The headline promise: correct text is never touched. Asserted per string *and* by count —
    /// without the count, deleting an awkward entry would quietly lower the bar.
    [Fact]
    public void Precision_correct_text_is_returned_completely_unchanged()
    {
        Assert.True(AccuracyCorpus.MustSurvive.Length == 36,
            "The precision corpus changed size. CLAUDE.md, SPEC.md and README.md all quote '36 of 36' — update them, and Fixtures/conversion-cases.json too.");
        foreach (var text in AccuracyCorpus.MustSurvive)
        {
            Assert.True(text == Mixed(text), $"Mixed mangled correct text: '{text}'");
        }
    }

    // MARK: - Recall, English mistyped on the Thai layout — 19 of 30

    [Fact]
    public void Recall_english_corpus_is_the_size_the_docs_claim()
    {
        var total = AccuracyCorpus.EnglishCaught.Length + AccuracyCorpus.EnglishMissed.Length;
        Assert.Equal(19, AccuracyCorpus.EnglishCaught.Length);
        Assert.True(total == 30, "The docs quote '19 of 30'. Update them with the corpus.");
    }

    [Fact]
    public void Recall_english_mistypings_are_fixed()
    {
        foreach (var word in AccuracyCorpus.EnglishCaught)
        {
            var wreckage = AccuracyCorpus.MistypedOnThaiLayout(word);
            Assert.True(word == Mixed(wreckage), $"'{word}' mistypes to '{wreckage}', which Mixed no longer recovers");
        }
    }

    /// The misses, asserted so the rate stays visible. A failure here is good news — move the
    /// word into `EnglishCaught`, bump the count above, and check precision still passes.
    [Fact]
    public void Known_limitation_english_misses_are_left_alone()
    {
        foreach (var word in AccuracyCorpus.EnglishMissed)
        {
            var wreckage = AccuracyCorpus.MistypedOnThaiLayout(word);
            Assert.True(wreckage == Mixed(wreckage), $"'{word}' → '{wreckage}' is now recovered; move it to EnglishCaught");
        }
    }

    // MARK: - Recall, Thai mistyped on the US layout — 4 of 12

    [Fact]
    public void Recall_thai_corpus_is_the_size_the_docs_claim()
    {
        var total = AccuracyCorpus.ThaiCaught.Length + AccuracyCorpus.ThaiMissed.Length;
        Assert.Equal(4, AccuracyCorpus.ThaiCaught.Length);
        Assert.True(total == 12, "The docs quote '4 of 12'. Update them with the corpus.");
    }

    [Fact]
    public void Recall_thai_mistypings_are_fixed()
    {
        foreach (var word in AccuracyCorpus.ThaiCaught)
        {
            var wreckage = AccuracyCorpus.MistypedOnUSLayout(word);
            Assert.True(word == Mixed(wreckage), $"'{word}' mistypes to '{wreckage}', which Mixed no longer recovers");
        }
    }

    [Fact]
    public void Known_limitation_thai_misses_are_left_alone()
    {
        foreach (var word in AccuracyCorpus.ThaiMissed)
        {
            var wreckage = AccuracyCorpus.MistypedOnUSLayout(word);
            Assert.True(wreckage == Mixed(wreckage), $"'{word}' → '{wreckage}' is now recovered; move it to ThaiCaught");
        }
    }
}
