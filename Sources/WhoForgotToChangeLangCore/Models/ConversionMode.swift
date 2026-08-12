import Foundation

/// How to interpret the text the user handed us.
///
/// The two explicit directions are mechanical: every mapped character is flipped, no questions
/// asked. `mixed` is the one that judges — see `KeyboardConverter` — so the explicit modes double
/// as the escape hatch for when that judgement is wrong.
public enum ConversionMode: String, CaseIterable, Sendable {
    /// Convert each run only if it is malformed in its own script; leave correct text alone.
    case mixed
    /// Treat the whole string as English keystrokes typed with the Thai layout active.
    case englishToThai
    /// Treat the whole string as Thai keystrokes typed with the US layout active.
    case thaiToEnglish

    /// The opposite explicit direction. `mixed` has no opposite and returns itself, so a Swap
    /// control can call this unconditionally.
    public var swapped: ConversionMode {
        switch self {
        case .mixed: return .mixed
        case .englishToThai: return .thaiToEnglish
        case .thaiToEnglish: return .englishToThai
        }
    }
}
