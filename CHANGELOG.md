# Changelog

All notable changes to this project are recorded here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Unreleased

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
