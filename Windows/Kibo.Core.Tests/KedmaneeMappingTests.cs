using System.Globalization;
using System.Text;

namespace Kibo.Core.Tests;

/// The mapping table is the one piece of this app that cannot be reasoned about — it is data, and
/// on macOS it is *dumped* rather than transcribed (`Tools/dump-kedmanee.swift`). The C# table is
/// a transcription of that dump, and `FixtureConformanceTests` holds it to the JSON the dump
/// produced. These tests pin the shape the table must have. Regenerate; never hand-edit.
public class KedmaneeMappingTests
{
    // MARK: - Structure

    [Fact]
    public void Every_printable_ascii_key_is_mapped()
    {
        // Kedmanee assigns a character to all 94 printable ASCII keys; a gap means a dropped row.
        for (var code = 0x21; code <= 0x7E; code++)
        {
            var key = new Rune(code);
            Assert.True(KedmaneeMapping.ThaiForQwerty(key).HasValue, $"QWERTY key '{key}' has no Kedmanee character");
        }
        Assert.Equal(94, KedmaneeMapping.Pairs.Count);
    }

    [Fact]
    public void Mapping_is_a_bijection()
    {
        // `ThaiForQwerty` is inverted to build `QwertyForThai`. That inversion is only sound if
        // no two QWERTY keys land on the same Kedmanee character.
        var outputs = KedmaneeMapping.Pairs.Select(p => p.Kedmanee).ToList();
        Assert.True(outputs.ToHashSet().Count == outputs.Count, "two QWERTY keys produce the same character");

        var inputs = KedmaneeMapping.Pairs.Select(p => p.Qwerty).ToList();
        Assert.True(inputs.ToHashSet().Count == inputs.Count, "a QWERTY key appears twice in the table");
    }

    [Fact]
    public void Round_trips_in_both_directions()
    {
        foreach (var pair in KedmaneeMapping.Pairs)
        {
            Assert.Equal(pair.Kedmanee, KedmaneeMapping.ThaiForQwerty(pair.Qwerty));
            Assert.Equal(pair.Qwerty, KedmaneeMapping.QwertyForThai(pair.Kedmanee));
        }
    }

    /// Documents why the table and the converter both speak `Rune` rather than `char` or text
    /// elements: Thai combining marks fuse with the consonant before them, so Thai text has
    /// strictly fewer grapheme clusters than scalars — and an emoji is *two* UTF-16 chars but one
    /// scalar. A char-based loop cuts surrogate pairs; a text-element loop is handed clusters that
    /// appear in no table. Both would pass text through unconverted.
    [Fact]
    public void Thai_combining_marks_fuse_into_fewer_text_elements()
    {
        Assert.Equal(6, "สวัสดี".EnumerateRunes().Count());
        Assert.Equal(4, new StringInfo("สวัสดี").LengthInTextElements);
        Assert.Equal(2, "🐈".Length);
        Assert.Single("🐈".EnumerateRunes());
    }

    // MARK: - Spot checks against the macOS dump

    /// The unshifted home row — the keys behind the `สวัสดี` example in SPEC.md.
    [Fact]
    public void Unshifted_home_row()
    {
        AssertMaps([
            ('a', 'ฟ'), ('s', 'ห'), ('d', 'ก'), ('f', 'ด'), ('g', 'เ'),
            ('h', '\u0E49'), ('j', '\u0E48'),
            ('k', 'า'), ('l', 'ส'), (';', 'ว'), ('\'', 'ง'),
        ]);
    }

    [Fact]
    public void Shifted_home_row()
    {
        AssertMaps([
            ('A', 'ฤ'), ('S', 'ฆ'), ('D', 'ฏ'), ('F', 'โ'), ('G', 'ฌ'),
            ('H', '\u0E47'), ('J', '\u0E4B'),
            ('K', 'ษ'), ('L', 'ศ'), (':', 'ซ'), ('"', '.'),
        ]);
    }

    /// The digit row is where hand-transcribed tables usually go wrong: `3` produces `_`
    /// (an underscore, not a hyphen) and the backtick produces `-`.
    [Fact]
    public void Digit_row_and_backtick()
    {
        AssertMaps([
            ('1', 'ๅ'), ('2', '/'), ('3', '_'), ('4', 'ภ'), ('5', 'ถ'),
            ('6', '\u0E38'), ('7', '\u0E36'),
            ('8', 'ค'), ('9', 'ต'), ('0', 'จ'), ('-', 'ข'), ('=', 'ช'), ('`', '-'),
        ]);
    }

    /// Shifted digits carry the Thai numerals ๐–๙ plus the baht sign.
    [Fact]
    public void Shifted_digits_are_thai_numerals()
    {
        AssertMaps([
            ('Q', '๐'), ('@', '๑'), ('#', '๒'), ('$', '๓'), ('%', '๔'),
            ('*', '๕'), ('(', '๖'), (')', '๗'), ('_', '๘'), ('+', '๙'), ('&', '฿'),
        ]);
    }

    /// Several Kedmanee keys produce ASCII, so the Thai side of the table is not all Thai script.
    /// The converter must map these too, or TH → EN silently drops characters.
    [Fact]
    public void Kedmanee_keys_that_produce_ascii()
    {
        AssertMaps([
            ('2', '/'), ('3', '_'), ('`', '-'), ('!', '+'), ('~', '%'),
            ('Z', '('), ('X', ')'), ('W', '"'), ('}', ','), ('"', '.'), ('M', '?'),
        ]);
    }

    [Fact]
    public void Backslash_and_pipe_carry_the_rare_consonants()
    {
        AssertMaps([('\\', 'ฃ'), ('|', 'ฅ')]);
    }

    // MARK: - Lookup misses

    [Fact]
    public void Unmapped_characters_return_null()
    {
        foreach (var text in new[] { " ", "\n", "\t", "🐈", "é", "ก", "ä" })
        {
            var scalar = Rune.GetRuneAt(text, 0);
            Assert.False(KedmaneeMapping.ThaiForQwerty(scalar).HasValue, $"'{text}' should not be a QWERTY key");
        }
        // A Latin letter is not a Kedmanee character.
        Assert.Null(KedmaneeMapping.QwertyForThai(new Rune('a')));
        Assert.Null(KedmaneeMapping.QwertyForThai(new Rune(' ')));
    }

    // MARK: - Helper

    /// Asserts both directions for each pair, so a spot check can never pass one-way.
    private static void AssertMaps((char Qwerty, char Kedmanee)[] expected)
    {
        foreach (var (qwerty, kedmanee) in expected)
        {
            Assert.True(new Rune(kedmanee) == KedmaneeMapping.ThaiForQwerty(new Rune(qwerty)), $"key '{qwerty}' → Thai");
            Assert.True(new Rune(qwerty) == KedmaneeMapping.QwertyForThai(new Rune(kedmanee)), $"'{kedmanee}' → key");
        }
    }
}
