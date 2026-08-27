using System.Text;

namespace Kibo.Core.Tests;

/// The fold itself, tested directly. The end-to-end cases — curled text converting exactly as the
/// straight keys the user pressed, Mixed keeping curls in text it leaves alone — live in
/// `TypographicSubstitutionTests`, which needs `KeyboardConverter`.
public class TypographicSubstitutesTests
{
    [Fact]
    public void Six_substitutes_fold_onto_three_keys()
    {
        Assert.Equal(6, TypographicSubstitutes.Pairs.Count);
        Assert.Equal(new Rune('\''), TypographicSubstitutes.AsciiKeyFor(new Rune('‘')));
        Assert.Equal(new Rune('\''), TypographicSubstitutes.AsciiKeyFor(new Rune('’')));
        Assert.Equal(new Rune('"'), TypographicSubstitutes.AsciiKeyFor(new Rune('“')));
        Assert.Equal(new Rune('"'), TypographicSubstitutes.AsciiKeyFor(new Rune('”')));
        Assert.Equal(new Rune('-'), TypographicSubstitutes.AsciiKeyFor(new Rune('–')));
        Assert.Equal(new Rune('-'), TypographicSubstitutes.AsciiKeyFor(new Rune('—')));
    }

    /// Every key the fold lands on is a real QWERTY key, or the fold would produce a scalar the
    /// mapping cannot convert.
    [Fact]
    public void Every_folded_key_is_a_qwerty_key()
    {
        foreach (var pair in TypographicSubstitutes.Pairs)
        {
            Assert.True(KedmaneeMapping.ThaiForQwerty(pair.Key).HasValue, $"'{pair.Key}' is not on the layout");
        }
    }

    /// `…` stands for three `.` presses, so folding it to one would silently drop two.
    [Fact]
    public void Ellipsis_and_ordinary_characters_are_not_substitutes()
    {
        foreach (var text in new[] { "…", "'", "-", "a", " ", "ง" })
        {
            var scalar = Rune.GetRuneAt(text, 0);
            Assert.False(TypographicSubstitutes.Contains(scalar), $"'{text}' should not be a substitute");
            Assert.Null(TypographicSubstitutes.AsciiKeyFor(scalar));
        }
    }

    [Fact]
    public void Contains_agrees_with_ascii_key_for()
    {
        foreach (var pair in TypographicSubstitutes.Pairs)
        {
            Assert.True(TypographicSubstitutes.Contains(pair.Substitute));
        }
    }
}
