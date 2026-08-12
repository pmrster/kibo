import XCTest
@testable import KiboCore

/// The accuracy table in CLAUDE.md, asserted.
///
/// CLAUDE.md says the three figures are "pinned by tests, so a change that trades one for another
/// shows up as a failure". This file is what makes that true. It measures **end to end through
/// `KeyboardConverter` in Mixed mode**, which is what the user actually experiences — the gates
/// have their own unit tests, but a gate verdict is not a promise about the output.
///
/// If you change `RunJudge`, expect to change the numbers here. That is the mechanism working:
/// update the corpus split, re-run, and copy the new figures into CLAUDE.md, SPEC.md and
/// README.md. Do not raise recall without reading what `test_precision` then says.
final class MeasuredAccuracyTests: XCTestCase {

    private let converter = KeyboardConverter()

    private func mixed(_ text: String) -> String {
        converter.convert(text, mode: .mixed).output
    }

    // MARK: - Precision — 36 of 36

    /// The headline promise: correct text is never touched. This is the failure the project treats
    /// as unacceptable, so it is asserted per string *and* by count — without the count, deleting
    /// an awkward entry would quietly lower the bar it claims to hold.
    func test_precision_correct_text_is_returned_completely_unchanged() {
        XCTAssertEqual(AccuracyCorpus.mustSurvive.count, 36,
                       "The precision corpus changed size. CLAUDE.md, SPEC.md and README.md all "
                       + "quote '36 of 36' — update them, and Fixtures/conversion-cases.json too.")
        for text in AccuracyCorpus.mustSurvive {
            XCTAssertEqual(mixed(text), text, "Mixed mangled correct text: '\(text)'")
        }
    }

    // MARK: - Recall, English mistyped on the Thai layout — 15 of 24

    func test_recall_english_corpus_is_the_size_the_docs_claim() {
        let total = AccuracyCorpus.englishCaught.count + AccuracyCorpus.englishMissed.count
        XCTAssertEqual(AccuracyCorpus.englishCaught.count, 15)
        XCTAssertEqual(total, 24, "The docs quote '15 of 24'. Update them with the corpus.")
    }

    func test_recall_english_mistypings_are_fixed() {
        for word in AccuracyCorpus.englishCaught {
            let wreckage = AccuracyCorpus.mistypedOnThaiLayout(word)
            XCTAssertEqual(mixed(wreckage), word,
                           "'\(word)' mistypes to '\(wreckage)', which Mixed no longer recovers")
        }
    }

    /// The misses, asserted so the rate stays visible rather than folded into a passing suite. A
    /// failure here is good news — move the word into `englishCaught`, bump the count above, and
    /// check `test_precision` still passes.
    func test_known_limitation_english_misses_are_left_alone() {
        for word in AccuracyCorpus.englishMissed {
            let wreckage = AccuracyCorpus.mistypedOnThaiLayout(word)
            XCTAssertEqual(mixed(wreckage), wreckage,
                           "'\(word)' → '\(wreckage)' is now recovered; move it to englishCaught")
        }
    }

    // MARK: - Recall, Thai mistyped on the US layout — 4 of 12

    func test_recall_thai_corpus_is_the_size_the_docs_claim() {
        let total = AccuracyCorpus.thaiCaught.count + AccuracyCorpus.thaiMissed.count
        XCTAssertEqual(AccuracyCorpus.thaiCaught.count, 4)
        XCTAssertEqual(total, 12, "The docs quote '4 of 12'. Update them with the corpus.")
    }

    func test_recall_thai_mistypings_are_fixed() {
        for word in AccuracyCorpus.thaiCaught {
            let wreckage = AccuracyCorpus.mistypedOnUSLayout(word)
            XCTAssertEqual(mixed(wreckage), word,
                           "'\(word)' mistypes to '\(wreckage)', which Mixed no longer recovers")
        }
    }

    func test_known_limitation_thai_misses_are_left_alone() {
        for word in AccuracyCorpus.thaiMissed {
            let wreckage = AccuracyCorpus.mistypedOnUSLayout(word)
            XCTAssertEqual(mixed(wreckage), wreckage,
                           "'\(word)' → '\(wreckage)' is now recovered; move it to thaiCaught")
        }
    }
}
