import XCTest
@testable import KiboCore

@MainActor
final class ConverterModelTests: XCTestCase {

    private func makeModel(mode: ConversionMode = .mixed)
        -> (ConverterModel, InMemoryClipboard) {
        let clipboard = InMemoryClipboard()
        return (ConverterModel(mode: mode, clipboard: clipboard), clipboard)
    }

    // MARK: - Output

    func test_starts_empty() {
        let (model, _) = makeModel()
        XCTAssertEqual(model.input, "")
        XCTAssertEqual(model.output, "")
        XCTAssertFalse(model.didCopy)
    }

    func test_output_updates_when_input_changes() {
        let (model, _) = makeModel(mode: .englishToThai)
        model.input = "l;ylfu"
        XCTAssertEqual(model.output, "สวัสดี")
    }

    func test_output_updates_when_mode_changes() {
        let (model, _) = makeModel(mode: .englishToThai)
        model.input = "ครับ"
        XCTAssertEqual(model.output, "ครับ", "no QWERTY keys to map")

        model.mode = .thaiToEnglish
        XCTAssertEqual(model.output, "8iy[")
    }

    func test_mixed_judges_each_run() {
        let (model, _) = makeModel()
        XCTAssertEqual(model.mode, .mixed)
        model.input = "l;ylfu ้ำสสน ครับ 2024 :)"
        XCTAssertEqual(model.output, "สวัสดี hello ครับ 2024 :)")
    }

    // MARK: - Actions

    func test_swap_exchanges_the_explicit_directions() {
        let (model, _) = makeModel(mode: .englishToThai)
        model.swapDirection()
        XCTAssertEqual(model.mode, .thaiToEnglish)
        model.swapDirection()
        XCTAssertEqual(model.mode, .englishToThai)
    }

    /// Mixed has no opposite, so Swap is a no-op rather than an error or a silent jump into one
    /// of the explicit modes.
    func test_swap_leaves_mixed_alone() {
        let (model, _) = makeModel(mode: .mixed)
        model.swapDirection()
        XCTAssertEqual(model.mode, .mixed)
    }

    func test_clear_resets_input_and_output() {
        let (model, _) = makeModel(mode: .englishToThai)
        model.input = "l;ylfu"
        model.clear()
        XCTAssertEqual(model.input, "")
        XCTAssertEqual(model.output, "")
    }

    // MARK: - Clipboard

    func test_paste_reads_the_clipboard_into_the_input() {
        let (model, clipboard) = makeModel(mode: .englishToThai)
        clipboard.contents = "l;ylfu"
        model.paste()
        XCTAssertEqual(model.input, "l;ylfu")
        XCTAssertEqual(model.output, "สวัสดี")
    }

    func test_paste_with_an_empty_clipboard_leaves_the_input_alone() {
        let (model, clipboard) = makeModel()
        model.input = "keep me"
        clipboard.contents = nil
        model.paste()
        XCTAssertEqual(model.input, "keep me")
    }

    func test_copy_writes_the_output_not_the_input() {
        let (model, clipboard) = makeModel(mode: .englishToThai)
        model.input = "l;ylfu"
        model.copyOutput()
        XCTAssertEqual(clipboard.contents, "สวัสดี")
    }

    func test_copy_with_empty_output_does_not_touch_the_clipboard() {
        let (model, clipboard) = makeModel()
        clipboard.contents = "untouched"
        model.copyOutput()
        XCTAssertEqual(clipboard.contents, "untouched")
        XCTAssertEqual(clipboard.writes, 0)
        XCTAssertFalse(model.didCopy)
    }

    // MARK: - The privacy invariant

    /// SPEC.md and AGENTS.md both promise the clipboard is read only on an explicit Paste and
    /// written only on an explicit Copy. Typing, switching modes, swapping, and clearing must all
    /// leave it untouched — this is the test that would catch a convenience feature breaking that.
    func test_clipboard_is_untouched_by_everything_except_paste_and_copy() {
        let (model, clipboard) = makeModel()
        model.input = "l;ylfu"
        model.mode = .englishToThai
        model.swapDirection()
        model.clear()
        model.input = "ไำะ"
        _ = model.output

        XCTAssertEqual(clipboard.reads, 0, "something read the clipboard without a Paste")
        XCTAssertEqual(clipboard.writes, 0, "something wrote the clipboard without a Copy")

        model.paste()
        XCTAssertEqual(clipboard.reads, 1)
        XCTAssertEqual(clipboard.writes, 0)

        model.input = "l;ylfu"
        model.copyOutput()
        XCTAssertEqual(clipboard.reads, 1)
        XCTAssertEqual(clipboard.writes, 1)
    }

    // MARK: - Copy confirmation

    func test_copy_raises_the_confirmation_flag() {
        let (model, _) = makeModel(mode: .englishToThai)
        model.input = "l;ylfu"
        XCTAssertFalse(model.didCopy)
        model.copyOutput()
        XCTAssertTrue(model.didCopy)
    }

    /// The confirmation refers to what was on screen when it was pressed, so any change that
    /// makes it stale must retract it.
    func test_confirmation_is_retracted_when_the_result_changes() {
        let (model, _) = makeModel(mode: .englishToThai)
        model.input = "l;ylfu"
        model.copyOutput()

        model.input = "vpkddbodkca"
        XCTAssertFalse(model.didCopy, "editing the input left a stale 'copied' confirmation")

        model.copyOutput()
        model.mode = .thaiToEnglish
        XCTAssertFalse(model.didCopy, "switching modes left a stale 'copied' confirmation")

        model.copyOutput()
        model.clear()
        XCTAssertFalse(model.didCopy, "clearing left a stale 'copied' confirmation")
    }

    // MARK: - Remembering the mode

    /// "Reopen in the mode you left it in" used to be a `.onChange` on the mode picker in the
    /// SwiftUI shell, where nothing could test it and a Windows port would have had to find it by
    /// reading view code. These four tests are what moving it into Core bought.

    func test_opens_in_the_remembered_mode() {
        let memory = InMemoryModeMemory(mode: .thaiToEnglish)
        let model = ConverterModel(clipboard: InMemoryClipboard(), memory: memory)
        XCTAssertEqual(model.mode, .thaiToEnglish)
    }

    /// Spelled `.swapAll` rather than `.default`, which would assert nothing. A first launch
    /// landing in the mode that converts *everything* is a product decision, so changing it should
    /// have to come through here.
    func test_opens_in_both_when_there_is_nothing_to_remember() {
        let model = ConverterModel(clipboard: InMemoryClipboard())
        XCTAssertEqual(model.mode, .swapAll)
        XCTAssertEqual(model.mode, .default)
    }

    func test_changing_the_mode_remembers_it() {
        let memory = InMemoryModeMemory(mode: .mixed)
        let model = ConverterModel(clipboard: InMemoryClipboard(), memory: memory)

        model.mode = .englishToThai
        XCTAssertEqual(memory.mode, .englishToThai)

        model.swapDirection()
        XCTAssertEqual(memory.mode, .thaiToEnglish, "swapping is a mode change and must persist too")
        XCTAssertEqual(memory.saves, 2, "the mode was saved more often than it changed")
    }

    /// Typing is not a mode change. Without this, every keystroke would write to `UserDefaults`.
    func test_editing_the_input_never_touches_the_mode_memory() {
        let memory = InMemoryModeMemory()
        let model = ConverterModel(clipboard: InMemoryClipboard(), memory: memory)

        model.input = "l;ylfu"
        model.input = "hello"
        model.clear()
        model.copyOutput()

        XCTAssertEqual(memory.saves, 0)
    }
}
