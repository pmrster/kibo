import AppKit
import KiboCore

/// The macOS Service: select mistyped text in any app, right-click → Services → **Fix Layout with
/// Kibo**, and the selection is replaced in place. Declared under `NSServices` in
/// `Packaging/Info.plist`, which is also what lets the system launch Kibo on demand when it is
/// not running.
///
/// It converts in whatever mode the popover's picker is set to — one control for both paths,
/// and the default (Both) means it always does *something*. There is no preview on this path,
/// so the safety net is the host app's own Undo.
///
/// **Privacy.** The text arrives on a private pasteboard the system creates for this one
/// invocation — not `NSPasteboard.general`, so neither clipboard managers nor Universal
/// Clipboard ever see it — and it is read only because the user picked the menu item. The
/// general clipboard is not touched; `ConverterModel.convert(_:)` is tested for exactly that.
///
/// Only a real `.app` bundle in `/Applications` registers Services; `swift run` cannot.
@MainActor
final class ConversionService: NSObject {
    private let model: ConverterModel

    init(model: ConverterModel) {
        self.model = model
    }

    /// The selector named by `NSMessage` in the plist. AppKit calls it on the main thread with
    /// the selection already on `pasteboard`; whatever is on it when this returns replaces the
    /// selection, because the service declares an `NSReturnTypes`.
    @objc func fixLayout(_ pasteboard: NSPasteboard,
                         userData: String?,
                         error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            error.pointee = "Kibo: the selection contains no text."
            return
        }
        let converted = model.convert(text)
        pasteboard.clearContents()
        pasteboard.setString(converted, forType: .string)
    }
}
