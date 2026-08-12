# Changelog

All notable changes to this project are recorded here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.2.0] — 2026-08-12

The first release under the name **Kibo**, and the first hardened one. Everything below had
accumulated as "Unreleased" while the shipped DMG still said 0.1.0 and described the old app.

### Security and privacy

- **The app is sandboxed, with no network entitlement.** `Packaging/Kibo.entitlements` grants
  `com.apple.security.app-sandbox` and nothing else, so "Kibo makes no network connections" is now
  enforced by the kernel instead of promised by the code. `package.sh` refuses to build without
  the entitlements file and verifies the sandbox survived signing.
- **Copies are marked concealed and transient.** `SystemClipboard.write` sets the
  `org.nspasteboard.ConcealedType` and `TransientType` markers, which clipboard managers honour by
  keeping the item out of their history. This app's use case means the text is often a password,
  and unmarked it was landing in every clipboard history on the machine — and, via Universal
  Clipboard, on nearby Apple devices.
- **Window state restoration is disabled** on every panel, plus
  `applicationSupportsSecureRestorableState`. AppKit would otherwise write a text view's contents
  — the user's pasted text — into `~/Library/Saved Application State/`.
- **Autocorrection is off** in the input field.
- *Upgrade note:* sandboxing moves preferences into `~/Library/Containers/pmrster.kibo/`, so
  appearance, text size and last mode reset once on first launch of 0.2.0. Nothing else was stored,
  so nothing else is lost.
- Added `PRIVACY.md` and `SECURITY.md`, including how to verify each claim, and what the app
  genuinely cannot control (the OS text context menu's Look Up and Translate; Universal Clipboard).
- **Corrected the verification command** in the README and `CLAUDE.md`: `lsof` ORs its selectors,
  so the documented `lsof -p $(pgrep -x Kibo) -i` printed every *other* process's sockets. It
  needs `-a`.

### Added

- The app icon is built from `icon.png` during packaging, so the DMG no longer ships a blank
  generic icon despite `Info.plist` declaring one.
- CI (`.github/workflows/ci.yml`): build, test, and package on every push and pull request — the
  accuracy contract is only a contract if something runs it.
- `CONTRIBUTING.md`.

### Changed

- **The app is now called Kibo**, after its mascot. "Who Forgot To Change Lang" becomes the
  subtitle, shown under the name in About. The rename goes all the way through — SwiftPM package,
  targets, source directories, the `.app`, the bundle identifier and the snapshot flag — because a
  half-rename is exactly the confusion the one-name rule exists to prevent — including the repo
  directory, now `kibo`.
- Preferences reset once as a result: the defaults keys moved from `wfcl.*` to `kibo.*` and the
  bundle identifier changed, so theme, text size and last mode return to their defaults.

- **Mascot.** **Kibo**, an original 8-bit ghost — the wrong layout haunting your sentence. Says
  "boo~" after a copy, as Tama's cat says "meow~". It perches on the
  top edge of the input field with its tails tucked behind, blinks while it waits, and shuts its
  eyes after a copy. Small vertical eyes, no mouth. A single colour with the features cut out as holes, the same
  construction Tama uses, flipping between midnight and pale so it is always the opposite of what
  it sits on. Proportions follow `icon.png`, the reference art now kept in the repository root. Replaces a first attempt that borrowed Tama's cat sprite and looked it once
  enlarged — that geometry is built for a 24×15 menu-bar pet, not for display.
- **Title font** is the system font at semibold — the same face as the section labels.
  Rounded heavy read as a toy and condensed black read as dated; Space Grotesk looked right but is
  not a system face, so the shipped build would have fallen back on every Mac but the one it was
  designed on. Nothing is bundled.
- **Input and result fills are opaque** rather than a 45% blend, so the mascot can hide behind the
  input field without showing through it.
- **Menu-bar glyph** is Kibo's silhouette. It went pixel keyboard → cat → `ก` keycap → Kibo: the
  cat was indistinguishable from Tama's at 18px, which is what the keycap solved, and which stops
  being a problem once the mascot is a ghost.
- **The app presents in English.** Title is "Kibo" in the header, About, Settings, the right-click
  menu, window titles and `CFBundleDisplayName`, with "Who Forgot To Change Lang" as the subtitle
  under the name in About; buttons and section headings are English too. The privacy badge now reads "Local-only · No network", phrased like
  Tama's. Thai appears only in the text being converted.
- **Thai text uses Noto Sans Thai**, which macOS ships, instead of the system Thai face, whose
  vowel and tone marks crowd at 11–13pt — the marks this app exists to help people read. Nothing
  is bundled; the helper falls back to the system font where the family is missing.

- **Accent is near-monochrome** — the same midnight/pale pair as the mascot — replacing mango,
  which fought everything around it once the ghost arrived. Green remains on the copy
  confirmation and privacy badge.
- **The mode control is hand-rolled.** A segmented `Picker` paints its selection with the system
  accent colour, so the selected mode rendered in whatever colour the user had set system-wide.
- **Removed the example presets row**, making the converter shorter and simpler to scan.

### Added

- `--snapshot` design-review mode behind the `KIBO_SNAPSHOT` compile flag: renders the converter,
  About, Settings and a mascot sheet to PNGs offscreen, in light and dark. Absent from normal
  debug and release builds. Exists because screen capture needs a permission a terminal often
  lacks.

### Fixed

- **The accuracy figures are now actually pinned.** They were quoted as "36 of 36 / 16 of 25 /
  4 of 12" and described as "pinned by tests", but only precision was asserted — and even that
  had no count, so deleting an entry would have lowered the bar silently. The English figure
  appeared as three different numbers in three files and measured 15 of 24. `AccuracyCorpus` now
  holds the corpora once and `MeasuredAccuracyTests` asserts every figure end-to-end through the
  converter, counts included, in both directions.
- **`Fixtures/conversion-cases.json` carries the whole contract**, not a sample: 24 cases became
  114, covering the full precision corpus, both recall corpora and the known misses, plus a
  `schema` block for a non-Swift reader. A Windows port could previously pass every case in the
  file and still mangle `HTML`, `array[i]` and `C:\Users\pmr`. Version bumped to 2.
- **Version injection no longer depends on a hardcoded literal.** `package.sh` matched
  `s/0\.1\.0/$VERSION/` against `Info.plist`, so bumping the plist would have silently stopped the
  substitution; it now sets the key by name with PlistBuddy, and `CFBundleVersion` is the commit
  count rather than a frozen `1`.
- Settings can be design-reviewed: its two segmented `Picker`s — the control CLAUDE.md bans for
  painting with the *system* accent — are now the app's own `ThemedSegmentedControl`, shared with
  the converter's mode picker, and they render under `--snapshot` where the AppKit ones did not.
- "Remember the last mode" moved out of a SwiftUI `.onChange` and into `ConverterModel` behind a
  `ModeMemory` seam, where it is testable and where a port will find it.
- Documentation that described an app that no longer existed: the mascot's file names, the accent
  colour, the title in the header, the display name in `PLAN.md`, and a test comment calling the
  dumped key table "transcribed".

## 0.1.0 — 2026-08-12

First slice: the converter and the menu-bar app.

### Added

- **Conversion domain** behind a single `KeyboardConverting` interface — `ConversionMode`,
  `ConversionResult`, and a pure, deterministic, synchronous `KeyboardConverter`.
- **Kedmanee key table**, 94 pairs covering every printable ASCII key in both directions, dumped
  from macOS layout data by `Tools/dump-kedmanee.swift` rather than transcribed by hand. The
  mapping is a bijection, so the two explicit directions are exact inverses.
- **Three modes.** `EN → TH` and `TH → EN` are mechanical whole-string conversions. `Mixed`
  converts a run only when that run is malformed in its own script, so already-correct text,
  numbers, and punctuation survive.
- **Orthographic gate** (`ThaiOrthography`, `LatinOrthography`, `RunJudge`) — dictionary-free
  judgement of whether a run is real text or the wreckage of the wrong layout, including a
  letter-poor path for Thai words that mistype into mostly punctuation, such as `ขอบคุณ` → `-v[86I`.
- **Menu-bar app** — `NSStatusItem` with a pixel-keyboard template glyph, left-click converter
  popover, right-click About / Settings / Quit, and a pinnable floating panel for copying between
  apps. No Dock icon.
- **Converter window** — live output, mode picker, swap, paste, clear, copy with a
  `คัดลอกแล้ว` confirmation, example presets, Thai interface, and VoiceOver labels. Every action
  has a shortcut (`⇧⌘C` copy, `⇧⌘V` paste, `⇧⌘K` clear, `⇧⌘S` swap, `⇧⌘P` pin), since the input
  is a text editor that swallows Tab.
- **Settings** — theme (system / light / dark) and text size, persisted along with the last mode.
- **Portable fixtures** — `Fixtures/conversion-cases.json` carries the full key table and 24 cases
  across all three modes as a behaviour contract for a later Windows port.
- **Packaging** — `Packaging/package.sh` produces an ad-hoc signed `.app` and DMG, with optional
  Developer ID signing and notarization.

### Known limitations

- Mixed mode is dictionary-free and judges spelling shape only, so wreckage that happens to be
  well-formed is left alone — `แนกำ` (was "code"), `นา` (was "ok"). It leaves correct text
  untouched in 36 of 36 sampled cases, and fixes 15 of 24 sampled English mistypings and 4 of 12
  Thai ones; the explicit modes convert the rest. All three figures are pinned as tests.
- No signing identity is provisioned, so published builds are ad-hoc signed and require
  right-click → Open on first launch.
- No app icon artwork yet; the bundle uses the generic application icon.

### Decisions

- Built as a SwiftPM package with no `.xcodeproj`, superseding the Xcode-project layout in
  `PLAN.md`. Forked from the sibling Tama app, which had already established the pattern.
- Menu bar uses `NSStatusItem` rather than SwiftUI's `MenuBarExtra`, which has no right-click hook.
- Deployment target macOS 14, for `@Observable` and to keep the WidgetKit path open.
