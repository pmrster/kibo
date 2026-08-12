# Repository guidance

## Project

This repository contains “ใครลืมเปลี่ยนภาษา,” a local-only Thai Kedmanee ↔ US QWERTY converter,
built as a native macOS menu-bar utility. A WidgetKit extension is optional and a Windows
notification-area utility comes later.

**`CLAUDE.md` is the working guide** — commands, architecture, the conversion path, and the
privacy invariant. Read `SPEC.md` for product behavior and `PLAN.md` for sequencing and
acceptance criteria before implementation.

## Current state

Slice 1 is built (0.1.0): SwiftPM package, two targets, the converter and its tests, the menu-bar
app, and packaging. It is **not** documentation-only any more, and it is **not** an Xcode project
— there is no `.xcodeproj`. Keep the package buildable and the suite green after each change.

## Design rules

- Keep keyboard conversion pure, deterministic, synchronous, and independent of SwiftUI, AppKit,
  clipboard state, or persistence.
- Keep the converter behind the `KeyboardConverting` interface described in `PLAN.md`.
- Walk Unicode **scalars**, never `Character`s — Thai combining marks fuse with the preceding
  consonant, so a Character-based loop silently skips text.
- Preserve unmapped characters exactly; never normalize or silently discard Unicode.
- Mixed mode converts a run **only when that run is malformed in its own script**. The judgement
  is structural and dictionary-free. Do not make it more aggressive without measuring the false
  positives — mangling correct text is a worse failure than leaving a mistyping, which the user
  can see and fix by switching to an explicit mode.
- Keep the explicit EN → TH and TH → EN modes mechanical. They are the escape hatch.
- Read the clipboard only from an explicit Paste action. Write it only from an explicit Copy action.
- Do not store entered or converted text, add analytics, or make network requests.
- Follow native macOS behavior and accessibility conventions. Use the sunset-mango accent as an
  accent, not as a replacement for system controls.
- Add a seam only when at least two adapters exist or a platform side effect must be replaced in
  tests.

## Testing

- Add a failing behavior test before fixing converter defects.
- Cover every unshifted and shifted Kedmanee mapping in both directions.
- Cover whitespace, newlines, punctuation, emoji, unmapped Unicode, empty input, long input, and
  Mixed runs.
- Keep portable cases in `Fixtures/conversion-cases.json` so a later Windows implementation can run
  the same contract.
- Tests and callers should exercise the public converter interface rather than mapping internals.
- Assert known limitations as tests rather than leaving them as comments, so the miss rate stays
  visible instead of being rediscovered.

## Documentation

Update `SPEC.md` when product behavior changes. Update `PLAN.md` when a platform or architecture
decision changes. Update `CLAUDE.md` when commands, architecture, or the measured gate accuracy
change. Do not describe WidgetKit as supporting free-form text entry unless Apple adds and
documents that capability.
