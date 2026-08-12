import SwiftUI
import WhoForgotToChangeLangCore

/// The mascot: a small ghost that hides behind the input field and peeks over the top of it.
///
/// Drawn from `GhostSprite` into a `Canvas`, so there is no image asset to manage or to get wrong
/// at 2x. See `GhostSprite` for why drawing it covering its own eyes did not work.
///
/// **It does not clip itself.** The hiding is done by the caller overlapping this view into an
/// opaque surface drawn after it, which then paints over the lower part — so the ghost is behind a
/// real edge rather than cut off in mid-air. Clipping was tried first and looked exactly like what
/// it was: a sprite with its bottom sliced off, floating above the field with a gap. That means
/// two obligations on the caller: place it immediately above an opaque surface, and overlap it
/// into that surface by `hiddenExtent`.
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

    /// Set where there is nothing below to hide behind — the About and Settings windows. The
    /// ghost then draws fully inside its own frame instead of lifting clear of an overlap that
    /// does not exist, which is what silently pushed it out of the top of the About window.
    var isStandalone = false

    private static let px: CGFloat = 2.0
    private static let width = CGFloat(GhostSprite.columns) * px
    private static let height = CGFloat(GhostSprite.rowCount) * px

    /// How far the caller must overlap this view into the surface below it. While waiting, exactly
    /// this much of the ghost is covered; rising lifts it clear.
    ///
    /// All three eye rows have to stay above the edge or the whole joke dies — cover them and it
    /// reads as a bump rather than as something looking at you. Ten rows leaves the eyes visible
    /// with the mouth still hidden, which is the pose that reads as peeking.
    static let hiddenExtent: CGFloat = 10 * px

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.4)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, _ in
                context.fill(path(at: time), with: .color(Palette.ghost))
            }
            .frame(width: Self.width, height: Self.height)
            .offset(y: drop(at: time))
        }
        .frame(width: Self.width, height: Self.height, alignment: .top)
        .animation(.easeOut(duration: 0.24), value: mood)
        // Decoration: the state it mirrors is already announced by the result field.
        .accessibilityHidden(true)
    }

    /// Vertical shift. Zero leaves the ghost overlapped into the surface below (peeking); lifting
    /// it by `hiddenExtent` clears that surface entirely (risen).
    private func drop(at time: Double) -> CGFloat {
        switch mood {
        case .waiting:
            // A slow float, so it looks like it is hovering rather than stuck to the edge.
            return time.truncatingRemainder(dividingBy: 3.2) < 1.6 ? 0 : -1
        case .risen, .pleased:
            return isStandalone ? 0 : -Self.hiddenExtent
        }
    }

    private func path(at time: Double) -> Path {
        let eyes: GhostSprite.Eyes
        switch mood {
        case .waiting, .risen:
            // Blinks about every four seconds, for one tick.
            eyes = time.truncatingRemainder(dividingBy: 4.0) < 0.4 ? .shut : .open
        case .pleased:
            eyes = .shut
        }
        return Self.build(GhostSprite.rows(eyes: eyes))
    }

    /// Rasterises a grid into one silhouette path. Cached per (eyes, mouth) pair, since this runs
    /// on every timeline tick and there are only two possible faces.
    private static func build(_ grid: [String]) -> Path {
        if let cached = cache[grid.joined()] { return cached }
        var path = Path()
        for (row, line) in grid.enumerated() {
            for (column, character) in line.enumerated() where character == "Y" {
                // The 0.3 overdraw closes hairline seams between adjacent pixels at fractional
                // scale factors.
                path.addRect(CGRect(x: CGFloat(column) * px,
                                    y: CGFloat(row) * px,
                                    width: px + 0.3,
                                    height: px + 0.3))
            }
        }
        cache[grid.joined()] = path
        return path
    }

    @MainActor private static var cache: [String: Path] = [:]
}
