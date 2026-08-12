import AppKit

/// The menu-bar glyph: a keycap outline with `ก` on it, drawn as a template image so macOS tints
/// it for light and dark menu bars automatically.
///
/// **Deliberately not the mascot.** The first version was the cat silhouette, which looked right
/// on its own and turned out to be unusable in practice: sitting next to Tama — the sibling app
/// this one was forked from — two side-view pixel cats are indistinguishable at 18px, so neither
/// icon told you which app it was. The mascot still appears everywhere inside the app; the menu
/// bar needs a shape that identifies rather than one that matches.
///
/// A bordered box is the distinguishing feature: nothing else in a menu bar has an outline, so it
/// is findable at a glance among a row of filled symbols. It also depicts the thing the user
/// forgot to press.
///
/// Other candidates were rendered at true size and rejected: a pixel-art keycap read as a
/// computer monitor, pixel swap arrows collapsed into a smudge, and `ก⇄A` cost noticeably more
/// menu-bar width than it earned.
enum MenuBarIcon {

    /// Menu-bar icons get about 18pt of height; the rest is padding macOS applies itself.
    private static let height: CGFloat = 18
    private static let letterSize: CGFloat = 11

    static func image() -> NSImage {
        let letter = NSAttributedString(string: "ก", attributes: [
            .font: font(size: letterSize),
            .foregroundColor: NSColor.black,
        ])
        let letterSize = letter.size()
        let width = ceil(letterSize.width) + 9

        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()

        // Inset by half the line width so the stroke lands inside the bitmap rather than being
        // clipped in half along the edges.
        let border = NSBezierPath(
            roundedRect: NSRect(x: 0.75, y: 1.25, width: width - 1.5, height: height - 2.5),
            xRadius: 3.5,
            yRadius: 3.5
        )
        border.lineWidth = 1.5
        NSColor.black.setStroke()
        border.stroke()

        letter.draw(at: NSPoint(x: (width - letterSize.width) / 2,
                                y: (height - letterSize.height) / 2))

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    /// Noto Sans Thai to match the app's Thai text, bolded through the descriptor because the
    /// family has no `-Bold` PostScript name to ask for directly. Falls back to the system font
    /// wherever the family is missing.
    private static func font(size: CGFloat) -> NSFont {
        let systemBold = NSFont.systemFont(ofSize: size, weight: .bold)
        guard let noto = NSFont(name: "Noto Sans Thai", size: size) else { return systemBold }
        let bold = NSFontManager.shared.convert(noto, toHaveTrait: .boldFontMask)
        return bold
    }
}
