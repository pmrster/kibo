import Foundation

/// How to interpret the text the user handed us.
///
/// Three of the four are mechanical: every mapped character is flipped, no questions asked.
/// `mixed` is the one that judges — see `KeyboardConverter` — so the other three double as the
/// escape hatch for when that judgement is wrong.
public enum ConversionMode: String, CaseIterable, Sendable {
    /// Convert each run only if it is malformed in its own script; leave correct text alone.
    case mixed
    /// Treat the whole string as English keystrokes typed with the Thai layout active.
    case englishToThai
    /// Treat the whole string as Thai keystrokes typed with the US layout active.
    case thaiToEnglish
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
