import Foundation

/// The system clipboard, narrowed to the two operations this app is allowed to perform.
///
/// The interface is this small on purpose. SPEC.md promises the clipboard is read only when the
/// user presses Paste and written only when they press Copy, and a two-method protocol makes that
/// promise auditable: `ConverterModelTests` counts the calls and fails if anything else reaches
/// for it. There is no "watch the clipboard" method to accidentally start using.
@MainActor
public protocol Clipboard {
    /// The clipboard's current text, or `nil` when it holds nothing readable as text.
    func read() -> String?
    func write(_ text: String)
}

/// A clipboard that lives in memory, for tests. Counts accesses so the privacy invariant can be
/// asserted rather than assumed.
@MainActor
public final class InMemoryClipboard: Clipboard {
    public var contents: String?
    public private(set) var reads = 0
    public private(set) var writes = 0

    public init(contents: String? = nil) {
        self.contents = contents
    }

    public func read() -> String? {
        reads += 1
        return contents
    }

    public func write(_ text: String) {
        writes += 1
        contents = text
    }
}
