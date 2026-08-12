import AppKit

/// The menu-bar glyph: the mascot's silhouette, drawn as a template image so macOS tints it for
/// light and dark menu bars automatically.
///
/// Flattened from the same grid `CatView` draws (`CatSprite.resting`), with the eyes filled in
/// rather than punched out. A silhouette is the right form at menu-bar size — a first attempt
/// kept the eyes as holes and the result read as a bat rather than a cat — and sharing the grid
/// means the glyph and the mascot cannot drift apart.
enum MenuBarIcon {

    static func image(pixelSize: CGFloat = 1.15) -> NSImage {
        let grid = CatSprite.resting
        let columns = CatSprite.columns
        let rows = CatSprite.rows
        let image = NSImage(size: NSSize(width: CGFloat(columns) * pixelSize,
                                         height: CGFloat(rows) * pixelSize))
        image.lockFocus()
        NSColor.black.setFill()
        for (row, line) in grid.enumerated() {
            for (column, character) in line.enumerated() where character != "." {
                // NSImage's origin is bottom-left, so the row index is flipped. The 0.3 overdraw
                // closes hairline seams between adjacent pixels at fractional scale factors.
                NSRect(x: CGFloat(column) * pixelSize,
                       y: CGFloat(rows - 1 - row) * pixelSize,
                       width: pixelSize + 0.3,
                       height: pixelSize + 0.3).fill()
            }
        }
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
