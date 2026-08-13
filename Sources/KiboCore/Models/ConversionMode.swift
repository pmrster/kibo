import Foundation

/// How to interpret the text the user handed us.
///
/// Three of the four are mechanical: every mapped character is flipped, no questions asked.
/// `mixed` is the one that judges — see `KeyboardConverter` — so the other three double as the
/// escape hatch for when that judgement is wrong.
/// **Declaration order is the order of the picker**, since the control is built from `allCases`,
/// and it also sets the ⌘1–⌘4 shortcuts. It runs most-used first — a UI decision living in Core
/// only because `CaseIterable` puts it here.
public enum ConversionMode: String, CaseIterable, Sendable {
    /// Flip **every** run, each in the direction implied by the script it is already in — Thai
    /// runs back to English, Latin runs to Thai — without consulting the gate.
    ///
    /// This exists because text can be mistyped in *both* directions at once: switch layout
    /// halfway through a sentence and half of it is Thai-on-QWERTY while the other half is
    /// English-on-Kedmanee. Neither explicit direction can fix that, since each leaves the other
    /// script alone, and Mixed will not, because telling the two apart by spelling shape is
    /// measurably impossible — 36% of English words flip to well-formed Thai. Here the user
    /// supplies the judgement the gate cannot, so there is nothing left to guess wrong.
    case swapAll
    /// Treat the whole string as English keystrokes typed with the Thai layout active.
    case englishToThai
    /// Treat the whole string as Thai keystrokes typed with the US layout active.
    case thaiToEnglish
    /// Convert each run only if it is malformed in its own script; leave correct text alone.
    case mixed

    /// What the converter opens in when nothing is remembered — a fresh install, or a stored value
    /// that no longer parses.
    ///
    /// One constant rather than a literal at each of the three sites that need it, so the answer
    /// cannot be changed in two of them. It is deliberately **not** derived from `allCases.first`:
    /// the picker order is presentation and may be reshuffled again, while this is behaviour.
    ///
    /// `swapAll` rather than the safer `mixed`, by explicit product decision. It converts correct
    /// text, so a first-time user who pastes something already right will see it mangled — the
    /// trade is that the mode which always does *something* beats one that silently does nothing,
    /// and the result field is a preview the user reads before copying. Anyone who has used the
    /// app before is unaffected: `lastMode` is what they get.
    public static let `default`: ConversionMode = .swapAll

    /// The opposite explicit direction. `mixed` and `swapAll` are direction-symmetric and return
    /// themselves, so a Swap control can call this unconditionally.
    public var swapped: ConversionMode {
        switch self {
        case .mixed: return .mixed
        case .englishToThai: return .thaiToEnglish
        case .thaiToEnglish: return .englishToThai
        case .swapAll: return .swapAll
        }
    }

    /// Whether the mode has an opposite for a Swap control to flip to.
    public var hasDirection: Bool { swapped != self }
}
