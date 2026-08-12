import Foundation

/// The mascot's pixel grids: a small ghost, assembled from interchangeable bands so the
/// expression can change without redrawing the body.
///
/// A ghost because it is what the app is about — the wrong layout haunting your sentence — and
/// because "boo" is a peekaboo joke that a converter can actually act out. It is original art,
/// unlike the first mascot, which borrowed Tama's cat sprite and looked it: scaled up in the About
/// window that geometry is visibly built for a 24×15 menu-bar pet, not for display.
///
/// Legend: `#` ink and outline · `o` body · `y` mouth · `.` empty
///
/// **Why the peekaboo is done by occlusion.** Three attempts drew the ghost covering its face with
/// its own paws, and at this resolution every one of them read as spectacles — an outlined square
/// over a face is a *lens*, not a hand, and no amount of reshaping fixed it. Hiding the ghost
/// behind the input field instead and letting it rise reads instantly, needs no hand pixels, and
/// makes the field itself part of the joke.
enum GhostSprite {
    static let columns = 20

    private static let dome = [
        "......########......",
        "....##oooooooo##....",
        "...#oooooooooooo#...",
        "..#oooooooooooooo#..",
        ".#oooooooooooooooo#.",
        ".#oooooooooooooooo#.",
    ]

    private static let hem = [
        "#oooooooooooooooooo#",
        ".#oooooooooooooooo#.",
        "..##ooo##oo##ooo##..",
        "....###..##..###....",
    ]

    enum Eyes {
        /// Ordinary. Used while it waits.
        case open
        /// Blinking, and also the contented look after a copy.
        case shut
        /// Wide — it has spotted a result.
        case wide

        var rows: [String] {
            switch self {
            case .open:
                return ["#oooooooooooooooooo#",
                        "#ooo##oooooooo##ooo#",
                        "#ooo##oooooooo##ooo#",
                        "#oooooooooooooooooo#"]
            case .shut:
                return ["#oooooooooooooooooo#",
                        "#oooooooooooooooooo#",
                        "#ooo##oooooooo##ooo#",
                        "#oooooooooooooooooo#"]
            case .wide:
                return ["#oooooooooooooooooo#",
                        "#ooo###oooooo###ooo#",
                        "#ooo###oooooo###ooo#",
                        "#oooooooooooooooooo#"]
            }
        }
    }

    enum Mouth {
        /// Closed — a plain line.
        case line
        /// A small open mouth.
        case small
        /// Rounder and happier.
        case round

        var rows: [String] {
            switch self {
            case .line:
                return ["#oooooooooooooooooo#",
                        "#ooooo########ooooo#",
                        "#oooooooooooooooooo#"]
            case .small:
                return ["#ooooo########ooooo#",
                        "#ooooo#yyyyyy#ooooo#",
                        "#ooooo########ooooo#"]
            case .round:
                return ["#ooooooo####ooooooo#",
                        "#ooooooo#yy#ooooooo#",
                        "#ooooooo####ooooooo#"]
            }
        }
    }

    static func rows(eyes: Eyes, mouth: Mouth) -> [String] {
        dome + eyes.rows + mouth.rows + hem
    }

    /// Total rows in an assembled sprite: 6 dome + 4 eyes + 3 mouth + 4 hem.
    static let rowCount = 17
}
