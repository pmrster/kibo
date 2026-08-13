import XCTest
@testable import KiboCore

/// The gate that decides whether a Thai run is real Thai or the wreckage of typing English with
/// the Thai layout on. Dictionary-free, so it judges spelling shape only — see the
/// `known limitations` section for exactly where that runs out.
final class ThaiOrthographyTests: XCTestCase {

    private func assertWellFormed(_ inputs: [String],
                                  file: StaticString = #filePath, line: UInt = #line) {
        for input in inputs {
            XCTAssertTrue(ThaiOrthography.isWellFormed(input),
                          "'\(input)' should read as well-formed Thai", file: file, line: line)
        }
    }

    private func assertMalformed(_ inputs: [String],
                                 file: StaticString = #filePath, line: UInt = #line) {
        for input in inputs {
            XCTAssertFalse(ThaiOrthography.isWellFormed(input),
                           "'\(input)' should read as malformed", file: file, line: line)
        }
    }

    // MARK: - Real Thai stays put

    func test_real_thai_words_are_well_formed() {
        assertWellFormed(["ครับ", "สวัสดี", "ขอบคุณ", "อยากกินกาแฟ", "ผม", "ไป", "แมว", "โรงเรียน"])
    }

    func test_empty_run_is_vacuously_well_formed() {
        assertWellFormed([""])
    }

    /// Thai numerals, the baht sign, and the repetition mark stand on their own — they need no
    /// consonant and must not be mistaken for stray marks.
    func test_standalone_characters_are_well_formed() {
        assertWellFormed(["๑๒๓", "฿", "ๆ", "ฯ", "๑๐๐฿"])
    }

    // MARK: - Wreckage gets converted

    /// A vowel mark with no consonant to attach to is the signature of English typed on the Thai
    /// layout — the very first character gives it away.
    func test_run_starting_with_a_combining_mark_is_malformed() {
        assertMalformed([
            "\u{0E33}ทฟรส",   // ำทฟรส — "email"
            "\u{0E49}\u{0E36}",  // ้ึ    — leading tone mark
            "\u{0E48}",       // ่      — a lone mark
        ])
    }

    /// เ แ โ ใ ไ are written before the consonant they belong to, so one with no consonant after
    /// it — including at the end of a run — is broken.
    func test_leading_vowel_without_a_following_consonant_is_malformed() {
        assertMalformed([
            "ไ\u{0E33}\u{0E30}",   // ไำะ — "wet"
            "เ",                    // trailing leading-vowel
            "ครับเ",                // ends on a leading vowel
            "ไไก",                  // leading vowel followed by another leading vowel
        ])
    }

    /// `ะ า ำ ๅ` are *spacing* vowels — they occupy their own cell and complete the syllable, so a
    /// combining vowel cannot attach after one: there is no consonant left for it to sit on.
    ///
    /// This is what catches the `-ture` family. On the Thai layout `t` is `ะ` and `u` is `ี`, so
    /// `feature` lands `ะี` in the middle, which is unpronounceable — but every earlier rule was
    /// satisfied, because `ฟ` two characters back still counted as a base.
    func test_a_combining_vowel_cannot_follow_a_spacing_vowel() {
        assertMalformed([
            "ด\u{0E33}ฟ\u{0E30}\u{0E35}พ\u{0E33}",  // ดำฟะีพำ — "feature"
            "ด\u{0E35}\u{0E30}\u{0E35}พ\u{0E33}",   // ดีะีพำ  — "future"
            "ก\u{0E32}\u{0E34}",                     // กาิ    — sara ii after sara aa
            "ก\u{0E33}\u{0E31}",                     // กำั    — mai han-akat after sara am
        ])
    }

    /// Tone marks are exempt from that rule on purpose. `นำ้` is `น้ำ` with the tone mark and the
    /// sara am encoded the wrong way round — sloppy, and common enough in pasted text to matter.
    /// It is still Thai, and converting it into Latin would be the worse failure.
    func test_a_tone_mark_after_a_spacing_vowel_is_tolerated() {
        assertWellFormed([
            "น\u{0E33}\u{0E49}",   // นำ้ — misordered น้ำ
            "น\u{0E49}\u{0E33}",   // น้ำ — the correct order
        ])
    }

    /// The shapes the new rule must not break: two spacing vowels in a row is ordinary Thai
    /// (`เ-าะ`), and a spacing vowel before a leading vowel or a consonant is unremarkable.
    func test_spacing_vowels_in_sequence_stay_well_formed() {
        assertWellFormed(["เกาะ", "เพราะ", "อะไร", "สะอาด", "ปะทะ", "ฟาร์ม", "เสาร์", "ก็"])
    }

    func test_doubled_identical_marks_are_malformed() {
        assertMalformed([
            "ท\u{0E33}\u{0E33}\u{0E30}ร\u{0E37}เ",  // ทำำะรืเ — "meeting"
            "ก\u{0E35}\u{0E35}",                     // กีี
        ])
    }

    /// English words whose mistyping breaks a Thai spelling rule outright — usually because the
    /// word starts with a letter that maps to a vowel mark, leaving it with no consonant to
    /// attach to.
    func test_common_english_words_mistyped_on_the_thai_layout_are_caught() {
        for word in AccuracyCorpus.englishCaught {
            let mistyped = Self.mistypedOnThaiLayout(word)
            XCTAssertFalse(ThaiOrthography.isWellFormed(mistyped),
                           "'\(word)' mistypes to '\(mistyped)', which the gate thinks is fine")
        }
    }

    /// What the user would have seen had they typed this English word with the Thai layout active.
    static func mistypedOnThaiLayout(_ english: String) -> String {
        AccuracyCorpus.mistypedOnThaiLayout(english)
    }

    // MARK: - Known limitations

    /// Documented misses, asserted so nobody "fixes" them by accident. Both are orthographically
    /// valid Thai, so a dictionary-free gate cannot tell them from real words — and `นา` really
    /// is a Thai word (a rice field), so not even a dictionary would help.
    ///
    /// The escape hatch for both is switching to the explicit TH → EN mode.
    func test_known_limitation_plausible_looking_wreckage_is_kept() {
        // "code" typed on the Thai layout — every rule satisfied, but it means nothing.
        assertWellFormed(["แนกำ"])
        // "ok" typed on the Thai layout — collides with a real word.
        assertWellFormed(["นา"])
    }

    /// English words made only of letters that map to Thai consonants come out looking like
    /// perfectly ordinary Thai spelling, so the gate has nothing to object to. Recorded here so
    /// the miss rate is visible rather than folded into a passing suite.
    ///
    /// The rate itself is measured end-to-end in `MeasuredAccuracyTests` — 15 of 24 — and the
    /// corpus is shared, so these two files can no longer disagree about it. (They used to: this
    /// comment claimed "17 of a 26-word sample" while the docs claimed 16 of 25 and the lists
    /// added up to 24.) Switching to the explicit TH → EN mode converts them.
    func test_known_limitation_consonant_heavy_english_words_are_kept() {
        for word in AccuracyCorpus.englishMissed {
            let mistyped = Self.mistypedOnThaiLayout(word)
            XCTAssertTrue(ThaiOrthography.isWellFormed(mistyped),
                          "'\(word)' → '\(mistyped)' is now caught; move it to the caught list")
        }
    }
}
