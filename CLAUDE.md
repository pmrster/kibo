# CLAUDE.md

## What this is

“ใครลืมเปลี่ยนภาษา” — a macOS menu-bar utility that fixes text typed with the wrong keyboard
layout, between Thai Kedmanee and US QWERTY. Local-only, no network, no stored text.

Read `SPEC.md` for product behaviour and `PLAN.md` for architecture and sequencing.

This app is a spin-off of **Tama** (`../tama-widget`, `pmrster/tama`) and forks its shell: the
SwiftPM layout, the `Color(light:dark:)` theming, `AppSettings`, the status-item/panel chrome, and
the packaging script all came from there. Separate repo, separate release cycle, shared look.

## Commands

SwiftPM package, Swift 6 / macOS 14+. No `package.json`, no `.xcodeproj`.

```bash
swift build                                   # debug build
swift test                                    # full suite (XCTest, all in the Core test target)
swift run WhoForgotToChangeLang               # run from source; glyph appears top-right
swift test --filter KeyboardConverterTests    # one test class
swift test --filter RunJudgeTests/test_neutral_runs_are_never_converted   # one method
swift Tools/dump-kedmanee.swift               # re-dump the key table from macOS layout data
swift Tools/dump-kedmanee.swift --json        # same, as the Fixtures mapping array
Packaging/package.sh [version]                # → dist/WhoForgotToChangeLang.app + .dmg

# Design review. Opt-in behind a compile flag, so it is absent from normal debug AND release
# builds — renders the surfaces to PNGs offscreen and exits:
swift run -Xswiftc -DWFCL_SNAPSHOT WhoForgotToChangeLang --snapshot [dir]   # → ./assets
```

`--snapshot` exists because screen capture needs a permission a terminal often lacks, which
otherwise makes "does this actually look right?" unanswerable without a human at the keyboard.
**Read its output with that limit in mind:** `ImageRenderer` cannot draw AppKit-backed controls,
so `Picker`, `TextEditor` and `ScrollView` come out as yellow no-entry blocks or blank boxes. That
is the renderer, not a bug. Everything else — layout, palette, typography, the mascot — is
faithful.

The app has no Dock icon (`LSUIElement`, plus `setActivationPolicy(.accessory)` so `swift run`
behaves the same as the packaged build). Look at the top-right menu bar. Left-click the glyph
opens the converter; right-click opens About / Settings / Quit. Quit from there or with
`pkill -x WhoForgotToChangeLang`.

## Naming

Everything is **WhoForgotToChangeLang**: SwiftPM package, executable target and source dir
(`Sources/WhoForgotToChangeLang/`), library target `WhoForgotToChangeLangCore`, tests
`WhoForgotToChangeLangCoreTests`, and the `.app`. The repo directory is `who-forget-to-change-lang`
and the user-facing display name is the Thai title — neither is used as an identifier.

## Architecture

Two targets, with a deliberate split:

- **`WhoForgotToChangeLangCore`** — all logic, zero AppKit/SwiftUI. Dependencies are injected
  (the clipboard, the converter, the defaults store) so everything is testable without a running
  app. Fully unit-tested.
- **`WhoForgotToChangeLang`** — the SwiftUI/AppKit shell. Thin; not unit-tested.

`ConverterModel` lives in Core, not the shell, because it is logic. The shell supplies it a
`SystemClipboard`; tests supply an `InMemoryClipboard` that counts accesses.

### Design

- **Palette** (`Theme.swift`) — Tama's neutrals verbatim so the two apps read as siblings in the
  menu bar; the accent is mango where Tama's is yellow. Colors come from an NSColor dynamic
  provider via `Color(light:dark:)`, so they re-resolve when the appearance is forced.
- **Type** — `AppFont.title` for the app's name: the system font's condensed black weight. It
  started as rounded heavy and read as a toy; this is a utility. `AppFont.ui` for other English
  chrome (plain system font, stays native); `AppFont.thai` for
  anything that can contain Thai. The latter is **Noto Sans Thai**, which macOS ships: the system
  Thai face crowds vowel and tone marks at 11–13pt, and those marks are the whole point here.
  Nothing is bundled, and the helper falls back to the system font if the family is missing.
- **Mascot** (`GhostSprite.swift`, `GhostView.swift`) — an original 8-bit ghost, assembled from
  interchangeable bands (dome / eyes / mouth / hem) so the expression changes without redrawing
  the body. Body and outline swap between appearances so it is always the opposite of what it sits
  on; one warm yellow marks the mouth. **It must be laid out directly above whatever it hides
  behind** — the peekaboo is a clip, not a pose. Currently that is the input field.
  - An earlier mascot borrowed Tama's cat sprite and looked it once enlarged: that geometry is
    built for a 24×15 menu-bar pet, not for display.
  - Three attempts drew the ghost covering its face with its own paws. Every one read as
    spectacles — at this resolution an outlined square over a face is a *lens*, not a hand.
    Occlusion solved in one attempt what reshaping could not solve in three.
  - The drop distance is load-bearing: at nine rows only the dome cleared the edge and it read as
    a bump. Both eye rows have to show.
- **Menu-bar glyph** (`MenuBarIcon.swift`) — a keycap outline with `ก`, and deliberately **not**
  the mascot. A glyph up there has to *identify* the app; matching a sibling app defeats the
  purpose. A cat silhouette was tried and was indistinguishable from Tama's at 18px. Rejected
  alternatives, all rendered at true size first: a pixel keycap (read as a monitor), pixel swap
  arrows (a smudge), and `ก⇄A` (too wide for what it added).
- **Language** — chrome is English, matching the app's English name. Thai stays where it is
  content rather than labelling: the conversion examples and the privacy capsule.

`AppSettings` is an `ObservableObject` while `ConverterModel` is `@Observable`. That is not an
oversight: `StatusItemController` is AppKit and needs to *subscribe* to appearance changes
(`NSPopover` does not inherit `NSApp.appearance` and must be recoloured by hand), which Combine
gives for free. `ConverterModel` has only SwiftUI consumers.

### The conversion path

```
input ──▶ RunSplitter ──▶ RunJudge ──▶ KedmaneeMapping ──▶ output
             (runs)      (convert?)      (per scalar)
```

- **`KedmaneeMapping`** — 94 key pairs, all printable ASCII, a bijection. **Dumped from macOS's
  own layout data**, not transcribed: `Tools/dump-kedmanee.swift` asks `UCKeyTranslate` what each
  physical key produces under `com.apple.keylayout.US` and `com.apple.keylayout.Thai`. This is the
  verification `PLAN.md` asked for, and it corrected two keys a hand table had backwards (`3`
  produces `_`, and the backtick produces `-`).
- **`RunSplitter`** — maximal runs of Thai (`U+0E00–U+0E7F`), Latin (printable ASCII, space
  excluded so whitespace is a boundary), or neutral. Runs always rejoin to the input exactly.
- **`RunJudge`** — the convert-or-keep decision, used only by Mixed mode.
- **`KeyboardConverter`** — the public `KeyboardConverting` interface. Explicit modes are
  mechanical whole-string flips; Mixed asks `RunJudge` per run.

**Everything walks `unicodeScalars`, never `Character`.** Thai combining marks fuse with the
consonant before them, so `"สวัสดี"` is six scalars but only four Characters. A Character-based
loop would be handed clusters that appear in no table and would pass them through unconverted.
The mapping table is typed `[(UnicodeScalar, UnicodeScalar)]` so the compiler rejects a
multi-scalar entry outright.

### Mixed mode and what it cannot do

Mixed converts a run **only if that run is malformed in its own script**, which is why
`สวัสดี wet ครับ 2024 :)` keeps `ครับ` and `2024`. The gate is dictionary-free, judged on
orthography:

- **Thai** — a vowel or tone mark needs a consonant before it; a leading vowel (`เ แ โ ใ ไ`) needs
  a consonant after it; the same mark never repeats. No dictionary means no word segmentation,
  which matters because written Thai has no spaces.
- **Latin** — runs with fewer than three letters are not judged; a `;` between two letters gives a
  mistyping away; otherwise a 6+ consonant pile-up, or no vowel at all in a word of six letters or
  more, condemns it. Measured per letter-group so `index.html` is not read as `indexhtml`, and
  all-caps groups are skipped as acronyms.
- **The letter-poor path** — Thai consonants sit on digit and punctuation keys, so `ขอบคุณ`
  mistypes to `-v[86I` with two letters in it. For runs with too few letters to judge, `RunJudge`
  asks the opposite question: does this convert into fully-Thai, well-formed text containing a
  vowel mark? Strictly guarded — applying it to runs that *do* have letters would convert
  `rhythm`, which maps to well-formed Thai and is not a mistyping.

**Every threshold here was set by measuring false positives, not by intuition.** An earlier,
more aggressive version converted `HTML`, `SQL`, `npm`, `https://example.com`, `array[i]` and
`C:\Users\pmr` into Thai. That is why the vowel rule needs six letters, why `[ ] \` are *not*
treated as keyboard-only characters, why all-caps groups are skipped, and why the letter-poor path
needs four characters.

**Measured accuracy** (all three figures are pinned by tests, so a change that trades one for
another shows up as a failure):

| Measure | Result | Notes |
| --- | --- | --- |
| **Precision** — correct text left untouched | 36 of 36 | `KeyboardConverterTests.test_mixed_returns_correct_text_completely_unchanged` |
| Recall — English mistyped as Thai | 16 of 25 | missed: about, please, sorry, code, ok, and, report, great, work |
| Recall — Thai mistyped as Latin | 4 of 12 | missed: โรงเรียน, ผม, แมว, ไป, กิน, ทำงาน, วันนี้, พรุ่งนี้ |

The misses are wreckage that happens to be well-formed — `แนกำ` ("code") breaks no Thai rule, and
`นา` ("ok") is a real Thai word that not even a dictionary would rescue. **The escape hatch is the
explicit EN → TH / TH → EN modes, which are mechanical and never consult the gate.** Do not
"improve" recall without re-measuring precision: mangling correct text is a worse failure than
leaving a mistyping, because the user can see and fix the latter.

## Testing

- Add a failing behaviour test before fixing a converter defect.
- Tests exercise the public converter interface, not mapping internals.
- `Fixtures/conversion-cases.json` is the portable behaviour contract for a later Windows port:
  the full key table plus 24 cases across all three modes. `FixtureConformanceTests` reads it from
  the repo via `#filePath` — there is no resource bundle, and a test that reaches for the real file
  cannot silently pass against a stale copy.
- Known limitations are asserted as tests, not left as comments, so the miss rate stays visible.

## Privacy invariant (do not break)

- **No network.** Not for updates, not for analytics, not for dictionaries. Verify with
  `lsof -p $(pgrep -x WhoForgotToChangeLang) -i`.
- **The clipboard is read only from Paste and written only from Copy.** `Clipboard` is a
  two-method protocol with no "watch" operation to start using by accident, and
  `ConverterModelTests` counts accesses and fails if anything else reaches for it.
- **No entered or converted text is stored.** `SettingsStore` holds appearance, text size, and the
  last mode — there is nowhere to put anything else.

## Releasing

`dist/` is gitignored. Build locally with `Packaging/package.sh <version>` and ship the DMG as a
GitHub Release asset; git holds source, the Release holds binaries. Without `SIGN_IDENTITY` the
app is ad-hoc signed and users must right-click → Open once. For a public build set
`SIGN_IDENTITY`, `NOTARY_PROFILE`, and `REQUIRE_NOTARIZATION=1`. No signing identity is
provisioned yet.

## Commit hygiene

Before every commit, review `git status --short --ignored` and keep local-only files out. Do not
commit build outputs, release artifacts, local state, agent caches, IDE metadata, secrets, or
temporary files. Expected local-only paths: `.build/`, `dist/`, `state/`, `.superpowers/`,
`.DS_Store`, `.env*`, certificates and profiles. If a new local-only artifact appears, add it to
`.gitignore` before committing.
