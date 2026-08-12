import XCTest
@testable import WhoForgotToChangeLangCore

/// The per-run convert-or-keep decision that makes Mixed mode different from the explicit modes.
final class RunJudgeTests: XCTestCase {

    private func judge(_ script: Run.Script, _ text: String) -> Bool {
        RunJudge.shouldConvert(Run(script: script, text: text))
    }

    func test_neutral_runs_are_never_converted() {
        XCTAssertFalse(judge(.neutral, " "))
        XCTAssertFalse(judge(.neutral, "\n\t"))
        XCTAssertFalse(judge(.neutral, "🐈"))
        XCTAssertFalse(judge(.neutral, "日本"))
    }

    func test_malformed_thai_is_converted_and_real_thai_is_not() {
        XCTAssertTrue(judge(.thai, "ไำะ"))
        XCTAssertFalse(judge(.thai, "ครับ"))
        XCTAssertFalse(judge(.thai, "สวัสดี"))
    }

    func test_malformed_latin_is_converted_and_real_english_is_not() {
        XCTAssertTrue(judge(.latin, "l;ylfu"))
        XCTAssertTrue(judge(.latin, "vpkddbodkca"))
        XCTAssertFalse(judge(.latin, "hello"))
        XCTAssertFalse(judge(.latin, "wet"))
    }

    // MARK: - The letter-poor path

    /// Thai consonants sit on digit and punctuation keys, so a mistyped Thai word can arrive with
    /// almost no letters in it. `LatinOrthography` abstains on those; this is the test that
    /// catches them, by asking whether the run turns into convincing Thai.
    func test_letter_poor_runs_that_convert_into_convincing_thai_are_converted() {
        // ขอบคุณ mistyped on the US layout — two letters, and it must still be caught.
        XCTAssertTrue(judge(.latin, "-v[86I"))
    }

    /// The guards that keep the letter-poor path from eating ordinary text.
    func test_letter_poor_runs_that_are_not_thai_in_disguise_are_kept() {
        XCTAssertFalse(judge(.latin, "2024"), "converts to half-ASCII, so it is a number")
        XCTAssertFalse(judge(.latin, ":)"), "too short to carry evidence")
        XCTAssertFalse(judge(.latin, "!!!"), "converts to ASCII, not Thai")
        XCTAssertFalse(judge(.latin, "..."), "too short to carry evidence")
        XCTAssertFalse(judge(.latin, "a/b"), "too short to carry evidence")
        XCTAssertFalse(judge(.latin, "100%"), "converts to malformed Thai")
        XCTAssertFalse(judge(.latin, "3.14"))
        XCTAssertFalse(judge(.latin, "42"))
        XCTAssertFalse(judge(.latin, "PM"))
        XCTAssertFalse(judge(.latin, "ok"))
    }

    /// The letter-poor test must never be applied to runs that have enough letters to judge on
    /// English shape — `rhythm` converts to well-formed Thai and is emphatically not a mistyping.
    func test_english_words_never_reach_the_letter_poor_path() {
        XCTAssertFalse(judge(.latin, "rhythm"))
        XCTAssertFalse(judge(.latin, "world"))
        XCTAssertFalse(judge(.latin, "don't"))
        XCTAssertFalse(judge(.latin, "http://example.com"))
        XCTAssertFalse(judge(.latin, "https://example.com"))
        XCTAssertFalse(judge(.latin, "README.md"))
        XCTAssertFalse(judge(.latin, "index.html"))
    }
}
