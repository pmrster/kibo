import SwiftUI
import AppKit

extension Color {
    /// An appearance-adaptive color: resolves to `light` or `dark` (each `0xRRGGBB`) based on
    /// the view's effective appearance. One `Palette` constant then works in both modes and
    /// re-resolves when the app appearance is forced (see `AppSettings.applyAppearance`).
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: Double((hex >> 16) & 0xFF) / 255.0,
                           green: Double((hex >> 8) & 0xFF) / 255.0,
                           blue: Double(hex & 0xFF) / 255.0,
                           alpha: 1.0)
        })
    }

}

/// The warm sunset palette SPEC.md asks for.
///
/// The neutrals are shared verbatim with Tama, the sibling menu-bar app this one was forked from,
/// so the two read as the same family sitting next to each other in the menu bar. The accent is
/// where they diverge: Tama's yellow becomes mango here, which is enough to tell the two apart at
/// a glance without making them look unrelated.
enum Palette {
    static let panel     = Color(light: 0xF7F4EF, dark: 0x1C1A17)
    static let panelEdge = Color(light: 0xE0DAD0, dark: 0x2A2620)
    static let text      = Color(light: 0x1C1A17, dark: 0xEDE6DC)
    static let dim       = Color(light: 0x6E655C, dark: 0x9A8F84)
    static let track     = Color(light: 0xD8D2C8, dark: 0x3A352E)

    /// The accent. Used for the primary action and for focus, never for whole surfaces.
    static let mango     = Color(light: 0xD1701F, dark: 0xE8823A)
    /// Confirmation — the "copied" state.
    static let green     = Color(light: 0x0E8A6B, dark: 0x10A37F)

    /// Mode tints, used only as small direction indicators.
    static let thai      = Color(light: 0xC2603F, dark: 0xD97757)
    static let latin     = Color(light: 0x3A7BA5, dark: 0x4A8FBF)

    /// The mascot: one colour, and the features are holes cut in it. Midnight on the light panel,
    /// pale on the dark one — always the opposite of what it sits on, since a fixed colour would
    /// have it disappearing in one mode, and a ghost that vanishes is funny exactly once.
    static let ghost = Color(light: 0x1E202C, dark: 0xF2EEE6)

    /// The input and result surfaces. Opaque, not `panelEdge` at 45% as it once was, because the
    /// mascot hides *behind* the input field — a translucent fill would show it through.
    /// These are that former blend, flattened.
    static let fieldFill = Color(light: 0xEDE8E1, dark: 0x221F1B)
}

/// Multiplies a hardcoded point size by the current font-size factor. Reading the shared settings
/// here keeps each call site a one-token change; views that observe `AppSettings.shared`
/// re-evaluate their bodies (and so recompute sizes) when it changes.
@MainActor
func scaled(_ size: CGFloat) -> CGFloat { size * CGFloat(AppSettings.shared.fontScale) }

/// Typography.
///
/// The system font renders Thai through Thonburi, whose vowel marks and tone marks sit tight
/// against the consonant at small sizes — exactly the detail this app asks people to read.
/// Noto Sans Thai spaces them properly, and macOS ships it, so it costs nothing to use and no
/// font has to be bundled (SPEC.md: "Prefer system fonts in the native utility").
enum AppFont {
    /// Resolved once. On a Mac without the family — it is present on macOS 14+, but this is not
    /// worth crashing or looking wrong over — every call quietly falls back to the system font.
    static let thaiFamily: String? = {
        NSFont(name: "Noto Sans Thai", size: 12) != nil ? "Noto Sans Thai" : nil
    }()

    /// For anything that can contain Thai: the input, the result, examples, Thai chrome. Latin
    /// glyphs inside the same string fall back automatically, so mixed text stays consistent.
    @MainActor
    static func thai(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        guard let thaiFamily else { return .system(size: scaled(size), weight: weight) }
        return .custom(thaiFamily, fixedSize: scaled(size)).weight(weight)
    }

    /// For English-only chrome — buttons, section headings. Stays on the system font so the app
    /// still looks native next to every other macOS utility.
    @MainActor
    static func ui(_ size: CGFloat,
                   weight: Font.Weight = .regular,
                   design: Font.Design = .default) -> Font {
        .system(size: scaled(size), weight: weight, design: design)
    }

    /// Space Grotesk, if it is installed. Resolved once.
    ///
    /// **This is not a system font.** It is currently present only in the developer's
    /// `~/Library/Fonts`, so on any other Mac `title` falls back — see the note there. Shipping
    /// the intended look means bundling the face with the app.
    static let titleFamily: String? = {
        NSFont(name: "Space Grotesk", size: 12) != nil ? "Space Grotesk" : nil
    }()

    /// The app's name. Space Grotesk: a grotesque with enough character to not look like every
    /// other utility, and squarer than the rounded weight this started with, which read as a toy.
    ///
    /// Falls back to the system font's condensed black — the closest thing macOS ships, and the
    /// weight this used before Space Grotesk. The fallback is what every machine without the font
    /// installed will actually render, so it has to be a deliberate choice rather than a shrug.
    @MainActor
    static func title(_ size: CGFloat) -> Font {
        if let titleFamily {
            return .custom(titleFamily, fixedSize: scaled(size)).weight(.bold)
        }
        let base = NSFont.systemFont(ofSize: scaled(size), weight: .black)
        guard let condensed = NSFont(
            descriptor: base.fontDescriptor.withSymbolicTraits([.condensed]),
            size: scaled(size)
        ) else {
            return .system(size: scaled(size), weight: .black)
        }
        return Font(condensed)
    }
}
