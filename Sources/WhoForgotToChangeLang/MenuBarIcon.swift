import AppKit

/// The menu-bar glyph: Kibo's silhouette, drawn as a template image so macOS tints it for light
/// and dark menu bars automatically.
///
/// **This is the mascot, and that is only safe because Kibo is a ghost.** The glyph's job up there
/// is to identify the app, and an earlier version — a cat silhouette, from when the mascot was
/// forked from Tama's sprite — failed at exactly that: sitting beside Tama in a real menu bar, two
/// side-view pixel cats are indistinguishable at 18px, so neither icon said which app it was. A
/// ghost next to a cat has no such problem, so the mascot can do both jobs again.
///
/// The eyes stay as holes rather than being filled in. A template image keeps alpha, so they
/// survive the tinting, and they are what stops the shape reading as a plain blob at this size.
enum MenuBarIcon {

    /// Whole pixels only, for the same reason `KiboView` is never scaled: a fractional size puts
    /// the sprite's edges between device pixels and the glyph comes out soft. One point per sprite
    /// pixel gives a 16×16 glyph, which sits comfortably in the ~18pt the menu bar allows.
    private static let pixelSize: CGFloat = 1

    static func image() -> NSImage {
        let grid = KiboSprite.rows(eyes: .open)
        let rows = KiboSprite.rowCount
        let size = NSSize(width: CGFloat(KiboSprite.columns) * pixelSize,
                          height: CGFloat(rows) * pixelSize)

        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.black.setFill()
        for (row, line) in grid.enumerated() {
            // NSImage's origin is bottom-left, so the row index is flipped.
            let y = CGFloat(rows - 1 - row) * pixelSize
            for (column, character) in line.enumerated() where character == "Y" {
                NSRect(x: CGFloat(column) * pixelSize, y: y,
                       width: pixelSize, height: pixelSize).fill()
            }
        }
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
