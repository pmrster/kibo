// Dumps the authoritative Thai Kedmanee <-> US QWERTY key mapping straight out of macOS.
//
// Run with:  swift Tools/dump-kedmanee.swift
//
// This is a one-off verification tool, NOT part of the app or its test suite. It exists because
// hand-transcribed keyboard tables are exactly the kind of thing that is 97% right and quietly
// wrong on three keys. macOS ships the real layout data for both `com.apple.keylayout.US` and
// `com.apple.keylayout.Thai`; asking UCKeyTranslate what each physical key produces under each
// layout gives the pairing directly, with no transcription step to get wrong.
//
// It reads only system layout resources and prints to stdout — no network, no file writes.
//
// If the Thai layout data is unavailable (TISGetInputSourceProperty can return nil for input
// sources the user has never enabled), the tool says so and exits non-zero; the committed table
// then stands on its unit tests instead. See CLAUDE.md for which path this repo actually used.

import Carbon.HIToolbox
import Foundation

/// Locates an installed keyboard layout by input-source id and returns its UCKeyboardLayout blob.
func layoutData(forSourceID wanted: String) -> Data? {
    let filter = [kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as String] as CFDictionary
    guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource]
    else { return nil }

    for source in list {
        guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { continue }
        let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
        guard id == wanted else { continue }
        guard let dataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            // Layout exists but carries no Unicode data — the documented failure mode.
            return nil
        }
        return Unmanaged<CFData>.fromOpaque(dataPtr).takeUnretainedValue() as Data
    }
    return nil
}

/// What `keyCode` produces under `layout`, with or without Shift. Dead keys are resolved to the
/// character they'd print on their own, so nothing silently returns empty.
func character(_ keyCode: UInt16, shift: Bool, layout: Data) -> String? {
    var deadKeyState: UInt32 = 0
    var chars = [UniChar](repeating: 0, count: 8)
    var length = 0
    // UCKeyTranslate wants the modifier byte, i.e. Carbon's shiftKey shifted down 8 bits.
    let modifiers = shift ? UInt32(shiftKey >> 8) : 0

    let status = layout.withUnsafeBytes { raw -> OSStatus in
        guard let base = raw.baseAddress else { return OSStatus(paramErr) }
        let ptr = base.assumingMemoryBound(to: UCKeyboardLayout.self)
        return UCKeyTranslate(ptr,
                              keyCode,
                              UInt16(kUCKeyActionDown),
                              modifiers,
                              UInt32(LMGetKbdType()),
                              OptionBits(kUCKeyTranslateNoDeadKeysBit),
                              &deadKeyState,
                              chars.count,
                              &length,
                              &chars)
    }
    guard status == noErr, length > 0 else { return nil }
    return String(utf16CodeUnits: chars, count: length)
}

// Virtual key codes 0...50 cover the alphanumeric block: letters, digits, and the punctuation
// keys. Everything above that is modifiers, function keys, and the numeric keypad, none of which
// carry a Kedmanee character.
let keyCodes: [UInt16] = Array(0...50)

guard let us = layoutData(forSourceID: "com.apple.keylayout.US") else {
    FileHandle.standardError.write(Data("ERROR: no layout data for com.apple.keylayout.US\n".utf8))
    exit(1)
}
guard let thai = layoutData(forSourceID: "com.apple.keylayout.Thai") else {
    FileHandle.standardError.write(Data("""
        ERROR: no layout data for com.apple.keylayout.Thai.
        Add Thai under System Settings > Keyboard > Text Input > Input Sources, then re-run.
        Falling back to the hand-written table (see CLAUDE.md).

        """.utf8))
    exit(2)
}

struct Pair: Encodable {
    let keyCode: UInt16
    let shift: Bool
    let qwerty: String
    let kedmanee: String
}

var pairs: [Pair] = []
for code in keyCodes {
    for shift in [false, true] {
        guard let latin = character(code, shift: shift, layout: us),
              let thaiChar = character(code, shift: shift, layout: thai),
              latin != thaiChar,                                   // key is identical on both layouts
              latin.unicodeScalars.allSatisfy({ (0x21...0x7E).contains($0.value) })
        else { continue }
        pairs.append(Pair(keyCode: code, shift: shift, qwerty: latin, kedmanee: thaiChar))
    }
}

pairs.sort { ($0.shift ? 1 : 0, $0.keyCode) < ($1.shift ? 1 : 0, $1.keyCode) }

// `--json` emits just the mapping array, for pasting into Fixtures/conversion-cases.json. That
// fixture is the behaviour contract a Windows port has to satisfy, so its table must come from
// the same place this one does rather than being re-transcribed.
if CommandLine.arguments.contains("--json") {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let mapping = pairs.map { ["qwerty": $0.qwerty, "kedmanee": $0.kedmanee] }
    do {
        print(String(decoding: try encoder.encode(mapping), as: UTF8.self))
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("ERROR: \(error)\n".utf8))
        exit(3)
    }
}

/// Renders a character as a Swift string literal body. Both sides of the table can contain `"`
/// and `\` — Kedmanee puts `"` on Shift-Q's neighbour and `\` is itself a mapped key — so the
/// output is not pasteable Swift unless both are escaped.
func swiftLiteral(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\")
     .replacingOccurrences(of: "\"", with: "\\\"")
}

print("// \(pairs.count) mapped keys, dumped from macOS layout data")
for p in pairs {
    print("(\"\(swiftLiteral(p.qwerty))\", \"\(swiftLiteral(p.kedmanee))\"),  // keyCode \(p.keyCode)\(p.shift ? " shift" : "")")
}

// Collision report — the converter inverts the EN->TH table to build TH->EN, which is only
// sound if no two QWERTY keys land on the same Thai character.
var seen: [String: String] = [:]
var collisions: [String] = []
for p in pairs {
    if let first = seen[p.kedmanee] { collisions.append("\(p.kedmanee): \(first) and \(p.qwerty)") }
    seen[p.kedmanee] = p.qwerty
}
if collisions.isEmpty {
    print("\n// mapping is a bijection: \(pairs.count) distinct Thai characters")
} else {
    print("\n// COLLISIONS (\(collisions.count)):")
    collisions.forEach { print("//   \($0)") }
}
