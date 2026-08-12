import SwiftUI
import WhoForgotToChangeLangCore

/// The mascot — a mango 8-bit cat, sibling to Tama's yellow one.
///
/// Same technique as `tama-widget`'s `PetView`: a character grid rasterised into two `Path`s and
/// drawn in a `Canvas`, so there is no image asset to manage or to get wrong at 2x. Built once as
/// static paths rather than per frame, because this redraws on a timer.
///
/// It reacts to the converter rather than wandering: blinking quietly with nothing to do, breathing
/// a single pixel once there is a result, eyes shut and content just after a copy. The speech
/// bubble shows which way the text is being pushed.
struct CatView: View {

    enum Mood: Equatable {
        /// Nothing typed yet.
        case idle
        /// There is a result on screen.
        case alert
        /// Just copied.
        case happy
    }

    let mood: Mood
    let mode: ConversionMode

    private nonisolated static let px: CGFloat = 1.6
    private nonisolated static let columns = CatSprite.columns
    private nonisolated static let rows = CatSprite.rows

    // Pixel legend:  Y = mango body   E = dark eyes / nose   . = empty

    private struct Sprite {
        let body: Path
        let dark: Path
    }

    private nonisolated static let restingSprite = makeSprite(CatSprite.resting)
    private nonisolated static let blinkSprite = makeSprite(CatSprite.restingEyesClosed)

    var body: some View {
        let width = CGFloat(Self.columns) * Self.px
        let height = CGFloat(Self.rows) * Self.px

        HStack(alignment: .center, spacing: 4) {
            TimelineView(.periodic(from: .now, by: 0.45)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, _ in
                    let sprite = sprite(at: time)
                    context.fill(sprite.body, with: .color(Palette.mango))
                    context.fill(sprite.dark, with: .color(Palette.catFeature))
                }
                .frame(width: width, height: height)
                .offset(y: bob(at: time))
            }
            bubble
        }
        // The cat is decoration; the state it reflects is already announced by the result field.
        .accessibilityHidden(true)
    }

    /// Which pose to draw. Blinking is derived from the clock rather than stored, so there is no
    /// animation state to keep in sync with the model.
    private func sprite(at time: Double) -> Sprite {
        switch mood {
        case .happy:
            // Eyes shut and content — it just did the thing you asked.
            return Self.blinkSprite
        case .idle, .alert:
            // A blink roughly every four seconds, lasting one tick.
            let blinking = time.truncatingRemainder(dividingBy: 4.0) < 0.45
            return blinking ? Self.blinkSprite : Self.restingSprite
        }
    }

    /// A single pixel of breathing while there is a result on screen. Enough to notice in the
    /// corner of the eye, not enough to compete with the text beside it.
    private func bob(at time: Double) -> CGFloat {
        guard mood == .alert else { return 0 }
        return time.truncatingRemainder(dividingBy: 1.8) < 0.9 ? 0 : -1
    }

    /// The little speech bubble: which script the text is being pushed towards.
    @ViewBuilder private var bubble: some View {
        let label: String = {
            switch mood {
            case .happy: return "✓"
            case .idle, .alert:
                switch mode {
                case .mixed: return "ก⇄A"
                case .englishToThai: return "ก"
                case .thaiToEnglish: return "A"
                }
            }
        }()

        Text(label)
            .font(AppFont.thai(8, weight: .bold))
            .foregroundStyle(mood == .happy ? Palette.green : Palette.mango)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                (mood == .happy ? Palette.green : Palette.mango).opacity(0.14),
                in: RoundedRectangle(cornerRadius: 4)
            )
    }

    private nonisolated static func makeSprite(_ grid: [String]) -> Sprite {
        var body = Path()
        var dark = Path()
        for (row, line) in grid.enumerated() {
            for (column, character) in line.enumerated() {
                // The 0.35 overdraw closes the hairline seams that otherwise show between
                // adjacent pixels when the canvas lands on a fractional scale factor.
                let rect = CGRect(x: CGFloat(column) * px,
                                  y: CGFloat(row) * px,
                                  width: px + 0.35,
                                  height: px + 0.35)
                switch character {
                case "Y": body.addRect(rect)
                case "E": dark.addRect(rect)
                default: continue
                }
            }
        }
        return Sprite(body: body, dark: dark)
    }
}
