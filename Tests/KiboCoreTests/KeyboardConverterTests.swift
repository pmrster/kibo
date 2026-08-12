import XCTest
@testable import KiboCore

final class KeyboardConverterTests: XCTestCase {

    private let converter = KeyboardConverter()

    private func convert(_ input: String, _ mode: ConversionMode) -> String {
        converter.convert(input, mode: mode).output
    }

    // MARK: - The documented examples

    /// Every worked example in SPEC.md, which is the contract the app promises on its own tin.
    func test_spec_examples() {
        XCTAssertEqual(convert("vpkddbodkca", .englishToThai), "อยากกินกาแฟ")
        XCTAssertEqual(convert("ะ้ฟืา", .thaiToEnglish), "thank")
        XCTAssertEqual(convert("l;ylfu", .englishToThai), "สวัสดี")
        XCTAssertEqual(convert("ไำะ", .thaiToEnglish), "wet")
    }

    /// The behaviour the whole Mixed design exists for: wreckage is fixed, correct text is not,
    /// and everything that is neither is left exactly where it was.
    func test_mixed_worked_example() {
        XCTAssertEqual(convert("l;ylfu ไำะ ครับ 2024 :)", .mixed), "สวัสดี wet ครับ 2024 :)")
    }

    // MARK: - Result shape

    func test_result_carries_its_question() {
        let result = converter.convert("l;ylfu", mode: .englishToThai)
        XCTAssertEqual(result.input, "l;ylfu")
        XCTAssertEqual(result.output, "สวัสดี")
        XCTAssertEqual(result.mode, .englishToThai)
    }

    func test_empty_input_converts_to_empty_output_in_every_mode() {
        for mode in ConversionMode.allCases {
            XCTAssertEqual(convert("", mode), "", "\(mode)")
        }
    }

    // MARK: - Preservation

    /// AGENTS.md is explicit that unmapped characters are never normalised or dropped. Whitespace
    /// and line structure carry meaning in pasted text, and losing them would be worse than a
    /// wrong conversion because it is invisible.
    func test_unmapped_characters_are_preserved_exactly() {
        for mode in [ConversionMode.englishToThai, .thaiToEnglish] {
            XCTAssertEqual(convert(" ", mode), " ", "\(mode)")
            XCTAssertEqual(convert("\n\n", mode), "\n\n", "\(mode)")
            XCTAssertEqual(convert("\t", mode), "\t", "\(mode)")
            XCTAssertEqual(convert("🐈🇹🇭", mode), "🐈🇹🇭", "\(mode)")
            XCTAssertEqual(convert("日本", mode), "日本", "\(mode)")
            XCTAssertEqual(convert("café", mode).hasSuffix("é"), true, "\(mode)")
        }
    }

    func test_multiline_input_keeps_its_line_structure() {
        let input = "l;ylfu\nl;ylfu\n\nl;ylfu"
        XCTAssertEqual(convert(input, .englishToThai), "สวัสดี\nสวัสดี\n\nสวัสดี")
    }

    func test_mixed_preserves_emoji_and_newlines_between_runs() {
        XCTAssertEqual(convert("l;ylfu\n🐈 ครับ", .mixed), "สวัสดี\n🐈 ครับ")
    }

    // MARK: - Direction

    /// The two explicit modes are exact inverses, because the mapping table is a bijection.
    func test_explicit_modes_round_trip() {
        let samples = ["l;ylfu", "vpkddbodkca", "Hello, World!", "a;sldkfj 123 [];'"]
        for sample in samples {
            let thai = convert(sample, .englishToThai)
            XCTAssertEqual(convert(thai, .thaiToEnglish), sample, "round trip of '\(sample)'")
        }
    }

    /// Explicit modes are mechanical — they do not consult the orthography gate. This is what
    /// makes them a usable escape hatch when Mixed guesses wrong.
    func test_explicit_modes_convert_even_well_formed_text() {
        XCTAssertEqual(convert("ครับ", .thaiToEnglish), "8iy[")
        XCTAssertNotEqual(convert("hello", .englishToThai), "hello")
    }

    /// Text in the wrong script for the mode passes through: there is nothing to map.
    func test_explicit_modes_ignore_text_from_the_other_script() {
        XCTAssertEqual(convert("สวัสดี", .englishToThai), "สวัสดี")
        XCTAssertEqual(convert("hello", .thaiToEnglish), "hello")
    }

    // MARK: - Mixed specifics

    func test_mixed_leaves_correct_text_of_both_scripts_alone() {
        XCTAssertEqual(convert("ครับ hello", .mixed), "ครับ hello")
    }

    func test_mixed_converts_each_run_in_its_own_direction() {
        XCTAssertEqual(convert("l;ylfu ไำะ", .mixed), "สวัสดี wet")
    }

    /// A Thai run that arrives with almost no letters after mistyping — `ขอบคุณ` — still gets
    /// fixed, via the letter-poor path in `RunJudge`.
    func test_mixed_fixes_letter_poor_thai_wreckage() {
        XCTAssertEqual(convert("-v[86I", .mixed), "ขอบคุณ")
    }

    /// End-to-end precision. SPEC.md: "mangling correct text is a worse failure than leaving a
    /// mistyping, because the user can see and fix the latter." Every string here is text a user
    /// might plausibly paste in, and Mixed must hand all of it back untouched.
    ///
    /// Kept at the converter level rather than only on the gates, because this is the promise the
    /// user actually experiences.
    func test_mixed_returns_correct_text_completely_unchanged() {
        let mustSurvive = [
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
        ]
        for text in mustSurvive {
            XCTAssertEqual(convert(text, .mixed), text, "Mixed mangled correct text: '\(text)'")
        }
    }

    // MARK: - Scale

    /// PLAN.md asks for conversion to stay visually immediate at 100,000 characters, since the
    /// output is recomputed on every keystroke.
    func test_converts_one_hundred_thousand_characters_quickly() {
        // Counted in scalars, not Characters: Thai combining marks fuse, so `.count` understates
        // how much text the converter actually walks.
        let input = String(repeating: "l;ylfu ไำะ ครับ 2024 :) ", count: 5_000)
        XCTAssertGreaterThan(input.unicodeScalars.count, 100_000)

        let start = Date()
        let output = convert(input, .mixed)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertFalse(output.isEmpty)
        XCTAssertLessThan(elapsed, 1.0, "mixed conversion of 100k characters took \(elapsed)s")
    }
}
