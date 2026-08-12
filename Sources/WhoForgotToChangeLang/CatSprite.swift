import Foundation

/// The mascot's pixel grids, kept apart from `CatView` so the poses can be read as data.
///
/// Note the menu-bar glyph is deliberately *not* built from these — see `MenuBarIcon` for why a
/// cat silhouette turned out to be unusable next to Tama in a real menu bar.
///
/// Geometry is shared with Tama's `PetView` — a side-view cat, ears and tail reading against the
/// background rather than notched out of a silhouette. A first attempt drew a head-on cat at 18x14
/// and it rendered as an anonymous blob: at this scale a shape has to be profiled, not implied.
/// Reusing the proven geometry is the point of the fork; only the palette differs.
///
/// Legend:  `Y` = body   `E` = eyes and nose   `.` = empty
enum CatSprite {
    static let columns = 24
    static let rows = 15

    /// Sitting, tail low.
    static let resting = [
        "........................",
        "...........YY.....YY....",
        "..........YYYY...YYYY...",
        "..........YYYYYYYYYYY...",
        ".........YYYYYYYYYYYYY..",
        ".........YYYYYYYYYYYYY..",
        "..YY.....YYYYEYYYYYEYY..",
        "..YYY...YYYYYEYYYYYEYY..",
        "...YYYYYYYYYYEYYEYYEYY..",
        "....YYYYYYYYYYYYYYYYYY..",
        "......YYYYYYYYYYYYYYYY..",
        "......YYYYYYYYYYYYYYY...",
        "......YYYYYYYYYYYYYY....",
        "......YYYYYYYYYYYYYY....",
        "......YY..YYY.YY..Y.....",
    ]

    /// Same pose with the eyes shut — the idle blink, and the post-copy smile.
    static let restingEyesClosed = [
        "........................",
        "...........YY.....YY....",
        "..........YYYY...YYYY...",
        "..........YYYYYYYYYYY...",
        ".........YYYYYYYYYYYYY..",
        ".........YYYYYYYYYYYYY..",
        "..YY.....YYYYYYYYYYYYY..",
        "..YYY...YYYYEEEYYYEEEY..",
        "...YYYYYYYYYYYYYYYYYYY..",
        "....YYYYYYYYYYYYYYYYYY..",
        "......YYYYYYYYYYYYYYYY..",
        "......YYYYYYYYYYYYYYY...",
        "......YYYYYYYYYYYYYY....",
        "......YYYYYYYYYYYYYY....",
        "......YY..YYY.YY..Y.....",
    ]

    // There is deliberately no walking pose. Tama's mid-stride frame was tried for an `alert`
    // mood and reads as a glitch when held static — the raised tail detaches into a floating blob
    // and the body loses a chunk to the stride. It works there because it is one frame of a loop.
    // Here the cat sits beside a text field, where a looping animation would pull the eye off the
    // thing the user is reading.
}
