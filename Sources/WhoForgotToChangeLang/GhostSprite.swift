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
/// three tones fighting inside 20×16 pixels. A silhouette has one job and does it.
///
/// Legend: `Y` body · `.` empty
///
/// **Why the peekaboo is done by occlusion.** Three attempts drew the ghost covering its face with
/// its own paws, and at this resolution every one read as spectacles — an outlined square over a
/// face is a *lens*, not a hand. Hiding the ghost behind the input field and letting it rise
/// reads instantly, needs no hand pixels, and makes the field part of the joke.
enum GhostSprite {
    static let columns = 16

    /// Dome and shoulders. Narrower and taller than the first mono attempt, which was 20 wide by
    /// 16 and read as a rounded hill rather than a ghost — a ghost needs to be taller than it is
    /// broad, with a hem you can actually see.
    private static let dome = [
        "....YYYYYYYY....",
        "..YYYYYYYYYYYY..",
        ".YYYYYYYYYYYYYY.",
        "YYYYYYYYYYYYYYYY",
        "YYYYYYYYYYYYYYYY",
        "YYYYYYYYYYYYYYYY",
        "YYYYYYYYYYYYYYYY",
    ]

    /// Body, then two rows of scallop. The gaps widen as they go down so the hem reads as three
    /// rounded tails rather than as teeth.
    private static let hem = [
        "YYYYYYYYYYYYYYYY",
        "YYYYYYYYYYYYYYYY",
        "YYYYYYYYYYYYYYYY",
        "YYYY..YYYY..YYYY",
        "YYY....YY....YYY",
    ]

    enum Eyes {
        /// Ordinary, while it waits.
        case open
        /// Blinking, and the contented look after a copy.
        case shut
        /// Wide — it has spotted a result.
        case wide

        var rows: [String] {
            switch self {
            case .open:
                return ["YY...YYYYYY...YY",
                        "YY...YYYYYY...YY"]
            case .shut:
                return ["YYYYYYYYYYYYYYYY",
                        "YY...YYYYYY...YY"]
            case .wide:
                return ["YY...YYYYYY...YY",
                        "YY...YYYYYY...YY"]
            }
        }
    }

    enum Mouth {
        /// Closed.
        case line
        /// Open, as when it pops up.
        case small
        /// Small and pleased.
        case round

        var rows: [String] {
            switch self {
            case .line:
                return ["YYYYYYYYYYYYYYYY",
                        "YYYYYY....YYYYYY",
                        "YYYYYYYYYYYYYYYY"]
            case .small:
                return ["YYYYYY....YYYYYY",
                        "YYYYYY....YYYYYY",
                        "YYYYYYYYYYYYYYYY"]
            case .round:
                return ["YYYYYYYYYYYYYYYY",
                        "YYYYYYY..YYYYYYY",
                        "YYYYYYYYYYYYYYYY"]
            }
        }
    }

    static func rows(eyes: Eyes, mouth: Mouth) -> [String] {
        dome + eyes.rows + mouth.rows + hem
    }

    /// 7 dome + 2 eyes + 3 mouth + 5 hem.
    static let rowCount = 17
}
