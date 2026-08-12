import AppKit
import KiboCore

/// The real clipboard, via `NSPasteboard`.
///
/// This type exists only inside the shell because `NSPasteboard` is AppKit and Core holds no
/// AppKit. It is also the only code in the app that touches the pasteboard at all — there is no
/// polling, no change-count observation, and no clipboard history. `ConverterModel` calls `read`
/// from Paste and `write` from Copy, and nothing else calls either.
@MainActor
struct SystemClipboard: Clipboard {

    /// The two community-standard pasteboard markers (nspasteboard.org). Clipboard managers —
    /// Raycast, Maccy, Paste, Alfred — honour them: *Concealed* means "this is a secret, do not
    /// record it", *Transient* means "do not keep it".
    ///
    /// Kibo sets both on every Copy, and that is not defensive over-caution: the app's whole use
    /// case is text typed with the wrong layout, which routinely means a password. Without these
    /// markers a Copy lands in every clipboard history on the machine, and macOS Universal
    /// Clipboard also hands `NSPasteboard.general` to nearby Apple devices — the one way a
    /// local-only app can still put a secret on the air. Nothing here can stop Universal
    /// Clipboard, but a marked item is what tells the rest of the system to treat it as a secret.
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    func read() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    func write(_ text: String) {
        // One item carrying all three types, so the markers cannot be separated from the string
        // they describe. Writing requires clearing first; without it the new value is appended to
        // whatever types are already on the pasteboard and the paste target may pick the stale one.
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setData(Data(), forType: Self.concealedType)
        item.setData(Data(), forType: Self.transientType)

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }
}
