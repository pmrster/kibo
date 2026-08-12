import XCTest
@testable import KiboCore

/// The mirror of `ThaiOrthography`: does this ASCII run read as English, or as Thai typed with
/// the US layout on?
final class LatinOrthographyTests: XCTestCase {

    private func assertWellFormed(_ inputs: [String],
                                  file: StaticString = #filePath, line: UInt = #line) {
        for input in inputs {
            XCTAssertTrue(LatinOrthography.isWellFormed(input),
                          "'\(input)' should read as well-formed", file: file, line: line)
        }
    }

    private func assertMalformed(_ inputs: [String],
                                 file: StaticString = #filePath, line: UInt = #line) {
        for input in inputs {
            XCTAssertFalse(LatinOrthography.isWellFormed(input),
                           "'\(input)' should read as malformed", file: file, line: line)
        }
    }

    // MARK: - Real English stays put

    func test_english_words_are_well_formed() {
        assertWellFormed(["hello", "world", "wet", "email", "meeting", "thank", "rhythm", "don't"])
    }

    /// The reason `2024` and `:)` survive Mixed mode: with no letters there is nothing to judge,
    /// so the run is left exactly as typed.
    func test_runs_without_letters_are_well_formed() {
        assertWellFormed(["2024", ":)", "!!!", "...", "42", "-", "3.14", "100%"])
    }

    /// Two letters is not enough evidence to call something mistyped, and guessing wrong here
    /// would mangle ordinary acronyms.
    func test_short_runs_are_left_alone() {
        assertWellFormed(["PM", "TV", "ok", "a", "I", "hi", ""])
    }

    // MARK: - Wreckage gets converted

    /// `;` never sits inside an English word, but it is the `ว` key — which is exactly why
    /// `l;ylfu` is Thai in disguise.
    func test_semicolon_between_letters_is_malformed() {
        assertMalformed(["l;ylfu", "ab;cd"])
    }

    /// A pile of consonants with no vowel to break it up is not an English word.
    func test_long_consonant_clusters_are_malformed() {
        assertMalformed(["vpkddbodkca", "bcdfghj", "bcdfghjk"])
    }

    func test_long_words_with_no_vowel_at_all_are_malformed() {
        assertMalformed(["bcdfgh", "kkkkkk"])
    }

    /// Thai words whose mistyping is caught on English shape alone — `สวัสดี` lands a `;`
    /// mid-word, `อยากกินกาแฟ` produces a six-consonant pile-up.
    func test_thai_words_whose_mistyping_is_caught_on_shape() {
        for word in ["สวัสดี", "อยากกินกาแฟ"] {
            let mistyped = Self.mistypedOnUSLayout(word)
            XCTAssertFalse(LatinOrthography.isWellFormed(mistyped),
                           "'\(word)' mistypes to '\(mistyped)', which the gate thinks is fine")
        }
    }

    /// Known limitations, asserted so the behaviour is recorded rather than discovered.
    ///
    /// `ขอบคุณ` mistypes to `-v[86I`, which has two letters in it — there is no English shape to
    /// judge, so `LatinOrthography` abstains and `RunJudge` catches it with a different test
    /// (see `RunJudgeTests`). `โรงเรียน` mistypes to `Fi'giupo`, which is genuinely English-shaped
    /// — vowels throughout, no consonant pile-up — and nothing here catches it. The escape hatch
    /// is the explicit EN → TH mode.
    func test_known_limitation_some_mistypings_are_english_shaped() {
        assertWellFormed([Self.mistypedOnUSLayout("ขอบคุณ")])    // -v[86I
        assertWellFormed([Self.mistypedOnUSLayout("โรงเรียน")])  // Fi'giupo
    }

    /// What the user would have seen had they typed this Thai word with the US layout active.
    static func mistypedOnUSLayout(_ thai: String) -> String {
        AccuracyCorpus.mistypedOnUSLayout(thai)
    }

    // MARK: - Things that must not be mangled

    /// The letters-only projection joins across punctuation, so a path or URL could invent a
    /// consonant cluster that was never really there. These are the cases that would hurt most.
    func test_urls_and_filenames_survive() {
        assertWellFormed(["http://example.com", "https://example.com", "README.md",
                          "index.html", "user@example.com", "v1.2.3"])
    }

    /// Regression: every one of these was converted into Thai by an earlier, more aggressive
    /// version of this gate. They are the reason the vowel rule needs six letters, `[ ] \` are
    /// not treated as keyboard-only, and all-caps groups are skipped.
    ///
    /// SPEC.md is explicit that this is the failure that matters: "mangling correct text is a
    /// worse failure than leaving a mistyping, because the user can see and fix the latter."
    func test_regression_correct_text_that_was_previously_mangled() {
        assertWellFormed([
            "HTML", "XML", "SQL", "PDF", "SMS",   // all-caps acronyms, no vowels
            "npm", "nth",                          // short and vowel-less, but real
            "https://example.com",                 // `https` is a five-consonant run
            "array[i]", "C:\\Users\\pmr",          // brackets and backslashes are code, not Thai
            "let x = 1;", "foo(bar)",
        ])
    }
}
