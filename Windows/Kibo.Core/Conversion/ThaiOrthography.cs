using System.Text;

namespace Kibo.Core;

/// <summary>
/// Decides whether a Thai run is real Thai or the wreckage of typing English with the Thai layout
/// active — without a dictionary. The port of <c>ThaiOrthography.swift</c>.
/// </summary>
/// <remarks>
/// Thai spelling has hard structural rules, and typing English on the Thai layout breaks them
/// almost immediately: vowel marks land with no consonant to attach to. That is a far cheaper
/// signal than word lookup, and it needs no word segmentation — written Thai has no spaces.
/// <para>
/// <b>What it cannot do.</b> It judges spelling shape, not meaning. Wreckage that happens to be
/// well-formed passes through unchanged — <c>แนกำ</c> ("code" mistyped) breaks no rule, and
/// <c>นา</c> ("ok" mistyped) is a real Thai word. The explicit TH → EN mode is the escape hatch.
/// </para>
/// </remarks>
internal static class ThaiOrthography
{
    /// <summary>ก through ฮ. <c>ฤ</c> and <c>ฦ</c> sit in this range and count as consonants.</summary>
    private static bool IsConsonant(Rune scalar) => scalar.Value is >= 0x0E01 and <= 0x0E2E;

    /// <summary>เ แ โ ใ ไ — written <i>before</i> the consonant they belong to.</summary>
    private static bool IsLeadingVowel(Rune scalar) => scalar.Value is >= 0x0E40 and <= 0x0E44;

    /// <summary>
    /// Vowels and tone marks that must follow a consonant, whether they combine with it
    /// (<c>ั ิ ี ึ ื ุ ู ่ ้ ๊ ๋ ์ ํ</c>) or merely sit after it (<c>ะ า ำ ๅ</c>).
    /// </summary>
    private static bool IsFollowingMark(Rune scalar) => scalar.Value switch
    {
        >= 0x0E30 and <= 0x0E3A => true,
        0x0E45 => true,
        >= 0x0E47 and <= 0x0E4E => true,
        _ => false,
    };

    /// <summary>
    /// <c>ะ า ำ ๅ</c> — the following marks that take a cell of their own. They complete the
    /// syllable, which is what makes the spacing-vowel rule possible.
    /// </summary>
    private static bool IsSpacingVowel(Rune scalar) => scalar.Value is 0x0E30 or 0x0E32 or 0x0E33 or 0x0E45;

    /// <summary><c>่ ้ ๊ ๋</c> — the four tone marks, which the spacing-vowel rule exempts.</summary>
    private static bool IsToneMark(Rune scalar) => scalar.Value is >= 0x0E48 and <= 0x0E4B;

    /// <summary>
    /// Whether the text carries any Thai vowel or tone mark. Real Thai spells its vowels, so a
    /// "Thai" string with none of them is usually punctuation that happened to map across.
    /// </summary>
    public static bool ContainsFollowingMark(string text)
    {
        foreach (var scalar in text.EnumerateRunes())
        {
            if (IsFollowingMark(scalar)) return true;
        }
        return false;
    }

    /// <summary>Whether every scalar is in the Thai block. Empty text is <c>false</c>.</summary>
    public static bool IsEntirelyThaiScript(string text)
    {
        if (text.Length == 0) return false;
        foreach (var scalar in text.EnumerateRunes())
        {
            if (scalar.Value is < 0x0E00 or > 0x0E7F) return false;
        }
        return true;
    }

    /// <summary>
    /// True when the run breaks none of Thai's structural spelling rules. Empty runs are
    /// vacuously well-formed. Characters that stand on their own — Thai digits, <c>฿</c>,
    /// <c>ๆ</c>, <c>ฯ</c> — need no consonant and simply end any pending attachment.
    /// </summary>
    public static bool IsWellFormed(string text)
    {
        var scalars = text.EnumerateRunes().ToArray();
        // Whether a consonant is available for a following mark to attach to. Marks keep it
        // available (a consonant can carry a vowel *and* a tone mark); anything else clears it.
        var hasBase = false;
        Rune? previousMark = null;

        for (var index = 0; index < scalars.Length; index++)
        {
            var scalar = scalars[index];
            if (IsConsonant(scalar))
            {
                hasBase = true;
                previousMark = null;
            }
            else if (IsLeadingVowel(scalar))
            {
                // Rule: a leading vowel must be followed by a consonant — including not being
                // the last character in the run.
                if (index + 1 >= scalars.Length || !IsConsonant(scalars[index + 1])) return false;
                hasBase = false;
                previousMark = null;
            }
            else if (IsFollowingMark(scalar))
            {
                // Rule: a mark needs a consonant earlier in the run.
                if (!hasBase) return false;
                // Rule: the same mark twice in a row is never correct.
                if (previousMark is { } same && same == scalar) return false;
                // Rule: a spacing vowel completes the syllable, so a *combining* vowel cannot
                // follow one — it would have no consonant of its own to sit on. `hasBase` alone
                // misses this, because the consonant two back is still notionally available.
                // Two spacing vowels in a row stay legal: `เ-าะ` spells `เกาะ`.
                //
                // Tone marks are exempt. `นำ้` is `น้ำ` with the tone and the sara am the wrong
                // way round — sloppy, but real Thai, and mangling it would be the worse error.
                if (previousMark is { } previous && IsSpacingVowel(previous)
                    && !IsSpacingVowel(scalar) && !IsToneMark(scalar))
                {
                    return false;
                }
                previousMark = scalar;
            }
            else
            {
                // Standalone: digits, currency, repetition and abbreviation marks.
                hasBase = false;
                previousMark = null;
            }
        }
        return true;
    }
}
