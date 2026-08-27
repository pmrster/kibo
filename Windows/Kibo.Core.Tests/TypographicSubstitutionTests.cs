namespace Kibo.Core.Tests;

/// An operating system rewrites what the user types before the converter ever sees it — macOS
/// curls `'` into `’` as you type, and text pasted from Word or a chat app arrives the same way
/// on Windows. Those keys carry Thai characters: `'` is `ง`, `"` is `.`, and `-` is `ข`. Before
/// the fold, a curled apostrophe survived even the mechanical EN → TH flip, and `ง` was
/// unreachable from the keyboard.
public class TypographicSubstitutionTests
{
    private readonly KeyboardConverter converter = new();

    private string Convert(string input, ConversionMode mode) => converter.Convert(input, mode).Output;

    // MARK: - The reported bug

    [Fact]
    public void Curly_apostrophe_converts_to_ngo_ngu()
    {
        Assert.Equal("ง", Convert("’", ConversionMode.EnglishToThai));
        Assert.Equal("ง", Convert("‘", ConversionMode.EnglishToThai));
    }

    [Fact]
    public void Curly_quotes_and_dashes_reach_their_thai_keys()
    {
        Assert.Equal(".", Convert("“", ConversionMode.EnglishToThai));
        Assert.Equal(".", Convert("”", ConversionMode.EnglishToThai));
        Assert.Equal("ข", Convert("–", ConversionMode.EnglishToThai));
        Assert.Equal("ข", Convert("—", ConversionMode.EnglishToThai));
    }

    /// The point of the fold: a curled apostrophe must convert exactly as the straight one the
    /// user actually pressed, so the substitution becomes invisible.
    [Fact]
    public void Curled_text_converts_identically_to_what_was_typed()
    {
        Assert.Equal(Convert("don't", ConversionMode.EnglishToThai), Convert("don’t", ConversionMode.EnglishToThai));
        Assert.Equal(Convert("l;ylfu'", ConversionMode.EnglishToThai), Convert("l;ylfu’", ConversionMode.EnglishToThai));
    }

    // MARK: - Precision: the fold must not rewrite text it leaves alone

    /// Mixed mode declines to convert `don’t`, and must hand it back byte for byte. Folding the
    /// apostrophe on the way *in* would have quietly straightened the user's punctuation.
    [Fact]
    public void Mixed_mode_returns_untouched_text_with_its_curls_intact()
    {
        foreach (var text in new[] { "don’t", "it’s fine", "“hello”", "well — yes" })
        {
            Assert.Equal(text, Convert(text, ConversionMode.Mixed));
        }
    }

    /// The Thai → English direction always emits the straight ASCII key, because that is the key
    /// the layout actually has. There is no curled `ง`.
    [Fact]
    public void Thai_to_english_still_emits_the_straight_key()
    {
        Assert.Equal("'", Convert("ง", ConversionMode.ThaiToEnglish));
        Assert.Equal("-", Convert("ข", ConversionMode.ThaiToEnglish));
    }
}
