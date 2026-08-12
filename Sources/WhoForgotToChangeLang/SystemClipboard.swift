import AppKit
import WhoForgotToChangeLangCore

/// The real clipboard, via `NSPasteboard`.
///
/// This type exists only inside the shell because `NSPasteboard` is AppKit and Core holds no
/// AppKit. It is also the only code in the app that touches the pasteboard at all — there is no
/// polling, no change-count observation, and no clipboard history. `ConverterModel` calls `read`
/// from Paste and `write` from Copy, and nothing else calls either.
@MainActor
struct SystemClipboard: Clipboard {

    func read() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    func write(_ text: String) {
        let pasteboard = NSPasteboard.general
        // Writing requires clearing first; without it the new value is appended to whatever
        // types are already on the pasteboard and the paste target may pick the stale one.
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
