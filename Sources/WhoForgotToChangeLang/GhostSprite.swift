import Foundation

/// The mascot's pixel grid: a small ghost.
///
/// A ghost because it is what the app is about — the wrong layout haunting your sentence.
///
/// **One colour, features cut out of it**, the same construction Tama uses: a solid silhouette
/// with the eyes as holes that let the panel show through.
///
/// Legend: `Y` body · `.` empty
///
/// Proportions follow the reference art (`icon.png` in the repository root). Each note below is a
/// correction to an attempt that looked wrong:
///
/// - **Narrow vertical eyes, one pixel wide.** Three-by-three blocks read as goggles, two-by-two
///   as a surprised stare. Slits read as a face.
/// - **No mouth.** At this size a mouth is either a slab or a nose, and both are worse than
///   nothing — Tama's cat carries its whole expression in two small holes, and so does this.
/// - **A crown that tapers in single steps**, then near-vertical sides. A square ghost reads as a
///   rounded hill.
/// - **Wide tails, narrow slits.** Gaps wider than the lobes turn the hem into piano keys.
/// - **Sixteen wide.** Small enough to sit inline at *native* pixel size, which matters more than
///   detail — see `GhostView` on why the sprite is never scaled.
enum GhostSprite {
    static let columns = 16
    static let rowCount = 16

    private static let dome = [
        ".....YYYYYY.....",
        "...YYYYYYYYYY...",
        "..YYYYYYYYYYYY..",
        ".YYYYYYYYYYYYYY.",
        ".YYYYYYYYYYYYYY.",
        "YYYYYYYYYYYYYYYY",
        "YYYYYYYYYYYYYYYY",
    ]

    /// Body, then the tails.
    ///
    /// **Three wide lobes, one-pixel slits.** Two earlier hems read as piano keys: first
    /// two-pixel tails with three-pixel gaps (a comb), then four narrower tails, which was still
    /// too many prongs across sixteen pixels. Fewer and wider is what reads as cloth. The last row
    /// drops the outer corners so the hem is rounded rather than flat-bottomed — the other half of
    /// what made it look like keys.
    private static let hem = [
        "YYYYYYYYYYYYYYYY",
        "YYYYYYYYYYYYYYYY",
        "YYYYYYYYYYYYYYYY",
        "YYYYYYYYYYYYYYYY",
        "YYYYY.YYYY.YYYYY",
        ".YYYY.YYYY.YYYY.",
    ]

    enum Eyes {
        /// One pixel wide, three tall.
        case open
        /// Shut — a short dash, for the blink and for the contented look after a copy.
        case shut

        var rows: [String] {
            switch self {
            case .open:
                return ["YYYY.YYYYYY.YYYY",
                        "YYYY.YYYYYY.YYYY",
                        "YYYY.YYYYYY.YYYY"]
            case .shut:
                return ["YYYYYYYYYYYYYYYY",
                        "YYY...YYYY...YYY",
                        "YYYYYYYYYYYYYYYY"]
            }
        }
    }

    static func rows(eyes: Eyes) -> [String] {
        dome + eyes.rows + hem
    }
}
