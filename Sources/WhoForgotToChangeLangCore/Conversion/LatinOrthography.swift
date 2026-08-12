import Foundation

/// The mirror of `ThaiOrthography`: decides whether an ASCII run reads as English, or as Thai
/// typed with the US layout active.
///
/// Thai typed on QWERTY produces long consonant pile-ups and stray keyboard punctuation, because
/// Thai's consonant-heavy words land on whatever ASCII keys the Kedmanee layout assigns them.
/// Those two signals carry most of the weight here.
enum LatinOrthography {

    private static func isLetter(_ scalar: UnicodeScalar) -> Bool {
        (0x41...0x5A).contains(scalar.value) || (0x61...0x7A).contains(scalar.value)
    }

    /// `y` counts. It carries English syllables that have no other vowel — `rhythm`, `by` — and
    /// excluding it would flag them as wreckage.
    private static func isVowel(_ scalar: UnicodeScalar) -> Bool {
        "aeiouyAEIOUY".unicodeScalars.contains(scalar)
    }

    /// Characters that never appear inside an English word but are ordinary Kedmanee keys.
    /// `;` is the `ว` key — which is the whole reason `l;ylfu` is Thai in disguise.
    ///
    /// Deliberately just the one character. `[`, `]` and `\` are also Kedmanee keys (`บ`, `ล`,
    /// `ฃ`), but they are far more common in ordinary text than they are useful here — including
    /// them converted `array[i]` and `C:\Users\alice` into Thai. `'` is absent for the same reason:
    /// it is the `ง` key, but it is also how English writes `don't`.
    private static let keyboardOnly: Set<UnicodeScalar> = [";"]

    /// Below this many letters there is not enough signal to call a run mistyped, and guessing
    /// wrong would mangle ordinary acronyms like `PM` and `TV`.
    private static let minimumLettersToJudge = 3

    /// The vowel rule needs a long word before it can be trusted, because English is full of
    /// short vowel-less strings that are not mistypings: `npm`, `nth`, `html`, `https`. Six is
    /// where it stopped producing false positives.
    private static let minimumLettersForVowelRule = 6

    /// English does not stack this many consonants without a vowel. Set so that `https` (five)
    /// survives and `vpkddbodkca` (six, from `อยากกินกาแฟ`) does not.
    private static let maximumConsonantRun = 5

    /// True when the run reads as ordinary English text and should be left exactly as typed.
    ///
    /// Runs with fewer than `minimumLettersToJudge` letters always come back `true` — there is
    /// nothing here to judge. That is not the same as "leave it alone": `RunJudge` has a second,
    /// narrower test for those, because Thai consonants map onto digits and punctuation often
    /// enough that a mistyped Thai word can arrive with barely a letter in it.
    static func isWellFormed(_ text: String) -> Bool {
        let scalars = Array(text.unicodeScalars)
        let letters = scalars.filter(isLetter)

        // Nothing to judge — this is what keeps `2024` and `:)` intact.
        guard letters.count >= minimumLettersToJudge else { return true }

        // A keyboard-only character wedged between two letters gives the mistyping away.
        for (index, scalar) in scalars.enumerated() where keyboardOnly.contains(scalar) {
            let letterBefore = index > 0 && isLetter(scalars[index - 1])
            let letterAfter = index + 1 < scalars.count && isLetter(scalars[index + 1])
            if letterBefore && letterAfter { return false }
        }

        // Both remaining rules are applied per letter-group rather than across the whole run,
        // because punctuation genuinely interrupts a word. Measured end to end, `index.html`
        // reads as `indexhtml` — a phantom consonant pile-up that exists only because the dot was
        // deleted first.
        for group in letterGroups(scalars) {
            // An all-caps group is an acronym, not a mistyping. Without this, `HTML`, `SQL`,
            // `PDF` and `SMS` were all converted into Thai — they have no vowels, which is
            // normal for an acronym and damning for a word.
            if group.allSatisfy(isUppercase) { continue }

            if group.count >= minimumLettersForVowelRule, !group.contains(where: isVowel) {
                return false
            }

            var consonantRun = 0
            for letter in group {
                consonantRun = isVowel(letter) ? 0 : consonantRun + 1
                if consonantRun > maximumConsonantRun { return false }
            }
        }
        return true
    }

    private static func isUppercase(_ scalar: UnicodeScalar) -> Bool {
        (0x41...0x5A).contains(scalar.value)
    }

    /// Maximal stretches of letters, with everything else acting as a separator.
    private static func letterGroups(_ scalars: [UnicodeScalar]) -> [[UnicodeScalar]] {
        var groups: [[UnicodeScalar]] = []
        var current: [UnicodeScalar] = []
        for scalar in scalars {
            if isLetter(scalar) {
                current.append(scalar)
            } else if !current.isEmpty {
                groups.append(current)
                current = []
            }
        }
        if !current.isEmpty { groups.append(current) }
        return groups
    }

    /// Whether `isWellFormed` had to abstain on this run for want of letters — in which case its
    /// `true` means "no opinion", not "leave it alone", and `RunJudge` should apply its own test.
    ///
    /// Phrased as a question rather than exposing the letter count and the threshold separately,
    /// so the rule for what counts as "too few" stays here with the rest of the English shape
    /// rules instead of being reassembled by the caller.
    static func hasTooFewLettersToJudge(_ text: String) -> Bool {
        text.unicodeScalars.filter(isLetter).count < minimumLettersToJudge
    }
}
