# Changelog

All notable changes to this project are recorded here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Unreleased

### Changed

- **Mascot.** A mango 8-bit cat, sibling to Tama's yellow one and built from the same sprite
  geometry, now sits in the converter header, the About window and Settings. It blinks when idle,
  breathes a pixel once there is a result, and shuts its eyes after a copy, with a small bubble
  showing the direction (`ก⇄A`, `ก`, `A`, or `✓`).
- **Menu-bar glyph** is now a keycap outline with `ก` on it, replacing the pixel keyboard. It is
  deliberately not the mascot: next to Tama in a real menu bar, two side-view pixel cats are
  indistinguishable at 18px, so neither icon identified its app. The outline is what makes it
  findable — nothing else up there has a border — and it depicts the key you forgot to press.
- **The app presents in English.** Title is "Who Forgot To Change Lang" in the header, About,
  Settings, the right-click menu, window titles and `CFBundleDisplayName`; buttons and section
  headings are English too. Thai remains where it is content rather than labelling — the
  conversion examples and the privacy capsule.
- **Thai text uses Noto Sans Thai**, which macOS ships, instead of the system Thai face, whose
  vowel and tone marks crowd at 11–13pt — the marks this app exists to help people read. Nothing
  is bundled; the helper falls back to the system font where the family is missing.

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
