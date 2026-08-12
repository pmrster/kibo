import SwiftUI

/// **Kibo**, the mascot: a small ghost that perches on the top edge of the input field, tails
/// tucked behind it. Says "boo~", as Tama's cat says "meow~".
///
/// **Never scale this view.** It is drawn from a pixel grid into a `Canvas`, so a `scaleEffect`
/// rasterises at the natural size and then stretches the result — which is what made the ghost
/// look broken and jagged next to Tama's crisp cat. To show it larger, pass a larger
/// `pixelSize`; every rectangle then lands on a whole pixel and the edges stay sharp. Tama does
/// the same thing, and that is the entire difference.
struct KiboView: View {

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

    /// Shows Kibo's "boo~" beside the sprite. Off by default: in the converter it appears only on
    /// a copy, so it stays a small reward rather than constant chatter next to a text field.
    var isSpeaking = false

    var body: some View {
        let width = CGFloat(KiboSprite.columns) * pixelSize
        let height = CGFloat(KiboSprite.rowCount) * pixelSize

        TimelineView(.periodic(from: .now, by: 0.4)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, _ in
                context.fill(Self.path(eyes: eyes(at: time), pixelSize: pixelSize),
                             with: .color(Palette.kibo))
            }
            .frame(width: width, height: height)
            .offset(y: float(at: time))
        }
        .frame(width: width, height: height)
        .overlay(alignment: .leading) {
            if isSpeaking {
                Text("boo~")
                    .font(.system(size: max(8, pixelSize * 2.2), weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.kibo)
                    .fixedSize()
                    // Placed to the left because in the converter Kibo sits at the right edge,
                    // where anything to its right would run off the panel. A plain offset, not an
                    // alignment guide — the guide pulled the text back across the sprite.
                    .offset(x: -(pixelSize * 9), y: -height * 0.24)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: isSpeaking)
        // Decoration: everything it reflects is already announced by the result field.
        .accessibilityHidden(true)
    }

    private func eyes(at time: Double) -> KiboSprite.Eyes {
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
    private static func path(eyes: KiboSprite.Eyes, pixelSize: CGFloat) -> Path {
        let key = "\(eyes)-\(pixelSize)"
        if let cached = cache[key] { return cached }

        var path = Path()
        for (row, line) in KiboSprite.rows(eyes: eyes).enumerated() {
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
