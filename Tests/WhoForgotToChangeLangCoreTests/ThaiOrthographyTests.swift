import XCTest
@testable import WhoForgotToChangeLangCore

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
        for word in ["email", "meeting", "hello", "thanks", "update", "when", "the", "you",
                     "project", "review", "design", "test", "build", "morning", "today"] {
            let mistyped = Self.mistypedOnThaiLayout(word)
            XCTAssertFalse(ThaiOrthography.isWellFormed(mistyped),
                           "'\(word)' mistypes to '\(mistyped)', which the gate thinks is fine")
        }
    }

    /// What the user would have seen had they typed this English word with the Thai layout active.
    static func mistypedOnThaiLayout(_ english: String) -> String {
        String(String.UnicodeScalarView(
            english.unicodeScalars.compactMap { KedmaneeMapping.thai(forQwerty: $0) }))
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
    /// Measured over a 26-word sample of everyday English, the gate catches 17. These nine are
    /// the misses. Switching to the explicit TH → EN mode converts them.
    func test_known_limitation_consonant_heavy_english_words_are_kept() {
        for word in ["about", "please", "sorry", "code", "ok", "and", "report", "great", "work"] {
            let mistyped = Self.mistypedOnThaiLayout(word)
            XCTAssertTrue(ThaiOrthography.isWellFormed(mistyped),
                          "'\(word)' → '\(mistyped)' is now caught; move it to the caught list")
        }
    }
}
