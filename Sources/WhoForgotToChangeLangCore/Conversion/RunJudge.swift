import Foundation

/// Decides, for one run, whether Mixed mode should convert it or leave it exactly as typed.
///
/// This is the whole difference between Mixed and the two explicit modes. The explicit modes flip
/// everything; Mixed asks this first, so text that is already correct survives a conversion of the
/// text around it.
enum RunJudge {

    static func shouldConvert(_ run: Run) -> Bool {
        switch run.script {
        case .neutral:
            return false
        case .thai:
            return !ThaiOrthography.isWellFormed(run.text)
        case .latin:
            return !LatinOrthography.isWellFormed(run.text) || readsAsThaiInDisguise(run.text)
        }
    }

    /// The second chance for Latin runs that carry too few letters to judge on English shape.
    ///
    /// Thai consonants sit on digit and punctuation keys as often as on letter keys, so a
    /// perfectly ordinary Thai word can come back looking like line noise: `ขอบคุณ` mistyped is
    /// `-v[86I`, which has two letters in it. There is no English shape to test, so instead we
    /// ask the opposite question — does this turn into convincing Thai?
    ///
    /// Three conditions, all needed, and deliberately strict:
    ///
    /// - **Only when there is no English evidence.** Runs with enough letters are judged on their
    ///   own shape and never reach here. Applying this test to them would convert real words:
    ///   `rhythm` maps to well-formed Thai, and it is not a mistyping.
    /// - **The conversion must be entirely Thai script and well-formed.** `2024` becomes `/จ/ภ`,
    ///   which is half ASCII, so it stays a number.
    /// - **It must contain a vowel or tone mark.** Real Thai spells its vowels. Without this,
    ///   `:)` would become `ซ๗` — two Thai characters that are not a word.
    private static func readsAsThaiInDisguise(_ text: String) -> Bool {
        guard LatinOrthography.hasTooFewLettersToJudge(text),
              text.unicodeScalars.count >= minimumScalarsForDisguiseTest
        else { return false }

        var converted = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            guard let thai = KedmaneeMapping.thai(forQwerty: scalar) else { return false }
            converted.append(thai)
        }
        let candidate = String(converted)

        return ThaiOrthography.isEntirelyThaiScript(candidate)
            && ThaiOrthography.isWellFormed(candidate)
            && ThaiOrthography.containsFollowingMark(candidate)
    }

    /// Below this, a run is too short to carry the evidence — short punctuation like `:)` and
    /// fragments like `a/b` are exactly what we must not touch. Four rather than three because
    /// three-scalar runs produced false positives without catching anything the other rules missed.
    private static let minimumScalarsForDisguiseTest = 4
}
