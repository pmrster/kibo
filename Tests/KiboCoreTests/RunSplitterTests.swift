import XCTest
@testable import KiboCore

final class RunSplitterTests: XCTestCase {

    /// Compact spelling of an expected split, so a case reads as close to the input as possible.
    private func assertSplit(_ input: String,
                             into expected: [(Run.Script, String)],
                             file: StaticString = #filePath, line: UInt = #line) {
        let runs = RunSplitter.split(input)
        XCTAssertEqual(runs.map(\.text), expected.map(\.1), "texts", file: file, line: line)
        XCTAssertEqual(runs.map(\.script), expected.map(\.0), "scripts", file: file, line: line)
    }

    func test_empty_input_produces_no_runs() {
        XCTAssertTrue(RunSplitter.split("").isEmpty)
    }

    func test_single_script_input_is_one_run() {
        assertSplit("hello", into: [(.latin, "hello")])
        assertSplit("สวัสดี", into: [(.thai, "สวัสดี")])
    }

    /// Whitespace is neutral, which is what makes it a run boundary — two Latin words separated
    /// by a space are judged separately rather than as one blob.
    func test_space_separates_runs_and_is_preserved() {
        assertSplit("hello world", into: [
            (.latin, "hello"), (.neutral, " "), (.latin, "world"),
        ])
    }

    func test_the_worked_example_from_the_spec() {
        assertSplit("l;ylfu ้ำสสน ครับ 2024 :)", into: [
            (.latin, "l;ylfu"), (.neutral, " "),
            (.thai, "้ำสสน"), (.neutral, " "),
            (.thai, "ครับ"), (.neutral, " "),
            (.latin, "2024"), (.neutral, " "),
            (.latin, ":)"),
        ])
    }

    /// Punctuation stays inside a Latin run. It has to: `;` is the `ว` key, so dropping it from
    /// the run would break `l;ylfu` → `สวัสดี`.
    func test_ascii_punctuation_belongs_to_the_latin_run() {
        assertSplit("l;ylfu", into: [(.latin, "l;ylfu")])
        assertSplit("don't", into: [(.latin, "don't")])
    }

    func test_script_change_without_whitespace_still_splits() {
        assertSplit("helloสวัสดี", into: [(.latin, "hello"), (.thai, "สวัสดี")])
    }

    /// Anything that is neither Thai nor printable ASCII is neutral and passes through: emoji,
    /// newlines, tabs, and other scripts.
    func test_non_thai_non_ascii_is_neutral() {
        assertSplit("hi🐈there", into: [
            (.latin, "hi"), (.neutral, "🐈"), (.latin, "there"),
        ])
        assertSplit("a\n\tb", into: [
            (.latin, "a"), (.neutral, "\n\t"), (.latin, "b"),
        ])
        assertSplit("café", into: [(.latin, "caf"), (.neutral, "é")])
        assertSplit("日本", into: [(.neutral, "日本")])
    }

    /// Adjacent neutral scalars coalesce rather than producing a run each.
    func test_consecutive_neutrals_form_one_run() {
        assertSplit("a   b", into: [(.latin, "a"), (.neutral, "   "), (.latin, "b")])
    }

    /// Splitting must not lose or reorder anything — the runs always rejoin to the input.
    func test_runs_always_rejoin_to_the_input() {
        let inputs = [
            "", "hello", "สวัสดี", "l;ylfu ้ำสสน ครับ 2024 :)", "hi🐈there",
            "a\n\tb", "café", "日本", "  ", "ๆๆๆ!!!",
        ]
        for input in inputs {
            XCTAssertEqual(RunSplitter.split(input).map(\.text).joined(), input, "input: \(input)")
        }
    }

    /// Thai combining marks must stay attached to the run, not be split off as neutral.
    func test_thai_combining_marks_stay_in_the_thai_run() {
        let runs = RunSplitter.split("ครับ")
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs.first?.text.unicodeScalars.count, 4)
    }
}
