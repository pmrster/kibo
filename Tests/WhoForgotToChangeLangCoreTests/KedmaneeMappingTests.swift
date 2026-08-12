import XCTest
@testable import WhoForgotToChangeLangCore

/// The mapping table is the one piece of this app that cannot be reasoned about — it is
/// transcribed data. These tests pin it against macOS's own layout data, which
/// `Tools/dump-kedmanee.swift` reads from `com.apple.keylayout.Thai`.
final class KedmaneeMappingTests: XCTestCase {

    // MARK: - Structure

    func test_every_printable_ascii_key_is_mapped() {
        // Kedmanee assigns a character to all 94 printable ASCII keys; a gap means a dropped row.
        for code in 0x21...0x7E {
            let key = UnicodeScalar(code)!
            XCTAssertNotNil(KedmaneeMapping.thai(forQwerty: key),
                            "QWERTY key '\(key)' has no Kedmanee character")
        }
        XCTAssertEqual(KedmaneeMapping.pairs.count, 94)
    }

    func test_mapping_is_a_bijection() {
        // `thai(forQwerty:)` is inverted to build `qwerty(forThai:)`. That inversion is only
        // sound if no two QWERTY keys land on the same Kedmanee character.
        let outputs = KedmaneeMapping.pairs.map(\.kedmanee)
        XCTAssertEqual(Set(outputs).count, outputs.count, "two QWERTY keys produce the same character")

        let inputs = KedmaneeMapping.pairs.map(\.qwerty)
        XCTAssertEqual(Set(inputs).count, inputs.count, "a QWERTY key appears twice in the table")
    }

    func test_round_trips_in_both_directions() {
        for pair in KedmaneeMapping.pairs {
            XCTAssertEqual(KedmaneeMapping.thai(forQwerty: pair.qwerty), pair.kedmanee)
            XCTAssertEqual(KedmaneeMapping.qwerty(forThai: pair.kedmanee), pair.qwerty)
        }
    }

    /// Documents why the table and the converter both speak `UnicodeScalar` rather than
    /// `Character`: Thai combining marks fuse with the consonant before them, so Thai text has
    /// strictly fewer Characters than scalars. A Character-based loop would be handed clusters
    /// that appear in no table and would pass them through unconverted.
    func test_thai_combining_marks_fuse_into_fewer_characters() {
        XCTAssertEqual("สวัสดี".unicodeScalars.count, 6)
        XCTAssertEqual("สวัสดี".count, 4)
    }

    // MARK: - Spot checks against the macOS dump

    /// The unshifted home row — the keys behind the `สวัสดี` example in SPEC.md.
    func test_unshifted_home_row() {
        assertMaps([
            ("a", "ฟ"), ("s", "ห"), ("d", "ก"), ("f", "ด"), ("g", "เ"),
            ("h", "\u{0E49}"), ("j", "\u{0E48}"),
            ("k", "า"), ("l", "ส"), (";", "ว"), ("'", "ง"),
        ])
    }

    func test_shifted_home_row() {
        assertMaps([
            ("A", "ฤ"), ("S", "ฆ"), ("D", "ฏ"), ("F", "โ"), ("G", "ฌ"),
            ("H", "\u{0E47}"), ("J", "\u{0E4B}"),
            ("K", "ษ"), ("L", "ศ"), (":", "ซ"), ("\"", "."),
        ])
    }

    /// The digit row is where hand-transcribed tables usually go wrong: `3` produces `_`
    /// (an underscore, not a hyphen) and the backtick produces `-`. Both were corrected from
    /// the macOS dump after an initial hand table had them the other way round.
    func test_digit_row_and_backtick() {
        assertMaps([
            ("1", "ๅ"), ("2", "/"), ("3", "_"), ("4", "ภ"), ("5", "ถ"),
            ("6", "\u{0E38}"), ("7", "\u{0E36}"),
            ("8", "ค"), ("9", "ต"), ("0", "จ"), ("-", "ข"), ("=", "ช"), ("`", "-"),
        ])
    }

    /// Shifted digits carry the Thai numerals ๐–๙ plus the baht sign.
    func test_shifted_digits_are_thai_numerals() {
        assertMaps([
            ("Q", "๐"), ("@", "๑"), ("#", "๒"), ("$", "๓"), ("%", "๔"),
            ("*", "๕"), ("(", "๖"), (")", "๗"), ("_", "๘"), ("+", "๙"), ("&", "฿"),
        ])
    }

    /// Several Kedmanee keys produce ASCII, so the Thai side of the table is not all Thai script.
    /// The converter must map these too, or TH → EN silently drops characters.
    func test_kedmanee_keys_that_produce_ascii() {
        assertMaps([
            ("2", "/"), ("3", "_"), ("`", "-"), ("!", "+"), ("~", "%"),
            ("Z", "("), ("X", ")"), ("W", "\""), ("}", ","), ("\"", "."), ("M", "?"),
        ])
    }

    func test_backslash_and_pipe_carry_the_rare_consonants() {
        assertMaps([("\\", "ฃ"), ("|", "ฅ")])
    }

    // MARK: - Lookup misses

    func test_unmapped_characters_return_nil() {
        for scalar: UnicodeScalar in [" ", "\n", "\t", "🐈", "é", "ก", "ä"] {
            XCTAssertNil(KedmaneeMapping.thai(forQwerty: scalar),
                         "'\(scalar)' should not be a QWERTY key")
        }
        // A Latin letter is not a Kedmanee character.
        XCTAssertNil(KedmaneeMapping.qwerty(forThai: "a"))
        XCTAssertNil(KedmaneeMapping.qwerty(forThai: " "))
    }

    // MARK: - Helper

    /// Asserts both directions for each pair, so a spot check can never pass one-way.
    private func assertMaps(_ expected: [(UnicodeScalar, UnicodeScalar)],
                            file: StaticString = #filePath, line: UInt = #line) {
        for (qwerty, kedmanee) in expected {
            XCTAssertEqual(KedmaneeMapping.thai(forQwerty: qwerty), kedmanee,
                           "key '\(qwerty)' → Thai", file: file, line: line)
            XCTAssertEqual(KedmaneeMapping.qwerty(forThai: kedmanee), qwerty,
                           "'\(kedmanee)' → key", file: file, line: line)
        }
    }
}
