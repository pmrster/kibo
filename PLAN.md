# macOS-first implementation plan

## Product decision

Build a native macOS menu-bar utility first. The working product shape is a compact converter window opened from a persistent menu-bar icon. This matches the fast paste/convert/copy workflow and has a direct Windows equivalent in a notification-area utility.

Do not make a WidgetKit widget the primary interface. WidgetKit renders timeline-based views in a separate process and its direct interactions are buttons and toggles backed by App Intents. That makes it useful as a companion, but unsuitable for the required multiline text input. See Apple's documentation for [widget interactivity](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities).

The menu-bar surface is an AppKit [`NSStatusItem`](https://developer.apple.com/documentation/appkit/nsstatusitem) hosting a SwiftUI view, not SwiftUI's [`MenuBarExtra`](https://developer.apple.com/documentation/swiftui/menubarextra). `MenuBarExtra` offers no right-click hook, and a menu-bar-only app has no menu bar of its own in which to put About, Settings, and Quit.

## MVP experience

1. The app starts as a menu-bar-only utility with no regular Dock presence.
2. Left-clicking the menu-bar glyph opens a compact SwiftUI popover and focuses the input; right-clicking opens About / Settings / Quit.
3. The user types or explicitly pastes text.
4. The result updates immediately in Mixed, EN → TH, or TH → EN mode.
5. Copy places the result on the clipboard and shows short confirmation feedback, retracted as soon as the result changes.
6. Swap exchanges EN → TH and TH → EN, and is disabled in Mixed, which has no direction to swap. Clear resets input and result.
7. The app follows the system appearance and performs no network requests.
8. Pin reopens the same converter as a floating panel, for copying between apps without it closing.

The MVP deliberately excluded automatic clipboard monitoring, conversion history, analytics, and a WidgetKit extension. Text replacement in other apps and launch at login were left out of it too, and arrived in 0.3.0 — replacement as a macOS Service, so nothing watches the selection.

## Architecture

The conversion domain is a deep module behind one small interface:

```swift
enum ConversionMode: String, CaseIterable, Sendable {
    case mixed
    case englishToThai
    case thaiToEnglish
}

struct ConversionResult: Equatable, Sendable {
    let input: String
    let output: String
    let mode: ConversionMode
}

protocol KeyboardConverting: Sendable {
    func convert(_ input: String, mode: ConversionMode) -> ConversionResult
}
```

Callers should not know about mapping tables, run tokenization, or Unicode traversal. Tests exercise the same interface as the app. Add an adapter seam only where behavior actually varies:

- `KeyboardConverter`: pure Kedmanee/QWERTY mapping and Mixed-mode run conversion. Internally it delegates to `KedmaneeMapping`, `RunSplitter`, and `RunJudge`, none of which a caller ever sees.
- `Clipboard`: reads only for an explicit Paste action and writes only for Copy. `SystemClipboard` wraps `NSPasteboard` in the shell; `InMemoryClipboard` supports tests and counts accesses so the privacy promise is asserted rather than assumed.
- `SettingsStore` / `AppSettings`: store only non-sensitive preferences — appearance, text size, and the last selected mode.
- `ConverterModel`: owns presentation state and calls the converter; it contains no mapping rules. It lives in the Core target, because it is logic and Core is where logic lives.

Do not introduce a shared cross-platform framework yet. The conversion implementation is small, while native desktop shells differ substantially. Portability comes from a language-neutral behavior contract and JSON test fixtures that both macOS and Windows implementations must pass.

## Repository shape

Built as a **SwiftPM package with no `.xcodeproj`**, following the sibling Tama app which had
already proven the pattern. The gain is that the whole suite runs from the terminal with
`swift test`, and there is no `project.pbxproj` to rot or to merge-conflict.

```text
kibo/
  Package.swift
  Sources/
    KiboCore/          # all logic, zero AppKit — fully unit-tested
      Models/{ConversionMode,ConversionResult}.swift
      Conversion/{KedmaneeMapping,KeyboardConverter,RunSplitter}.swift
      Conversion/{ThaiOrthography,LatinOrthography,RunJudge}.swift
      Converter/{ConverterModel,Clipboard}.swift
      Settings/SettingsStore.swift
    Kibo/              # SwiftUI/AppKit shell — thin, not unit-tested
      KiboApp.swift
      {Theme,AppSettings,SystemClipboard}.swift
      {AppChrome,ConverterView,SettingsView}.swift
  Tests/KiboCoreTests/
  Fixtures/conversion-cases.json         # portable behavior contract
  Tools/dump-kedmanee.swift              # dumps the key table from macOS layout data
  Packaging/{Info.plist,package.sh}
```

`ConverterModel` sits in Core rather than a feature folder because it is logic, and Core is where
logic lives. The WidgetKit extension remains a Phase 3 item and is not created.

## Conversion rules

- EN → TH maps every supported US QWERTY character to the character on the same Kedmanee physical key.
- TH → EN applies the reverse mapping. The table is a bijection over all 94 printable ASCII keys, so the two directions are exact inverses.
- Mixed splits the string into maximal Thai, Latin-keyboard, and neutral runs, then converts a run **only if it is malformed in its own script**. Neutral runs are always preserved.
- Preserve whitespace, newlines, emoji, and unmapped Unicode exactly.
- Include both unshifted and shifted keys, punctuation, and digits in the mapping contract.
- Conversion walks Unicode **scalars**, not `Character`s. Thai combining marks fuse with the preceding consonant, so `สวัสดี` is six scalars but four Characters; a Character-based loop would hand the converter clusters that are in no table and pass them through unconverted.

### Mixed is judged, not mechanical

This supersedes the original plan, which called for Mixed to flip every run unconditionally. That
rule would turn `l;ylfu ้ำสสน ครับ 2024 :)` into `สวัสดี hello 8iy[ /จ/ภ ซ๗` — correcting two runs and
destroying three. The judgement is deterministic and dictionary-free, resting on Thai and English
spelling structure; `SPEC.md` documents the rules and `CLAUDE.md` the measured accuracy.

A dictionary-backed judgement was considered and rejected for this slice: written Thai has no
spaces, so `สวัสดีครับ` arrives as one run and any lookup would first need word segmentation —
substantial work whose errors would cascade into wrong conversions. The structural gate needs no
segmentation at all. The explicit modes stay mechanical and are the escape hatch when the gate is
wrong.

## Delivery slices

### Slice 1 — executable vertical slice — **done (0.1.0)**

- ~~Create a macOS SwiftUI app and test targets~~ — SwiftPM package, macOS 14, two targets plus tests.
- ~~Implement the converter interface, complete Kedmanee mapping, and portable fixtures.~~
- ~~Add exhaustive unit tests~~ — 97 tests covering both directions, shifted keys, unmapped characters, multiline input, Mixed runs, the orthographic gate, and the fixture contract.
- ~~Add `MenuBarExtra` with `.window` style~~ — **superseded**: an `NSStatusItem` with a popover, because `MenuBarExtra` has no right-click hook and a menu-bar-only app needs somewhere to put About / Settings / Quit. Input, live output, mode picker, Copy, Paste, Swap, and Clear all present, plus a pinnable floating panel.
- ~~Make the app menu-bar-only with an accessible icon and control labels.~~

Exit condition met: `swift run Kibo` and the packaged `.app` both complete the
paste → convert → copy flow with no network sockets open.

Carried into Slice 2: app icon artwork, and a signing identity for a notarized build.

### Slice 2 — desktop-quality release

- Add keyboard-first focus behavior and a user-configurable global shortcut.
- ~~Add a Settings scene for launch-at-login~~ — done, as an `SMAppService`-backed switch in Settings. A global shortcut preference remains open; the Services item (right-click → Services → *Fix Layout with Kibo*) can be given a system-wide shortcut in System Settings, which covers the most common want without the app registering a hotkey of its own.
- Add UI tests for the primary flow and clipboard feedback.
- Polish Thai localization, empty/error states, VoiceOver labels, contrast, and compact-window sizing.
- Add app icon, versioning, signing configuration, hardened runtime, archive validation, and notarized distribution.

Exit condition: a signed build is comfortable to use daily and installable on another Mac.

### Slice 3 — optional WidgetKit companion

- Add an App Group only when the widget needs to share non-sensitive state.
- Show the last conversion or a privacy-safe empty state.
- Offer only actions WidgetKit supports well, such as changing the default mode or opening the converter.
- Do not promise editable text inside the widget.

Exit condition: the widget adds convenience without becoming a second implementation of conversion behavior.

### Slice 4 — Windows utility

- Implement a Windows notification-area shell with a compact converter window.
- Reimplement the small converter module in the selected Windows stack and run the shared JSON fixtures against it.
- Preserve the same privacy defaults: local conversion, explicit clipboard access, no analytics.
- Adapt visual styling to Windows rather than copying SwiftUI layout literally.

Exit condition: macOS and Windows pass the same conversion cases and provide equivalent paste → convert → copy flows.

## Acceptance criteria for the first build

- All documented examples produce the expected output.
- Every supported Kedmanee key maps correctly in both directions.
- Conversion is synchronous and visually immediate for at least 100,000 characters.
- The app makes zero network requests and stores no entered or converted text.
- Clipboard reads happen only after Paste and clipboard writes only after Copy.
- Closing the converter leaves the menu-bar utility available.
- The main flow is usable without a mouse and has VoiceOver labels.

## Decisions validated during Slice 1

- **macOS 14 confirmed** as the minimum. It buys `@Observable` and keeps the Slice 3 WidgetKit
  interactivity path open; nothing in the converter needs a newer API.
- **Kedmanee tables verified.** `Tools/dump-kedmanee.swift` reads macOS's own layout data through
  `UCKeyTranslate` for `com.apple.keylayout.US` and `com.apple.keylayout.Thai`, so the table is
  dumped rather than transcribed. It corrected two keys an initial hand table had backwards: `3`
  produces `_`, and the backtick produces `-`. All 94 printable ASCII keys map, and the result is
  a bijection — which is what makes TH → EN a sound inversion of EN → TH.
- **Close on focus loss, or stay open?** Both, rather than choosing. The popover is transient by
  default; a Pin button opens the same view in a floating `NSPanel` that survives switching apps.
- **App name in metadata.** ~~The Thai title is the display name.~~ Superseded: `Kibo` is the
  display name (`CFBundleDisplayName`, window titles, the status-item accessibility label) as well
  as the identifier everywhere a Latin name is required — bundle name, executable, targets. The
  interface is entirely English, so a Thai display name sat oddly against it; "ใครลืมเปลี่ยนภาษา"
  is the project's Thai name in prose, and "Who Forgot To Change Lang" the subtitle. See SPEC.md.

Still open, for Slice 2:

- Choose a conflict-free default global shortcut only after testing common Thai input-source shortcuts; the shortcut is not required for the first vertical slice.
- Whether the Mixed-mode gate should gain a dictionary. Defer until real use shows which of the recorded misses actually cause friction.
