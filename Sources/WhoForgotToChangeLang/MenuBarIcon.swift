import AppKit

/// The menu-bar glyph: a small pixel keyboard, drawn as a template image so it adapts to light and
/// dark menu bars automatically.
///
/// Same technique as Tama's pixel cat — a character grid rasterised at run time — which keeps the
/// family resemblance and means there is no image asset to manage or to get wrong at 2x.
enum MenuBarIcon {
    private static let keyboard = [
        "XXXXXXXXXXXXXX",
        "X............X",
        "X.XX.XX.XX.X.X",
        "X............X",
        "X.X.XX.XX.XX.X",
        "X............X",
        "X..XXXXXXXX..X",
        "X............X",
        "XXXXXXXXXXXXXX",
    ]

    static func image(pixelSize: CGFloat = 1.3) -> NSImage {
        let grid = keyboard
        let columns = grid[0].count
        let rows = grid.count
        let image = NSImage(size: NSSize(width: CGFloat(columns) * pixelSize,
                                         height: CGFloat(rows) * pixelSize))
        image.lockFocus()
        NSColor.black.setFill()
        for (row, line) in grid.enumerated() {
            for (column, character) in line.enumerated() where character == "X" {
                // NSImage's origin is bottom-left, so the row index is flipped.
                NSRect(x: CGFloat(column) * pixelSize,
                       y: CGFloat(rows - 1 - row) * pixelSize,
                       width: pixelSize,
                       height: pixelSize).fill()
            }
        }
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
