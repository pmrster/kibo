using System.Text;

namespace Kibo.Core;

/// <summary>
/// The mirror of <see cref="ThaiOrthography"/>: decides whether an ASCII run reads as English, or
/// as Thai typed with the US layout active. The port of <c>LatinOrthography.swift</c>.
/// </summary>
/// <remarks>
/// Thai typed on QWERTY produces long consonant pile-ups and stray keyboard punctuation, because
/// Thai's consonant-heavy words land on whatever ASCII keys the Kedmanee layout assigns them.
/// Those two signals carry most of the weight here. <b>Every threshold was set by measuring false
/// positives</b>, not by intuition — see the regression list in <c>LatinOrthographyTests</c>.
/// </remarks>
internal static class LatinOrthography
{
    /// <summary>ASCII letters only — never <see cref="Rune.IsLetter"/>, which would admit <c>é</c>.</summary>
    private static bool IsLetter(Rune scalar) => scalar.Value is (>= 0x41 and <= 0x5A) or (>= 0x61 and <= 0x7A);

    /// <summary>
    /// <c>y</c> counts. It carries English syllables that have no other vowel — <c>rhythm</c>,
    /// <c>by</c> — and excluding it would flag them as wreckage.
    /// </summary>
    private static bool IsVowel(Rune scalar) => scalar.Value < 0x80 && "aeiouyAEIOUY".Contains((char)scalar.Value);

    private static bool IsUppercase(Rune scalar) => scalar.Value is >= 0x41 and <= 0x5A;

    /// <summary>
    /// Characters that never appear inside an English word but are ordinary Kedmanee keys.
    /// <c>;</c> is the <c>ว</c> key — which is the whole reason <c>l;ylfu</c> is Thai in disguise.
    /// Deliberately just the one character: <c>[</c>, <c>]</c> and <c>\</c> are Kedmanee keys too,
    /// but including them converted <c>array[i]</c> and <c>C:\Users\alice</c> into Thai, and
    /// <c>'</c> is how English writes <c>don't</c>.
    /// </summary>
    private static bool IsKeyboardOnly(Rune scalar) => scalar.Value == ';';

    /// <summary>
    /// Below this many letters there is not enough signal to call a run mistyped, and guessing
    /// wrong would mangle ordinary acronyms like <c>PM</c> and <c>TV</c>.
    /// </summary>
    private const int MinimumLettersToJudge = 3;

    /// <summary>
    /// The vowel rule needs a long word before it can be trusted, because English is full of
    /// short vowel-less strings that are not mistypings: <c>npm</c>, <c>nth</c>, <c>html</c>,
    /// <c>https</c>. Six is where it stopped producing false positives.
    /// </summary>
    private const int MinimumLettersForVowelRule = 6;

    /// <summary>
    /// English does not stack this many consonants without a vowel. Set so that <c>https</c>
    /// (five) survives and <c>vpkddbodkca</c> (six, from <c>อยากกินกาแฟ</c>) does not.
    /// </summary>
    private const int MaximumConsonantRun = 5;

    /// <summary>
    /// True when the run reads as ordinary English text and should be left exactly as typed.
    /// <para>
    /// Runs with fewer than <see cref="MinimumLettersToJudge"/> letters always come back
    /// <c>true</c> — there is nothing here to judge. That is not the same as "leave it alone":
    /// <see cref="RunJudge"/> has a second, narrower test for those, because Thai consonants map
    /// onto digits and punctuation often enough that a mistyped Thai word can arrive with barely
    /// a letter in it. <see cref="HasTooFewLettersToJudge"/> is how it tells the two apart.
    /// </para>
    /// </summary>
    public static bool IsWellFormed(string text)
    {
        var scalars = text.EnumerateRunes().ToArray();
        var letterCount = scalars.Count(IsLetter);

        // Nothing to judge — this is what keeps `2024` and `:)` intact.
        if (letterCount < MinimumLettersToJudge) return true;

        // A keyboard-only character wedged between two letters gives the mistyping away.
        for (var index = 0; index < scalars.Length; index++)
        {
            if (!IsKeyboardOnly(scalars[index])) continue;
            var letterBefore = index > 0 && IsLetter(scalars[index - 1]);
            var letterAfter = index + 1 < scalars.Length && IsLetter(scalars[index + 1]);
            if (letterBefore && letterAfter) return false;
        }

        // Both remaining rules are applied per letter-group rather than across the whole run,
        // because punctuation genuinely interrupts a word. Measured end to end, `index.html`
        // reads as `indexhtml` — a phantom consonant pile-up that exists only because the dot was
        // deleted first.
        foreach (var group in LetterGroups(scalars))
        {
            // An all-caps group is an acronym, not a mistyping. Without this, `HTML`, `SQL`,
            // `PDF` and `SMS` were all converted into Thai.
            if (group.All(IsUppercase)) continue;

            if (group.Count >= MinimumLettersForVowelRule && !group.Any(IsVowel)) return false;

            var consonantRun = 0;
            foreach (var letter in group)
            {
                consonantRun = IsVowel(letter) ? 0 : consonantRun + 1;
                if (consonantRun > MaximumConsonantRun) return false;
            }
        }
        return true;
    }

    /// <summary>Maximal stretches of letters, with everything else acting as a separator.</summary>
    private static List<List<Rune>> LetterGroups(Rune[] scalars)
    {
        var groups = new List<List<Rune>>();
        var current = new List<Rune>();
        foreach (var scalar in scalars)
        {
            if (IsLetter(scalar))
            {
                current.Add(scalar);
            }
            else if (current.Count > 0)
            {
                groups.Add(current);
                current = [];
            }
        }
        if (current.Count > 0) groups.Add(current);
        return groups;
    }

    /// <summary>
    /// Whether <see cref="IsWellFormed"/> had to abstain on this run for want of letters — in
    /// which case its <c>true</c> means "no opinion", not "leave it alone", and
    /// <see cref="RunJudge"/> should apply its own test.
    /// </summary>
    public static bool HasTooFewLettersToJudge(string text)
    {
        var letters = 0;
        foreach (var scalar in text.EnumerateRunes())
        {
            if (IsLetter(scalar)) letters++;
        }
        return letters < MinimumLettersToJudge;
    }
}
