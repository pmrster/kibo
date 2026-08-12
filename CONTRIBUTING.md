# Contributing

Thanks for looking. This is a small, opinionated project — the notes below are mostly about the
two or three places where a well-meaning change can quietly break something important.

## Getting set up

Requires macOS 14+ and a Swift 6 toolchain (Xcode 16 or the matching command-line tools). There is
no `.xcodeproj` and no `package.json`; it is a plain SwiftPM package.

```bash
swift build
swift test          # 97 tests, all in KiboCoreTests
swift run Kibo      # the glyph appears in the menu bar, top-right; quit with pkill -x Kibo
```

`CLAUDE.md` is the architecture document — read it before a non-trivial change. `SPEC.md` has the
product behaviour, `PLAN.md` the sequencing.

## The two rules that matter most

**1. Do not trade precision for recall.** Mixed mode converts text only when it looks mistyped,
and it is deliberately tuned to leave correct text alone even when that means missing a real
mistyping. Leaving a mistyping is recoverable — the user sees it and switches to an explicit mode.
Mangling text they typed correctly is not.

`MeasuredAccuracyTests` pins all three figures (36 of 36 precision, 15 of 24 English recall, 4 of
12 Thai recall). If your change moves any of them, the suite fails. That is the mechanism working.
Update `AccuracyCorpus`, re-run, and say in your PR what moved in **both** directions — a recall
improvement that costs a precision case will not be merged.

**2. Walk `unicodeScalars`, never `Character`.** Thai combining marks fuse with the consonant
before them, so `"สวัสดี"` is six scalars but four Characters. A per-`Character` loop is handed
clusters that appear in no mapping table and silently passes them through unconverted.

## Also worth knowing

- **The key table is dumped, not typed.** `Sources/KiboCore/Conversion/KedmaneeMapping.swift`
  comes from macOS's own layout data via `swift Tools/dump-kedmanee.swift`. Do not hand-edit it;
  regenerate it. Hand-transcription is how it once had two keys backwards.
- **Logic goes in `KiboCore`, not `Kibo`.** Core has zero AppKit/SwiftUI and is fully tested;
  the shell is thin and untested. If you find yourself writing a rule inside a SwiftUI view, it
  probably belongs in Core with a test.
- **Keep `Fixtures/conversion-cases.json` in step.** It is the contract a future Windows port has
  to pass. `FixtureConformanceTests` fails if the JSON drifts from the Swift corpus.
- **No segmented `Picker`.** It paints its selection with the *system* accent colour, which wrecks
  the palette on any Mac with a custom accent. Use `ThemedSegmentedControl`.
- **No dependencies.** `Package.swift` declares none, and that is a feature — it is also why there
  is no supply chain to audit. Please do not add one.
- **No network. Ever.** Not for updates, dictionaries, or analytics. See `PRIVACY.md`; the sandbox
  enforces it, so such a PR would not work anyway.

## Pull requests

- Add a failing test before fixing a converter defect.
- Test the public interface, not mapping internals.
- Assert known limitations as tests rather than leaving them as comments, so the miss rate stays
  visible.
- `swift build` should stay warning-free.
- Keep local-only files out: check `git status --short --ignored` before committing.

## Reporting things

Bugs and ideas: open an issue. Security or privacy problems: see [`SECURITY.md`](SECURITY.md) —
report those privately, not in a public issue.
