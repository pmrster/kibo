import SwiftUI
import WhoForgotToChangeLangCore

/// The mascot: a small ghost that hides behind the input field and peeks over the top of it.
///
/// Drawn from `GhostSprite` into a `Canvas`, so there is no image asset to manage or to get wrong
/// at 2x. The peekaboo is done by sliding the sprite down and clipping it — see `GhostSprite` for
/// why drawing it covering its own eyes did not work — which means the view must be laid out
/// directly above whatever it is meant to be hiding behind.
struct GhostView: View {

    enum Mood: Equatable {
        /// Nothing typed yet: only the top of its head shows.
        case waiting
        /// A result is on screen: it rises fully into view.
        case risen
        /// Just copied: risen, eyes shut, pleased with itself.
        case pleased
    }

    let mood: Mood

    private static let px: CGFloat = 2.0
    private static let width = CGFloat(GhostSprite.columns) * px
    private static let height = CGFloat(GhostSprite.rowCount) * px

    /// How far down the sprite sits while waiting.
    ///
    /// Both eye rows have to clear the edge or the whole joke dies: at nine rows only the dome
    /// showed and it read as a bump, not as something looking at you. Seven leaves the eyes fully
    /// visible with the mouth still hidden, which is the pose that reads as peeking.
    private static let hiddenDrop: CGFloat = 7 * px

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.4)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, _ in
                let paths = paths(at: time)
                context.fill(paths.body, with: .color(Palette.ghostBody))
                context.fill(paths.ink, with: .color(Palette.ghostInk))
                context.fill(paths.mouth, with: .color(Palette.ghostMouth))
            }
            .frame(width: Self.width, height: Self.height)
            .offset(y: drop(at: time))
        }
        // Clipped to its own frame so the part that has slid down is hidden, which is what makes
        // it look like it is behind the field below rather than sinking into the background.
        .frame(width: Self.width, height: Self.height, alignment: .top)
        .clipped()
        .animation(.easeOut(duration: 0.22), value: mood)
        // Decoration: the state it mirrors is already announced by the result field.
        .accessibilityHidden(true)
    }

    private func drop(at time: Double) -> CGFloat {
        switch mood {
        case .waiting:
            // A slow float, so it looks like it is hovering rather than stuck to the edge.
            let bob: CGFloat = time.truncatingRemainder(dividingBy: 3.2) < 1.6 ? 0 : -1
            return Self.hiddenDrop + bob
        case .risen, .pleased:
            return 0
        }
    }

    private struct Paths {
        var body = Path()
        var ink = Path()
        var mouth = Path()
    }

    private func paths(at time: Double) -> Paths {
        let eyes: GhostSprite.Eyes
        let mouth: GhostSprite.Mouth
        switch mood {
        case .waiting:
            // Blinks about every four seconds, for one tick.
            let blinking = time.truncatingRemainder(dividingBy: 4.0) < 0.4
            eyes = blinking ? .shut : .open
            mouth = .line
        case .risen:
            eyes = .wide
            mouth = .small
        case .pleased:
            eyes = .shut
            mouth = .round
        }
        return Self.build(GhostSprite.rows(eyes: eyes, mouth: mouth))
    }

    /// Rasterises a grid into three paths, one per colour. Cached per (eyes, mouth) pair, since
    /// this runs on every timeline tick and there are only nine possible combinations.
    private static func build(_ grid: [String]) -> Paths {
        if let cached = cache[grid.joined()] { return cached }
        var paths = Paths()
        for (row, line) in grid.enumerated() {
            for (column, character) in line.enumerated() {
                // The 0.3 overdraw closes hairline seams between adjacent pixels at fractional
                // scale factors.
                let rect = CGRect(x: CGFloat(column) * px,
                                  y: CGFloat(row) * px,
                                  width: px + 0.3,
                                  height: px + 0.3)
                switch character {
                case "o": paths.body.addRect(rect)
                case "#": paths.ink.addRect(rect)
                case "y": paths.mouth.addRect(rect)
                default: continue
                }
            }
        }
        cache[grid.joined()] = paths
        return paths
    }

    @MainActor private static var cache: [String: Paths] = [:]
}
