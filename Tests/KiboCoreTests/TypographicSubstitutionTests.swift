import XCTest
@testable import KiboCore

/// macOS rewrites what the user types before the converter ever sees it.
///
/// `NSTextView` — which backs SwiftUI's `TextEditor`, and therefore Kibo's input field — ships
/// with `isAutomaticQuoteSubstitutionEnabled` and `isAutomaticDashSubstitutionEnabled` set to
/// `true`. Typing `'` inserts `’` (U+2019); typing `"` inserts `“`/`”`; typing `-` between words
/// inserts `–`. `.autocorrectionDisabled(true)` does *not* turn any of that off — it only clears
/// `isAutomaticSpellingCorrectionEnabled`.
///
/// That matters here more than in most apps, because those three keys carry Thai characters:
/// `'` is `ง`, `"` is `.`, and `-` is `ข`. Before this, a typed apostrophe reached the converter
/// as U+2019 — absent from the key table and neutral to `RunSplitter` — so it survived even the
/// mechanical EN → TH flip, and `ง` was unreachable from the keyboard.
///
/// The shell now disables those substitutions, but the converter cannot rely on that: **Paste is
/// a first-class path**, and text copied out of Messages, Mail or Slack arrives already curled.
final class TypographicSubstitutionTests: XCTestCase {

    private let converter = KeyboardConverter()

    private func convert(_ input: String, _ mode: ConversionMode) -> String {
        converter.convert(input, mode: mode).output
    }

    // MARK: - The reported bug

    func test_curly_apostrophe_converts_to_ngo_ngu() {
        XCTAssertEqual(convert("\u{2019}", .englishToThai), "ง")
        XCTAssertEqual(convert("\u{2018}", .englishToThai), "ง")
    }

    func test_curly_quotes_and_dashes_reach_their_thai_keys() {
        XCTAssertEqual(convert("\u{201C}", .englishToThai), ".")
        XCTAssertEqual(convert("\u{201D}", .englishToThai), ".")
        XCTAssertEqual(convert("\u{2013}", .englishToThai), "ข")
        XCTAssertEqual(convert("\u{2014}", .englishToThai), "ข")
    }

    /// The point of the fold: a curled apostrophe must convert exactly as the straight one the
    /// user actually pressed, so the substitution becomes invisible.
    func test_curled_text_converts_identically_to_what_was_typed() {
        XCTAssertEqual(convert("don\u{2019}t", .englishToThai),
                       convert("don't", .englishToThai))
        XCTAssertEqual(convert("l;ylfu\u{2019}", .englishToThai),
                       convert("l;ylfu'", .englishToThai))
    }

    // MARK: - Precision: the fold must not rewrite text it leaves alone

    /// Mixed mode declines to convert `don’t`, and must hand it back byte for byte. Folding the
    /// apostrophe to `'` on the way *in* would have quietly straightened the user's punctuation —
    /// a mutation of text the app promised not to touch.
    func test_mixed_mode_returns_untouched_text_with_its_curls_intact() {
        for text in ["don\u{2019}t", "it\u{2019}s fine", "\u{201C}hello\u{201D}", "well \u{2014} yes"] {
            XCTAssertEqual(convert(text, .mixed), text)
        }
    }

    /// The Thai → English direction always emits the straight ASCII key, because that is the key
    /// the layout actually has. There is no curled `ง`.
    func test_thai_to_english_still_emits_the_straight_key() {
        XCTAssertEqual(convert("ง", .thaiToEnglish), "'")
        XCTAssertEqual(convert("ข", .thaiToEnglish), "-")
    }

    // MARK: - Run splitting

    /// U+2019 used to be neutral, which split `don’t` into three runs and denied `RunJudge` the
    /// word it needed to judge.
    func test_a_curled_apostrophe_keeps_its_word_in_one_run() {
        let runs = RunSplitter.split("don\u{2019}t")
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs.first?.script, .latin)
        XCTAssertEqual(runs.first?.text, "don\u{2019}t")
    }

    func test_runs_still_rejoin_to_the_input_exactly() {
        let input = "\u{201C}don\u{2019}t\u{201D} \u{2014} สวัสดี 2024"
        XCTAssertEqual(RunSplitter.split(input).map(\.text).joined(), input)
    }
}
