import Foundation

/// A maximal stretch of one kind of text. Mixed mode judges and converts one run at a time, so
/// where the boundaries fall decides what gets judged together.
struct Run: Equatable, Sendable {
    enum Script: Sendable {
        /// Thai script.
        case thai
        /// Printable ASCII — letters, digits, and punctuation alike.
        case latin
        /// Everything else. Never converted, never judged, passed through exactly.
        case neutral
    }

    let script: Script
    let text: String

    init(script: Script, text: String) {
        self.script = script
        self.text = text
    }
}

/// Splits text into maximal same-script runs.
enum RunSplitter {

    /// ASCII punctuation stays *inside* the Latin run rather than being treated as neutral, and
    /// that is deliberate: `;` is the `ว` key, so pulling it out would break `l;ylfu` → `สวัสดี`.
    /// The cost is that a run like `2024` is nominally "Latin"; `LatinOrthography` is what keeps
    /// it from being converted.
    ///
    /// Space is excluded from the Latin range on purpose. It makes whitespace a run boundary, so
    /// two words either side of a space are judged separately instead of as one blob.
    private static func script(of scalar: UnicodeScalar) -> Run.Script {
        switch scalar.value {
        case 0x0E00...0x0E7F: return .thai
        case 0x21...0x7E: return .latin
        default: return .neutral
        }
    }

    /// Runs always rejoin to the input exactly — nothing is dropped, reordered, or normalised.
    static func split(_ input: String) -> [Run] {
        var runs: [Run] = []
        var current = String.UnicodeScalarView()
        var currentScript: Run.Script?

        for scalar in input.unicodeScalars {
            let scalarScript = script(of: scalar)
            if scalarScript != currentScript, currentScript != nil {
                runs.append(Run(script: currentScript!, text: String(current)))
                current = String.UnicodeScalarView()
            }
            currentScript = scalarScript
            current.append(scalar)
        }
        if let currentScript {
            runs.append(Run(script: currentScript, text: String(current)))
        }
        return runs
    }
}
