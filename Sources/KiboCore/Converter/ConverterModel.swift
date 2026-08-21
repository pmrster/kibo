import Foundation

/// The converter window's state and behaviour.
///
/// It lives in Core rather than in the SwiftUI shell because it is logic, and logic is what this
/// target holds — which is also what makes it testable without a running app. It owns no mapping
/// rules of its own; it asks `KeyboardConverting` and reports the answer.
@MainActor
@Observable
public final class ConverterModel {

    /// What the user typed or pasted.
    public var input: String = "" {
        didSet { refresh() }
    }

    /// Which question we are asking of it. Remembered across launches, when a `ModeMemory` was
    /// supplied — the rule lives here rather than in the view that happens to draw the picker.
    public var mode: ConversionMode {
        didSet {
            refresh()
            memory?.saveMode(mode)
        }
    }

    /// The converted text. Recomputed when the input or mode changes rather than on every read,
    /// since SwiftUI may read it several times per frame and the input can run to 100k characters.
    public private(set) var output: String = ""

    /// Whether the Copy confirmation should be showing. Retracted automatically as soon as the
    /// result changes, so the confirmation can never refer to text that is no longer on screen.
    public private(set) var didCopy = false

    private let converter: any KeyboardConverting
    private let clipboard: any Clipboard
    private let memory: (any ModeMemory)?

    /// - Parameters:
    ///   - mode: the mode to open in. Omit it to open in the remembered mode, or in
    ///     `ConversionMode.default` when there is no memory to consult.
    ///   - memory: where the mode is remembered. Optional because most tests do not care, and the
    ///     model must work without persistence.
    public init(mode: ConversionMode? = nil,
                converter: any KeyboardConverting = KeyboardConverter(),
                clipboard: any Clipboard,
                memory: (any ModeMemory)? = nil) {
        self.mode = mode ?? memory?.loadMode() ?? .default
        self.converter = converter
        self.clipboard = clipboard
        self.memory = memory
    }

    // MARK: - Actions

    /// Swaps the two explicit directions. Mixed has no opposite, so this leaves it as it is
    /// rather than picking one arbitrarily.
    public func swapDirection() {
        mode = mode.swapped
    }

    public func clear() {
        input = ""
    }

    /// The only place this app reads the clipboard. An empty or non-text clipboard leaves the
    /// input alone — silently blanking what the user typed would be worse than doing nothing.
    public func paste() {
        guard let text = clipboard.read(), !text.isEmpty else { return }
        input = text
    }

    /// The only place this app writes the clipboard. Writes the *result*, never the input, and
    /// does nothing when there is no result to write.
    public func copyOutput() {
        guard !output.isEmpty else { return }
        clipboard.write(output)
        didCopy = true
    }

    /// Lets the shell retract the confirmation on a timer without reaching into private state.
    public func dismissCopyConfirmation() {
        didCopy = false
    }

    /// Converts text that did not come through the input field — the macOS Service, where the
    /// user selects text in another app and asks for it fixed in place.
    ///
    /// It uses the mode the converter is currently set to, so the picker in the popover is the
    /// one control for both paths, and it deliberately bypasses `input`: the field in the popover
    /// belongs to whatever the user was working on there, and a conversion that happened in
    /// another app must not overwrite it. Nor does it go near the clipboard — a Service carries
    /// its text on a private pasteboard the system provides, which is what keeps this path off
    /// clipboard managers and Universal Clipboard.
    public func convert(_ text: String) -> String {
        converter.convert(text, mode: mode).output
    }

    private func refresh() {
        output = converter.convert(input, mode: mode).output
        didCopy = false
    }
}
