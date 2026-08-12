import SwiftUI

/// The mascot: a small ghost that perches on the top edge of the input field, tails tucked
/// behind it.
///
/// **Never scale this view.** It is drawn from a pixel grid into a `Canvas`, so a `scaleEffect`
/// rasterises at the natural size and then stretches the result — which is what made the ghost
/// look broken and jagged next to Tama's crisp cat. To show it larger, pass a larger
/// `pixelSize`; every rectangle then lands on a whole pixel and the edges stay sharp. Tama does
/// the same thing, and that is the entire difference.
struct GhostView: View {

    enum Mood: Equatable {
        /// Ordinary. Blinks now and then.
        case idle
        /// Just copied — eyes shut, pleased with itself.
        case pleased
    }

    var mood: Mood = .idle

    /// Whole numbers only. See the warning above.
    var pixelSize: CGFloat = 2

    /// How far the caller should overlap this view into the surface below, so the tails tuck
    /// behind its edge rather than the ghost floating above it.
    ///
    /// Two rows, not ten. An earlier version sank most of the ghost behind the field so only its
    /// eyes showed, which raised the obvious question of why the mascot was hiding — it read as
    /// something broken rather than as something perching. The reference art sits *on* the line.
    static func tailTuck(pixelSize: CGFloat = 2) -> CGFloat { 2 * pixelSize }

    var body: some View {
        let width = CGFloat(GhostSprite.columns) * pixelSize
        let height = CGFloat(GhostSprite.rowCount) * pixelSize

        TimelineView(.periodic(from: .now, by: 0.4)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, _ in
                context.fill(Self.path(eyes: eyes(at: time), pixelSize: pixelSize),
                             with: .color(Palette.ghost))
            }
            .frame(width: width, height: height)
            .offset(y: float(at: time))
        }
        .frame(width: width, height: height)
        // Decoration: everything it reflects is already announced by the result field.
        .accessibilityHidden(true)
    }

    private func eyes(at time: Double) -> GhostSprite.Eyes {
        switch mood {
        case .pleased:
            return .shut
        case .idle:
            // A blink roughly every four seconds, lasting one tick.
            return time.truncatingRemainder(dividingBy: 4.0) < 0.4 ? .shut : .open
        }
    }

    /// A single pixel of drift, so it hovers rather than sitting welded to the edge. Whole pixels
    /// only, for the same reason the sprite is never scaled.
    private func float(at time: Double) -> CGFloat {
        time.truncatingRemainder(dividingBy: 3.2) < 1.6 ? 0 : -pixelSize
    }

    /// Rasterises the grid into one silhouette path. Cached per (eyes, pixel size), since this
    /// runs on every timeline tick and there are only a handful of combinations.
    private static func path(eyes: GhostSprite.Eyes, pixelSize: CGFloat) -> Path {
        let key = "\(eyes)-\(pixelSize)"
        if let cached = cache[key] { return cached }

        var path = Path()
        for (row, line) in GhostSprite.rows(eyes: eyes).enumerated() {
            for (column, character) in line.enumerated() where character == "Y" {
                path.addRect(CGRect(x: CGFloat(column) * pixelSize,
                                    y: CGFloat(row) * pixelSize,
                                    width: pixelSize,
                                    height: pixelSize))
            }
        }
        cache[key] = path
        return path
    }

    @MainActor private static var cache: [String: Path] = [:]
}
