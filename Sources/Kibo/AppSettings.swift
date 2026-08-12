import SwiftUI
import AppKit
import Combine
import KiboCore

/// SwiftUI-facing settings: publishes the user's appearance and text-size choices, persists them
/// through `SettingsStore`, and applies appearance app-wide via `NSApp.appearance`.
///
/// This is an `ObservableObject` rather than `@Observable`, unlike `ConverterModel`, and the
/// difference is deliberate. `StatusItemController` is AppKit and needs to *subscribe* to
/// appearance changes — see the `$appearance` sink there — because `NSPopover` does not inherit
/// `NSApp.appearance` and has to be recoloured by hand. Combine gives that for free;
/// `@Observable` would mean hand-rolling change tracking outside SwiftUI. `ConverterModel` has
/// only SwiftUI consumers, so it uses the newer macro.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let store: SettingsStore

    @Published var appearance: Appearance { didSet { store.appearance = appearance; applyAppearance() } }
    @Published var fontSize: FontSize { didSet { store.fontSize = fontSize } }

    init(store: SettingsStore = SettingsStore()) {
        self.store = store
        self.appearance = store.appearance
        self.fontSize = store.fontSize
    }

    var fontScale: Double { fontSize.factor }

    // The last mode used to be proxied through here. It is not a display preference, and this
    // type was only passing the value along to `SettingsStore` — so `ConverterModel` now owns it
    // directly, via `ModeMemory`.

    /// The AppKit appearance for the current setting (nil = follow the OS). Drives both
    /// `NSApp.appearance` and surfaces that don't inherit it (notably `NSPopover`).
    var nsAppearance: NSAppearance? {
        switch appearance {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    /// Force (or clear) the whole app's appearance. Call at launch and on every change.
    func applyAppearance() {
        NSApp.appearance = nsAppearance
    }
}
