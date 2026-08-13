import Foundation
@testable import KiboCore

/// The corpora behind the accuracy table in CLAUDE.md, in one place so the table has exactly one
/// source of truth.
///
/// They live here, apart from the tests that read them, because three different files quote these
/// figures at the user — CLAUDE.md, SPEC.md, README.md — and before this existed they quoted
/// three *different* numbers. The English figure was written as "16 of 25" in the docs, "17 of a
/// 26-word sample" in a test comment, and was actually 15 of 24 when measured. Nothing failed,
/// because nothing counted.
///
/// Every list is split into what the gate catches and what it misses, and `MeasuredAccuracyTests`
/// asserts **both directions**. That is the point: a change that raises recall by mangling
/// correct text moves words out of `missed` *and* breaks precision, and both show up as failures.
enum AccuracyCorpus {

    // MARK: - Precision: correct text that Mixed must hand back untouched

    /// SPEC.md: "mangling correct text is a worse failure than leaving a mistyping, because the
    /// user can see and fix the latter." Every string here is text a user might plausibly paste.
    ///
    /// Each group exists because an earlier, more aggressive gate converted it into Thai.
    static let mustSurvive = [
        // Acronyms and vowel-less abbreviations
        "HTML", "XML", "SQL", "PDF", "SMS", "npm", "nth", "PM", "TV", "ok",
        // URLs, paths, filenames, versions
        "https://example.com", "http://example.com", "user@example.com",
        "README.md", "index.html", "C:\\Users\\alice", "v1.2.3", "a/b",
        // Code
        "array[i]", "let x = 1;", "foo(bar)",
        // Ordinary English
        "hello", "world", "rhythm", "don't", "email", "meeting", "thank you",
        // Numbers and punctuation
        "2024", ":)", "3.14", "100%", "42",
        // Correct Thai, including an unsegmented phrase
        "ครับ", "สวัสดีครับ", "ขอบคุณมาก",
    ]

    // MARK: - Recall: English typed while the Thai layout was active

    /// Caught because the wreckage breaks a Thai spelling rule outright — usually a leading letter
    /// that maps to a vowel mark, leaving it with no consonant to attach to.
    ///
    /// The `-ture` group is caught by a different rule: `t` is `ะ` and `u` is `ี`, so the ending
    /// lands a combining vowel straight after a spacing one, which no Thai syllable does.
    static let englishCaught = [
        "email", "meeting", "hello", "thanks", "update", "when", "the", "you",
        "project", "review", "design", "test", "build", "morning", "today",
        "feature", "picture", "future", "nature",
    ]

    /// Missed, and unfixable without a dictionary. These words are made only of letters that map
    /// to Thai consonants, so the wreckage is orthographically perfect Thai — `แนกำ` ("code")
    /// breaks no rule, and `นา` ("ok") is a real Thai word meaning a rice field, so not even a
    /// dictionary would rescue it. The escape hatch is the explicit TH → EN mode.
    ///
    /// `value` and `issue` are here to keep the `-ture` group honest. All six words in that family
    /// were measured together when the spacing-vowel rule was added, and these two were the ones
    /// it did not rescue — adding only the four that it did would have inflated the figure.
    static let englishMissed = [
        "about", "please", "sorry", "code", "ok", "and", "report", "great", "work",
        "value", "issue",
    ]

    // MARK: - Recall: Thai typed while the US layout was active

    /// Caught on English shape (`สวัสดี` lands a `;` mid-word, `อยากกินกาแฟ` makes a six-consonant
    /// pile-up) or, for `ขอบคุณ` → `-v[86I`, by the letter-poor path in `RunJudge`.
    static let thaiCaught = ["สวัสดี", "อยากกินกาแฟ", "ขอบคุณ", "สวัสดีครับ"]

    /// Missed because the wreckage is genuinely English-shaped — `โรงเรียน` gives `Fi'giupo`,
    /// which has vowels throughout and no pile-up. The short ones are worse: below three letters
    /// `LatinOrthography` abstains on purpose, because guessing on two letters mangles far more
    /// correct text than it rescues.
    static let thaiMissed = [
        "โรงเรียน", "ผม", "แมว", "ไป", "กิน", "ทำงาน", "วันนี้", "พรุ่งนี้",
    ]

    // MARK: - Layout simulation

    /// What the user would have seen had they typed this English word with the Thai layout active.
    static func mistypedOnThaiLayout(_ english: String) -> String {
        String(String.UnicodeScalarView(
            english.unicodeScalars.compactMap { KedmaneeMapping.thai(forQwerty: $0) }))
    }

    /// What the user would have seen had they typed this Thai word with the US layout active.
    static func mistypedOnUSLayout(_ thai: String) -> String {
        String(String.UnicodeScalarView(
            thai.unicodeScalars.compactMap { KedmaneeMapping.qwerty(forThai: $0) }))
    }
}
