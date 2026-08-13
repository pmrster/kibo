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
        XCTAssertEqual(convert("้ำสสน", .thaiToEnglish), "hello")
    }

    /// The behaviour the whole Mixed design exists for: wreckage is fixed, correct text is not,
    /// and everything that is neither is left exactly where it was.
    func test_mixed_worked_example() {
        XCTAssertEqual(convert("l;ylfu ้ำสสน ครับ 2024 :)", .mixed), "สวัสดี hello ครับ 2024 :)")
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
        XCTAssertEqual(convert("l;ylfu ้ำสสน", .mixed), "สวัสดี hello")
    }

    /// A Thai run that arrives with almost no letters after mistyping — `ขอบคุณ` — still gets
    /// fixed, via the letter-poor path in `RunJudge`.
    func test_mixed_fixes_letter_poor_thai_wreckage() {
        XCTAssertEqual(convert("-v[86I", .mixed), "ขอบคุณ")
    }

    /// End-to-end precision — the corpus itself is `AccuracyCorpus.mustSurvive` and the assertion
    /// with its count guard lives in `MeasuredAccuracyTests`, alongside the two recall figures it
    /// trades against. Kept as a pointer rather than a second copy of the same 36 strings: two
    /// copies drift, and this is the one number the project refuses to let drift.
    func test_mixed_returns_correct_text_completely_unchanged() {
        for text in AccuracyCorpus.mustSurvive {
            XCTAssertEqual(convert(text, .mixed), text, "Mixed mangled correct text: '\(text)'")
        }
    }

    // MARK: - Both directions at once

    /// The case the mode exists for: one sentence mistyped in *both* directions, because the
    /// layout was switched partway through. Neither explicit mode can fix it — each leaves the
    /// other script alone — and Mixed will not, because the two are not distinguishable by
    /// spelling shape.
    func test_swap_all_fixes_a_sentence_mistyped_in_both_directions() {
        // `vtwiot` is อะไรนะ on the US layout; `เพฟิ` is "grab" on the Thai one.
        let input = "vtwiot \u{0E40}\u{0E1E}\u{0E1F}\u{0E34} sinv0twxi5g,]N"
        XCTAssertEqual(convert(input, .swapAll), "อะไรนะ grab หรือจะไปรถเมล์")
    }

    /// Each run goes the way its own script implies, so the two directions happen in one pass.
    func test_swap_all_sends_each_run_the_way_its_script_implies() {
        XCTAssertEqual(convert("l;ylfu", .swapAll), "สวัสดี")
        XCTAssertEqual(convert("สวัสดี", .swapAll), "l;ylfu")
        XCTAssertEqual(convert("l;ylfu สวัสดี", .swapAll), "สวัสดี l;ylfu")
    }

    /// It is mechanical, so it converts correct text too. That is the deal: the user supplies the
    /// judgement the gate cannot, and Mixed remains the mode that spares things.
    func test_swap_all_does_not_spare_correct_text() {
        XCTAssertEqual(convert("ครับ", .swapAll), "8iy[")
        XCTAssertEqual(convert("ครับ", .mixed), "ครับ")
    }

    /// Neutral runs are on no layout, so there is no direction to send them in.
    func test_swap_all_passes_through_what_is_on_no_layout() {
        XCTAssertEqual(convert("  \n\t", .swapAll), "  \n\t")
        XCTAssertEqual(convert("🐈 é", .swapAll), "🐈 é")
    }

    func test_swap_all_has_no_opposite_to_swap_to() {
        XCTAssertEqual(ConversionMode.swapAll.swapped, .swapAll)
        XCTAssertFalse(ConversionMode.swapAll.hasDirection)
        XCTAssertFalse(ConversionMode.mixed.hasDirection)
        XCTAssertTrue(ConversionMode.englishToThai.hasDirection)
    }

    // MARK: - Scale

    /// PLAN.md asks for conversion to stay visually immediate at 100,000 characters, since the
    /// output is recomputed on every keystroke.
    func test_converts_one_hundred_thousand_characters_quickly() {
        // Counted in scalars, not Characters: Thai combining marks fuse, so `.count` understates
        // how much text the converter actually walks.
        let input = String(repeating: "l;ylfu ้ำสสน ครับ 2024 :) ", count: 5_000)
        XCTAssertGreaterThan(input.unicodeScalars.count, 100_000)

        let start = Date()
        let output = convert(input, .mixed)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertFalse(output.isEmpty)
        XCTAssertLessThan(elapsed, 1.0, "mixed conversion of 100k characters took \(elapsed)s")
    }
}
