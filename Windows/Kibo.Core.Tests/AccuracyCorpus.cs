using System.Text;

namespace Kibo.Core.Tests;

/// The corpora behind the accuracy table in CLAUDE.md, copied verbatim from
/// `Tests/KiboCoreTests/AccuracyCorpus.swift` so the C# port is measured against exactly the same
/// strings. Every list is split into what the gate catches and what it misses, and
/// `MeasuredAccuracyTests` asserts **both directions** — a change that raises recall by mangling
/// correct text moves words out of `missed` *and* breaks precision, and both show up as failures.
public static class AccuracyCorpus
{
    // MARK: - Precision: correct text that Mixed must hand back untouched

    /// SPEC.md: "mangling correct text is a worse failure than leaving a mistyping, because the
    /// user can see and fix the latter." Each group exists because an earlier, more aggressive
    /// gate converted it into Thai.
    public static readonly string[] MustSurvive =
    [
        // Acronyms and vowel-less abbreviations
        "HTML", "XML", "SQL", "PDF", "SMS", "npm", "nth", "PM", "TV", "ok",
        // URLs, paths, filenames, versions
        "https://example.com", "http://example.com", "user@example.com",
        "README.md", "index.html", "C:\\Users\\alice", "v1.2.3", "a/b",
        // Code
        "array[i]", "let x = 1;", "foo(bar)",
        // Ordinary English
        "hello", "world", "rhythm", "don't", "email", "meeting", "thank you",
        // Numbers and punctuation
        "2024", ":)", "3.14", "100%", "42",
        // Correct Thai, including an unsegmented phrase
        "ครับ", "สวัสดีครับ", "ขอบคุณมาก",
    ];

    // MARK: - Recall: English typed while the Thai layout was active

    /// Caught because the wreckage breaks a Thai spelling rule outright. The `-ture` group is
    /// caught by the spacing-vowel rule: `t` is `ะ` and `u` is `ี`.
    public static readonly string[] EnglishCaught =
    [
        "email", "meeting", "hello", "thanks", "update", "when", "the", "you",
        "project", "review", "design", "test", "build", "morning", "today",
        "feature", "picture", "future", "nature",
    ];

    /// Missed, and unfixable without a dictionary: the wreckage is orthographically perfect Thai.
    /// `value` and `issue` keep the `-ture` group honest — measured with it, not rescued by it.
    public static readonly string[] EnglishMissed =
    [
        "about", "please", "sorry", "code", "ok", "and", "report", "great", "work",
        "value", "issue",
    ];

    // MARK: - Recall: Thai typed while the US layout was active

    /// Caught on English shape, or — for `ขอบคุณ` → `-v[86I` — by the letter-poor path.
    public static readonly string[] ThaiCaught = ["สวัสดี", "อยากกินกาแฟ", "ขอบคุณ", "สวัสดีครับ"];

    /// Missed because the wreckage is genuinely English-shaped, or too short to judge.
    public static readonly string[] ThaiMissed =
    [
        "โรงเรียน", "ผม", "แมว", "ไป", "กิน", "ทำงาน", "วันนี้", "พรุ่งนี้",
    ];

    // MARK: - Layout simulation

    /// What the user would have seen had they typed this English word with the Thai layout active.
    /// Unmapped scalars are dropped, as the Swift `compactMap` does — a test helper, unlike the
    /// converter, which passes them through.
    public static string MistypedOnThaiLayout(string english) =>
        Simulate(english, KedmaneeMapping.ThaiForQwerty);

    /// What the user would have seen had they typed this Thai word with the US layout active.
    public static string MistypedOnUSLayout(string thai) =>
        Simulate(thai, KedmaneeMapping.QwertyForThai);

    private static string Simulate(string text, Func<Rune, Rune?> lookup)
    {
        var builder = new StringBuilder();
        foreach (var scalar in text.EnumerateRunes())
        {
            if (lookup(scalar) is { } mapped)
            {
                builder.Append(mapped.ToString());
            }
        }
        return builder.ToString();
    }
}
