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
/// - **Deep tails**: two rows at full gap width, or the hem reads as serration.
/// - **Sixteen wide.** Small enough to sit inline at *native* pixel size, which matters more than
///   detail — see `GhostView` on why the sprite is never scaled.
enum GhostSprite {
    static let columns = 16
    static let rowCount = 17

    private static let dome = [
        ".....YYYYYY.....",
        "...YYYYYYYYYY...",
        "..YYYYYYYYYYYY..",
        ".YYYYYYYYYYYYYY.",
        ".YYYYYYYYYYYYYY.",
        "YYYYYYYYYYYYYYYY",
        "YYYYYYYYYYYYYYYY",
    ]

    /// Body, then the tails. The gaps widen as they descend so the hem reads as four rounded
    /// lobes rather than as teeth.
    private static let hem = [
        "YYYYYYYYYYYYYYYY",
        "YYYYYYYYYYYYYYYY",
        "YYYYYYYYYYYYYYYY",
        "YYYYYYYYYYYYYYYY",
        "YYY.YYYY.YYYY.YY",
        "YY...YY...YY...Y",
        "YY...YY...YY...Y",
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
