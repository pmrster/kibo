import Foundation

/// Decides whether a Thai run is real Thai or the wreckage of typing English with the Thai layout
/// active — without a dictionary.
///
/// Thai spelling has hard structural rules, and typing English on the Thai layout breaks them
/// almost immediately: the resulting characters are drawn from wherever the English letters
/// happen to sit, so vowel marks land with no consonant to attach to. That is a far cheaper
/// signal than word lookup, and it needs no word segmentation — which matters, because written
/// Thai has no spaces, so `สวัสดีครับ` arrives as a single run.
///
/// **What it cannot do.** It judges spelling shape, not meaning. Wreckage that happens to be
/// well-formed passes through unchanged — `แนกำ` ("code" mistyped) breaks no rule, and `นา`
/// ("ok" mistyped) is a real Thai word. `ThaiOrthographyTests` pins both as known limitations.
/// The explicit TH → EN mode is the escape hatch.
enum ThaiOrthography {

    /// ก through ฮ. `ฤ` and `ฦ` sit in this range and are treated as consonants here: they are
    /// independent letters that a following mark may legitimately attach to.
    private static func isConsonant(_ scalar: UnicodeScalar) -> Bool {
        (0x0E01...0x0E2E).contains(scalar.value)
    }

    /// เ แ โ ใ ไ — written *before* the consonant they belong to.
    private static func isLeadingVowel(_ scalar: UnicodeScalar) -> Bool {
        (0x0E40...0x0E44).contains(scalar.value)
    }

    /// Vowels and tone marks that must follow a consonant, whether they combine with it
    /// (`ั ิ ี ึ ื ุ ู ่ ้ ๊ ๋ ์ ํ`) or merely sit after it (`ะ า ำ ๅ`).
    private static func isFollowingMark(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0x0E30...0x0E3A, 0x0E45, 0x0E47...0x0E4E: return true
        default: return false
        }
    }

    /// Whether the text carries any Thai vowel or tone mark. Used by `RunJudge` to tell Thai
    /// words from incidental strings of Thai consonants and digits — real Thai spells vowels,
    /// so a "Thai" string with none of them is usually punctuation that happened to map across.
    static func containsFollowingMark(_ text: String) -> Bool {
        text.unicodeScalars.contains(where: isFollowingMark)
    }

    /// Whether every scalar is in the Thai block.
    static func isEntirelyThaiScript(_ text: String) -> Bool {
        !text.isEmpty && text.unicodeScalars.allSatisfy { (0x0E00...0x0E7F).contains($0.value) }
    }

    /// True when the run breaks none of Thai's structural spelling rules. Empty runs are
    /// vacuously well-formed. Characters that stand on their own — Thai digits, `฿`, `ๆ`, `ฯ` —
    /// need no consonant and simply end any pending attachment.
    static func isWellFormed(_ text: String) -> Bool {
        let scalars = Array(text.unicodeScalars)
        // Whether a consonant is available for a following mark to attach to. Marks keep it
        // available (a consonant can carry a vowel *and* a tone mark); anything else clears it.
        var hasBase = false
        var previousMark: UnicodeScalar?

        for (index, scalar) in scalars.enumerated() {
            if isConsonant(scalar) {
                hasBase = true
                previousMark = nil
            } else if isLeadingVowel(scalar) {
                // Rule: a leading vowel must be followed by a consonant — including not being
                // the last character in the run.
                guard index + 1 < scalars.count, isConsonant(scalars[index + 1]) else { return false }
                hasBase = false
                previousMark = nil
            } else if isFollowingMark(scalar) {
                // Rule: a mark needs a consonant earlier in the run.
                guard hasBase else { return false }
                // Rule: the same mark twice in a row is never correct.
                guard scalar != previousMark else { return false }
                previousMark = scalar
            } else {
                // Standalone: digits, currency, repetition and abbreviation marks.
                hasBase = false
                previousMark = nil
            }
        }
        return true
    }
}
