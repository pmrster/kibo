import Foundation

/// The Thai Kedmanee layout mapped to the US QWERTY layout, key by key.
///
/// Every pair below was dumped from macOS's own layout data rather than transcribed by hand —
/// see `Tools/dump-kedmanee.swift`, which asks `UCKeyTranslate` what each physical key produces
/// under `com.apple.keylayout.US` and `com.apple.keylayout.Thai`. Two keys in particular defeat
/// intuition and are worth not "correcting": `3` produces `_` (underscore) and the backtick
/// produces `-` (hyphen), not the other way round.
///
/// All 94 printable ASCII keys carry a Kedmanee character, and no two land on the same one, so
/// the table is a bijection and the Thai → English direction is a plain inversion of it. Both
/// facts are asserted in `KedmaneeMappingTests`; the converter's correctness rests on them.
///
/// Note that the Kedmanee side is not all Thai script: eleven keys produce ASCII characters
/// (`/ _ - + % ( ) " , . ?`). They are part of the mapping like any other key.
///
/// **Why the escapes.** Fifteen Kedmanee characters are Unicode nonspacing marks (`Mn`). Written
/// literally in a Swift string they would attach to whatever character precedes them and collapse
/// into a single `Character`, silently shortening the table and shifting every pair after them.
/// Each is written as an explicit scalar escape with its name in a comment so the table stays one
/// entry per key, and so a reader is never asked to tell `ิ` from `ี` at 11pt.
enum KedmaneeMapping {

    struct Pair: Sendable, Equatable {
        let qwerty: UnicodeScalar
        let kedmanee: UnicodeScalar
    }

    /// Laid out in physical keyboard rows, unshifted then shifted, so a row can be read straight
    /// off a real keyboard.
    static let pairs: [Pair] = table.map(Pair.init)

    /// Typed as scalars rather than `Character` on purpose: a `Character` literal would happily
    /// accept a multi-scalar cluster and quietly break the lookups below, whereas a
    /// `UnicodeScalar` literal that isn't exactly one scalar fails to compile.
    private static let table: [(UnicodeScalar, UnicodeScalar)] = [
        // ── Number row ──────────────────────────────────────────────────────────────────────
        ("`", "-"), ("1", "ๅ"), ("2", "/"), ("3", "_"), ("4", "ภ"), ("5", "ถ"),
        ("6", "\u{0E38}"),                                                  // ุ  SARA U
        ("7", "\u{0E36}"),                                                  // ึ  SARA UE
        ("8", "ค"), ("9", "ต"), ("0", "จ"), ("-", "ข"), ("=", "ช"),

        ("~", "%"), ("!", "+"), ("@", "๑"), ("#", "๒"), ("$", "๓"), ("%", "๔"),
        ("^", "\u{0E39}"),                                                  // ู  SARA UU
        ("&", "฿"), ("*", "๕"), ("(", "๖"), (")", "๗"), ("_", "๘"), ("+", "๙"),

        // ── Top row ─────────────────────────────────────────────────────────────────────────
        ("q", "ๆ"), ("w", "ไ"), ("e", "ำ"), ("r", "พ"), ("t", "ะ"),
        ("y", "\u{0E31}"),                                                  // ั  MAI HAN AKAT
        ("u", "\u{0E35}"),                                                  // ี  SARA II
        ("i", "ร"), ("o", "น"), ("p", "ย"), ("[", "บ"), ("]", "ล"), ("\\", "ฃ"),

        ("Q", "๐"), ("W", "\""), ("E", "ฎ"), ("R", "ฑ"), ("T", "ธ"),
        ("Y", "\u{0E4D}"),                                                  // ํ  NIKHAHIT
        ("U", "\u{0E4A}"),                                                  // ๊  MAI TRI
        ("I", "ณ"), ("O", "ฯ"), ("P", "ญ"), ("{", "ฐ"), ("}", ","), ("|", "ฅ"),

        // ── Home row ────────────────────────────────────────────────────────────────────────
        ("a", "ฟ"), ("s", "ห"), ("d", "ก"), ("f", "ด"), ("g", "เ"),
        ("h", "\u{0E49}"),                                                  // ้  MAI THO
        ("j", "\u{0E48}"),                                                  // ่  MAI EK
        ("k", "า"), ("l", "ส"), (";", "ว"), ("'", "ง"),

        ("A", "ฤ"), ("S", "ฆ"), ("D", "ฏ"), ("F", "โ"), ("G", "ฌ"),
        ("H", "\u{0E47}"),                                                  // ็  MAITAIKHU
        ("J", "\u{0E4B}"),                                                  // ๋  MAI CHATTAWA
        ("K", "ษ"), ("L", "ศ"), (":", "ซ"), ("\"", "."),

        // ── Bottom row ──────────────────────────────────────────────────────────────────────
        ("z", "ผ"), ("x", "ป"), ("c", "แ"), ("v", "อ"),
        ("b", "\u{0E34}"),                                                  // ิ  SARA I
        ("n", "\u{0E37}"),                                                  // ื  SARA UEE
        ("m", "ท"), (",", "ม"), (".", "ใ"), ("/", "ฝ"),

        ("Z", "("), ("X", ")"), ("C", "ฉ"), ("V", "ฮ"),
        ("B", "\u{0E3A}"),                                                  // ฺ  PHINTHU
        ("N", "\u{0E4C}"),                                                  // ์  THANTHAKHAT
        ("M", "?"), ("<", "ฒ"), (">", "ฬ"), ("?", "ฦ"),
    ]

    // Lookups are keyed by `UnicodeScalar`, not `Character`, and this is load-bearing rather
    // than a style choice. A `Character` is an extended grapheme cluster, so Thai combining
    // marks fuse with the consonant before them: "สวัสดี" is six scalars but only *four*
    // Characters (ส | วั | ส | ดี). Walking a Thai string by Character would hand the converter
    // clusters that are in no table, and it would silently pass them through unconverted.
    // `KeyboardConverter` therefore iterates `unicodeScalars`, and these dictionaries match.

    private static let enToTh: [UnicodeScalar: UnicodeScalar] =
        Dictionary(uniqueKeysWithValues: table)

    private static let thToEn: [UnicodeScalar: UnicodeScalar] =
        Dictionary(uniqueKeysWithValues: table.map { ($0.1, $0.0) })

    /// The scalar this physical key prints with the Thai layout active. `nil` for anything that
    /// is not a mapped key — whitespace, emoji, accented Latin, Thai script itself.
    static func thai(forQwerty key: UnicodeScalar) -> UnicodeScalar? { enToTh[key] }

    /// The inverse: which physical key printed this Kedmanee scalar. `nil` when the scalar is
    /// not on the Thai layout at all.
    static func qwerty(forThai key: UnicodeScalar) -> UnicodeScalar? { thToEn[key] }
}
