# Repository guidance

**Kibo** (“Who Forgot To Change Lang” · ใครลืมเปลี่ยนภาษา) is a local-only macOS menu-bar utility that
fixes text typed with the wrong keyboard layout, between Thai Kedmanee and US QWERTY.

**`CLAUDE.md` is the working guide** — commands, architecture, the conversion path, the measured
accuracy figures, and the privacy invariant. Read it before a non-trivial change. `SPEC.md` has
the product behaviour, `PLAN.md` the sequencing, and `CONTRIBUTING.md` the short list of rules a
well-meaning change most easily breaks.

It is a plain SwiftPM package (Swift 6, macOS 14+) with no `.xcodeproj` and no dependencies. Keep
`swift build` warning-free and `swift test` green after each change.

## Non-negotiables

- **Privacy.** No network, no analytics, no stored text. The clipboard is read only from Paste and
  written only from Copy, and the tests count accesses. The sandbox has no network entitlement.
- **Precision over recall.** Mixed mode converts a run only when it is malformed in its own
  script. `MeasuredAccuracyTests` pins the figures; do not raise recall without re-measuring what
  it mangles, and report both directions.
- **Scalars, never `Character`s.** Thai combining marks fuse with the consonant before them, so a
  per-`Character` loop silently skips text.
- **Logic in `KiboCore`, never in the shell.** Core has zero AppKit/SwiftUI and is fully tested.
- **The key table is dumped, not typed** (`Tools/dump-kedmanee.swift`). Regenerate it; never
  hand-edit it.
- **No segmented `Picker` and no SwiftUI `Toggle`** — both paint with the system accent. Use
  `ThemedSegmentedControl` and `ThemedToggle`.
- **No dependencies.** `Package.swift` declares none, and that is a feature.

## Documentation

Update `SPEC.md` when product behaviour changes, `PLAN.md` when an architecture decision changes,
`CLAUDE.md` when commands, architecture, or the measured accuracy change, and `CHANGELOG.md` for
anything a user would notice.
