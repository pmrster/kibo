# Changelog

All notable changes to this project are recorded here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Unreleased

### Changed

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
- **The app presents in English.** Title is "Who Forgot To Change Lang" in the header, About,
  Settings, the right-click menu, window titles and `CFBundleDisplayName`; buttons and section
  headings are English too. The privacy badge now reads "Local-only · No network", phrased like
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

- `--snapshot` design-review mode behind the `WFCL_SNAPSHOT` compile flag: renders the converter,
  About, Settings and a mascot sheet to PNGs offscreen, in light and dark. Absent from normal
  debug and release builds. Exists because screen capture needs a permission a terminal often
  lacks.

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
  untouched in 36 of 36 sampled cases, and fixes 16 of 25 sampled English mistypings and 4 of 12
  Thai ones; the explicit modes convert the rest. All three figures are pinned as tests.
- No signing identity is provisioned, so published builds are ad-hoc signed and require
  right-click → Open on first launch.
- No app icon artwork yet; the bundle uses the generic application icon.

### Decisions

- Built as a SwiftPM package with no `.xcodeproj`, superseding the Xcode-project layout in
  `PLAN.md`. Forked from the sibling Tama app, which had already established the pattern.
- Menu bar uses `NSStatusItem` rather than SwiftUI's `MenuBarExtra`, which has no right-click hook.
- Deployment target macOS 14, for `@Observable` and to keep the WidgetKit path open.
