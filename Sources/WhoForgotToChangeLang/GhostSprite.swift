import Foundation

/// The mascot's pixel grids: a small ghost, assembled from interchangeable bands so the
/// expression can change without redrawing the body.
///
/// A ghost because it is what the app is about — the wrong layout haunting your sentence — and
/// because "boo" is a peekaboo joke a converter can act out.
///
/// **One colour, features cut out of it**, the same construction Tama uses: a solid silhouette
/// with the eyes and mouth as holes that let the panel show through. An earlier version drew the
/// ghost with a contrasting outline and a yellow mouth and it read as cluttered at this size —
/// three tones fighting inside a 16-pixel sprite.
///
/// Proportions follow `icon.png`, the reference art in the repository root. Four things in it
/// carry the character, and earlier attempts missed all four:
///
/// - **Taller than wide** (20 × 22, not 16 × 17). A squat ghost reads as a rounded hill.
/// - **A dome that tapers**, narrow at the crown and widening in single steps.
/// - **Round eyes**, three by three — rectangles read as a visor.
/// - **A tiny smile and deep scalloped tails.** The mouth is four pixels, not a slab, and the
///   tails hang far enough to be unmistakable.
///
/// Legend: `Y` body · `.` empty
///
/// **Why the peekaboo is done by occlusion.** Three attempts drew the ghost covering its face with
/// its own paws, and at this resolution every one read as spectacles — an outlined square over a
/// face is a *lens*, not a hand. Hiding the ghost behind the input field and letting it rise
/// reads instantly, needs no hand pixels, and makes the field part of the joke.
enum GhostSprite {
    static let columns = 20

    /// The crown, tapering out in single steps.
    private static let dome = [
        "........YYYY........",
        "......YYYYYYYY......",
        ".....YYYYYYYYYY.....",
        "....YYYYYYYYYYYY....",
        "...YYYYYYYYYYYYYY...",
        "..YYYYYYYYYYYYYYYY..",
        "..YYYYYYYYYYYYYYYY..",
        ".YYYYYYYYYYYYYYYYYY.",
        ".YYYYYYYYYYYYYYYYYY.",
    ]

    /// Body, then the tails. The gaps widen as they descend so the hem reads as four rounded
    /// lobes rather than as teeth.
    private static let hem = [
        "YYYYYYYYYYYYYYYYYYYY",
        "YYYYYYYYYYYYYYYYYYYY",
        "YYYYYYYYYYYYYYYYYYYY",
        "YYYYY.YYYY.YYYY.YYYY",
        "YYYY...YY...YY...YYY",
        "YYYY...YY...YY...YYY",
    ]

    enum Eyes {
        /// Ordinary — three by three, so they read as round rather than as a slot.
        case open
        /// Blinking, and the contented look after a copy.
        case shut

        var rows: [String] {
            switch self {
            case .open:
                return [".YYY...YYYYYY...YYY.",
                        ".YYY...YYYYYY...YYY.",
                        ".YYY...YYYYYY...YYY."]
            case .shut:
                return [".YYYYYYYYYYYYYYYYYY.",
                        ".YYY...YYYYYY...YYY.",
                        ".YYYYYYYYYYYYYYYYYY."]
            }
        }
    }

    /// A four-pixel smile, and the only expression the mouth has.
    ///
    /// The reference art wears one face, and copying that is the point: a second mouth shape was
    /// tried for the risen state and at 2×2 it read as a nose, not as surprise. The moods are
    /// carried by where the ghost is and whether its eyes are shut — which is plenty.
    /// Held at the same width as the dome above it. Letting these rows run the full twenty
    /// columns put a step in the silhouette level with the mouth, which made the ghost look like
    /// it had shoulders; the body should not widen until the hem.
    private static let mouth = [
        ".YYYYYYYYYYYYYYYYYY.",
        ".YYYYYYY.YY.YYYYYYY.",
        ".YYYYYYYY..YYYYYYYY.",
    ]

    static func rows(eyes: Eyes) -> [String] {
        dome + eyes.rows + mouth + hem
    }

    /// 9 dome + 3 eyes + 3 mouth + 6 hem.
    static let rowCount = 21
}
