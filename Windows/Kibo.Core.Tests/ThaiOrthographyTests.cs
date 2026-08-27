namespace Kibo.Core.Tests;

/// The gate that decides whether a Thai run is real Thai or the wreckage of typing English with
/// the Thai layout on. Dictionary-free, so it judges spelling shape only — see the
/// `Known limitations` section for exactly where that runs out.
public class ThaiOrthographyTests
{
    private static void AssertWellFormed(params string[] inputs)
    {
        foreach (var input in inputs)
        {
            Assert.True(ThaiOrthography.IsWellFormed(input), $"'{input}' should read as well-formed Thai");
        }
    }

    private static void AssertMalformed(params string[] inputs)
    {
        foreach (var input in inputs)
        {
            Assert.False(ThaiOrthography.IsWellFormed(input), $"'{input}' should read as malformed");
        }
    }

    // MARK: - Real Thai stays put

    [Fact]
    public void Real_thai_words_are_well_formed()
    {
        AssertWellFormed("ครับ", "สวัสดี", "ขอบคุณ", "อยากกินกาแฟ", "ผม", "ไป", "แมว", "โรงเรียน");
    }

    [Fact]
    public void Empty_run_is_vacuously_well_formed()
    {
        AssertWellFormed("");
    }

    /// Thai numerals, the baht sign, and the repetition mark stand on their own — they need no
    /// consonant and must not be mistaken for stray marks.
    [Fact]
    public void Standalone_characters_are_well_formed()
    {
        AssertWellFormed("๑๒๓", "฿", "ๆ", "ฯ", "๑๐๐฿");
    }

    // MARK: - Wreckage gets converted

    /// A vowel mark with no consonant to attach to is the signature of English typed on the Thai
    /// layout — the very first character gives it away.
    [Fact]
    public void Run_starting_with_a_combining_mark_is_malformed()
    {
        AssertMalformed(
            "\u0E33ทฟรส",     // ำทฟรส — "email"
            "\u0E49\u0E36",   // ้ึ    — leading tone mark
            "\u0E48");        // ่      — a lone mark
    }

    /// เ แ โ ใ ไ are written before the consonant they belong to, so one with no consonant after
    /// it — including at the end of a run — is broken.
    [Fact]
    public void Leading_vowel_without_a_following_consonant_is_malformed()
    {
        AssertMalformed(
            "ไ\u0E33\u0E30",   // ไำะ — "wet"
            "เ",               // trailing leading-vowel
            "ครับเ",           // ends on a leading vowel
            "ไไก");            // leading vowel followed by another leading vowel
    }

    /// `ะ า ำ ๅ` are *spacing* vowels — they complete the syllable, so a combining vowel cannot
    /// attach after one. This is what catches the `-ture` family: `t` is `ะ` and `u` is `ี`.
    [Fact]
    public void A_combining_vowel_cannot_follow_a_spacing_vowel()
    {
        AssertMalformed(
            "ด\u0E33ฟ\u0E30\u0E35พ\u0E33",  // ดำฟะีพำ — "feature"
            "ด\u0E35\u0E30\u0E35พ\u0E33",   // ดีะีพำ  — "future"
            "ก\u0E32\u0E34",                // กาิ    — sara ii after sara aa
            "ก\u0E33\u0E31");               // กำั    — mai han-akat after sara am
    }

    /// Tone marks are exempt from that rule on purpose. `นำ้` is `น้ำ` with the tone mark and the
    /// sara am encoded the wrong way round — sloppy, but still Thai.
    [Fact]
    public void A_tone_mark_after_a_spacing_vowel_is_tolerated()
    {
        AssertWellFormed(
            "น\u0E33\u0E49",   // นำ้ — misordered น้ำ
            "น\u0E49\u0E33");  // น้ำ — the correct order
    }

    /// The shapes the rule must not break: two spacing vowels in a row is ordinary Thai
    /// (`เ-าะ`), and a spacing vowel before a leading vowel or a consonant is unremarkable.
    [Fact]
    public void Spacing_vowels_in_sequence_stay_well_formed()
    {
        AssertWellFormed("เกาะ", "เพราะ", "อะไร", "สะอาด", "ปะทะ", "ฟาร์ม", "เสาร์", "ก็");
    }

    [Fact]
    public void Doubled_identical_marks_are_malformed()
    {
        AssertMalformed(
            "ท\u0E33\u0E33\u0E30ร\u0E37เ",  // ทำำะรืเ — "meeting"
            "ก\u0E35\u0E35");               // กีี
    }

    /// English words whose mistyping breaks a Thai spelling rule outright.
    [Fact]
    public void Common_english_words_mistyped_on_the_thai_layout_are_caught()
    {
        foreach (var word in AccuracyCorpus.EnglishCaught)
        {
            var mistyped = AccuracyCorpus.MistypedOnThaiLayout(word);
            Assert.False(ThaiOrthography.IsWellFormed(mistyped), $"'{word}' mistypes to '{mistyped}', which the gate thinks is fine");
        }
    }

    // MARK: - Known limitations

    /// Documented misses, asserted so nobody "fixes" them by accident. Both are orthographically
    /// valid Thai — and `นา` really is a Thai word (a rice field).
    [Fact]
    public void Known_limitation_plausible_looking_wreckage_is_kept()
    {
        AssertWellFormed("แนกำ");   // "code" typed on the Thai layout
        AssertWellFormed("นา");     // "ok" typed on the Thai layout — collides with a real word
    }

    /// English words made only of letters that map to Thai consonants come out looking like
    /// ordinary Thai spelling. Recorded so the miss rate is visible rather than folded into a
    /// passing suite; the rate itself is measured end-to-end in `MeasuredAccuracyTests`.
    [Fact]
    public void Known_limitation_consonant_heavy_english_words_are_kept()
    {
        foreach (var word in AccuracyCorpus.EnglishMissed)
        {
            var mistyped = AccuracyCorpus.MistypedOnThaiLayout(word);
            Assert.True(ThaiOrthography.IsWellFormed(mistyped), $"'{word}' → '{mistyped}' is now caught; move it to the caught list");
        }
    }

    // MARK: - The helpers RunJudge relies on

    [Fact]
    public void Entirely_thai_script_requires_a_non_empty_all_thai_run()
    {
        Assert.True(ThaiOrthography.IsEntirelyThaiScript("ขอบคุณ"));
        Assert.True(ThaiOrthography.IsEntirelyThaiScript("๑๒๓"));
        Assert.False(ThaiOrthography.IsEntirelyThaiScript(""));
        Assert.False(ThaiOrthography.IsEntirelyThaiScript("/จ/ภ"));
        Assert.False(ThaiOrthography.IsEntirelyThaiScript("ครับ "));
    }

    [Fact]
    public void Contains_following_mark_tells_words_from_consonant_strings()
    {
        Assert.True(ThaiOrthography.ContainsFollowingMark("ขอบคุณ"));
        Assert.False(ThaiOrthography.ContainsFollowingMark("ซ๗"));
        Assert.False(ThaiOrthography.ContainsFollowingMark(""));
    }
}
