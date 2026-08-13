import Foundation

/// Which key the user actually pressed, for the handful of characters macOS swaps out as they
/// type.
///
/// `NSTextView` — and so SwiftUI's `TextEditor`, and so Kibo's input field — enables
/// `isAutomaticQuoteSubstitutionEnabled` and `isAutomaticDashSubstitutionEnabled` by default.
/// Typing `'` inserts `’`, `"` inserts `“`/`”`, and `-` between words inserts `–`. Other apps do
/// the same, so text arriving by **Paste** is curled just as often as text typed here.
///
/// For most apps that is cosmetic. Here it is not: those three keys carry Kedmanee characters —
/// `'` is `ง`, `"` is `.`, `-` is `ข` — so a curled apostrophe is a keystroke the converter can no
/// longer recognise, and `ง` becomes unreachable from the keyboard.
///
/// **This is deliberately not part of `KedmaneeMapping`.** That table is dumped from macOS's
/// layout data, is a bijection, and describes physical keys. This one is a many-to-one fold of
/// characters that are on no key at all, and it applies in the QWERTY → Thai direction only: the
/// Thai → English direction emits the straight ASCII the layout actually prints, because there is
/// no curled `ง`.
///
/// The fold is 1:1 by construction — a substitute stands for exactly one keystroke. That is why
/// `…` is absent: it replaces *three* `.` presses, and folding it to one would silently drop two.
/// The shell disables text replacement, which is what produces it.
enum TypographicSubstitutes {

    struct Pair: Sendable, Equatable {
        let substitute: UnicodeScalar
        let key: UnicodeScalar
    }

    /// Written as escapes rather than literally so the pairs stay legible: `‘` and `’` are hard to
    /// tell apart at 11pt, and the whole point of the table is that they are different characters.
    ///
    /// Unlike `KedmaneeMapping` this is **many-to-one** and has no inverse — both curls fold to the
    /// one key — which is the other reason it cannot live in that table.
    private static let table: [(UnicodeScalar, UnicodeScalar)] = [
        ("\u{2018}", "'"),      // ‘  LEFT SINGLE QUOTATION MARK
        ("\u{2019}", "'"),      // ’  RIGHT SINGLE QUOTATION MARK — a typed apostrophe becomes this
        ("\u{201C}", "\""),     // “  LEFT DOUBLE QUOTATION MARK
        ("\u{201D}", "\""),     // ”  RIGHT DOUBLE QUOTATION MARK
        ("\u{2013}", "-"),      // –  EN DASH
        ("\u{2014}", "-"),      // —  EM DASH
    ]

    /// The whole fold, so `Fixtures/conversion-cases.json` can carry it to a port and the
    /// conformance test can prove the two have not drifted.
    static let pairs: [Pair] = table.map(Pair.init)

    private static let asciiForSubstitute: [UnicodeScalar: UnicodeScalar] =
        Dictionary(uniqueKeysWithValues: table)

    /// The ASCII key this character stands in for, or `nil` if it is not a substitution at all.
    static func asciiKey(for scalar: UnicodeScalar) -> UnicodeScalar? {
        asciiForSubstitute[scalar]
    }

    /// Whether this scalar is one of the substitutes, so `RunSplitter` can keep it inside the
    /// Latin run it belongs to instead of treating it as neutral and cutting the word in half.
    static func contains(_ scalar: UnicodeScalar) -> Bool {
        asciiForSubstitute[scalar] != nil
    }
}
