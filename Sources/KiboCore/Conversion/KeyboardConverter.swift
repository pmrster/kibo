import Foundation

/// The whole conversion domain, behind one call.
///
/// Callers — the menu-bar UI, the tests, and one day a Windows port — know only this. Mapping
/// tables, run splitting, and the orthography gate stay on the other side of it, so any of them
/// can change without a caller noticing.
public protocol KeyboardConverting: Sendable {
    func convert(_ input: String, mode: ConversionMode) -> ConversionResult
}

/// Pure, deterministic, synchronous. No clipboard, no persistence, no SwiftUI, no clock — the
/// same input and mode always produce the same output, which is what lets the fixtures in
/// `Fixtures/conversion-cases.json` serve as a portable contract for other implementations.
public struct KeyboardConverter: KeyboardConverting {

    public init() {}

    public func convert(_ input: String, mode: ConversionMode) -> ConversionResult {
        let output: String
        switch mode {
        case .englishToThai:
            output = mapEveryScalar(input, using: thai(forQwerty:))
        case .thaiToEnglish:
            output = mapEveryScalar(input, using: KedmaneeMapping.qwerty(forThai:))
        case .mixed:
            output = convertMixed(input)
        }
        return ConversionResult(input: input, output: output, mode: mode)
    }

    /// The QWERTY → Thai lookup, with one fallback the raw table does not have: if the scalar is
    /// a character macOS substituted for a keystroke (`’` for `'`, `—` for `-`), convert the key
    /// that was actually pressed. Without it a typed apostrophe reached here as U+2019, matched
    /// nothing, and `ง` could not be produced at all.
    ///
    /// Only the outbound direction folds, and only at the moment a scalar is being converted —
    /// text this converter decides to leave alone keeps its curls, because straightening the
    /// user's punctuation would be a change to text the app promised not to touch.
    private func thai(forQwerty scalar: UnicodeScalar) -> UnicodeScalar? {
        if let mapped = KedmaneeMapping.thai(forQwerty: scalar) { return mapped }
        guard let key = TypographicSubstitutes.asciiKey(for: scalar) else { return nil }
        return KedmaneeMapping.thai(forQwerty: key)
    }

    /// Mechanical whole-string conversion. Anything the table has no entry for is copied over
    /// untouched rather than dropped — whitespace, emoji, other scripts, and text already in the
    /// destination script all survive.
    private func mapEveryScalar(_ input: String,
                                using lookup: (UnicodeScalar) -> UnicodeScalar?) -> String {
        var output = String.UnicodeScalarView()
        output.reserveCapacity(input.unicodeScalars.count)
        for scalar in input.unicodeScalars {
            output.append(lookup(scalar) ?? scalar)
        }
        return String(output)
    }

    /// Split into runs, ask `RunJudge` about each, and convert only the ones it condemns. Each
    /// run is converted in the direction implied by the script it is currently in: Thai wreckage
    /// goes back to English, Latin wreckage goes to Thai.
    private func convertMixed(_ input: String) -> String {
        var output = ""
        output.reserveCapacity(input.count)
        for run in RunSplitter.split(input) {
            guard RunJudge.shouldConvert(run) else {
                output += run.text
                continue
            }
            switch run.script {
            case .thai:
                output += mapEveryScalar(run.text, using: KedmaneeMapping.qwerty(forThai:))
            case .latin:
                output += mapEveryScalar(run.text, using: thai(forQwerty:))
            case .neutral:
                // `RunJudge` never condemns a neutral run; handled for exhaustiveness.
                output += run.text
            }
        }
        return output
    }
}
