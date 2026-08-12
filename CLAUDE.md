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

- **Palette** (`Theme.swift`) — Tama's warm neutrals verbatim so the two apps read as siblings,
  under a **near-monochrome accent** that matches the mascot (midnight on light, pale on dark).
  It was mango; the orange fought everything once the mascot went midnight-and-pale. Green is the
  one colour left, on the copy confirmation and the privacy badge. Colors come from an NSColor
  dynamic provider via `Color(light:dark:)`, so they re-resolve when the appearance is forced.
- **The mode control is hand-rolled, not a segmented `Picker`.** A segmented picker paints its
  selection with the *system* accent — whatever the user set in System Settings — so on a Mac with
  a yellow accent the selected mode came out bright yellow and wrecked the palette. macOS offers
  no supported override. The replacement also renders in `--snapshot`, which the AppKit-backed
  picker never did.
- **Type** — `AppFont.title` for the app's name: the system font at heavy weight, the same face
  as the `INPUT` / `RESULT` labels. It arrived by elimination — rounded heavy read as a toy,
  condensed black as dated, and Space Grotesk looked right but lived in one developer's
  `~/Library/Fonts`, so every other Mac would have fallen back silently. **Do not depend on a face
  the app cannot guarantee.** If this ever wants more character without bundling anything, macOS
  also ships Avenir Next and Chakra Petch (the latter covers Thai). `AppFont.ui` for other English
  chrome; `AppFont.thai` for
  the input and result fields, which can contain Thai. That is **Noto Sans Thai**, which macOS ships: the system
  Thai face crowds vowel and tone marks at 11–13pt, and those marks are the whole point here.
  Nothing is bundled, and the helper falls back to the system font if the family is missing.
- **Mascot** (`GhostSprite.swift`, `GhostView.swift`) — an original 8-bit ghost. **One colour,
  features cut out as holes**, the same construction Tama uses; it flips between midnight and pale
  so it is always the opposite of what it sits on.
  - **Never apply `scaleEffect` to it.** A `Canvas` rasterises at its natural size, so scaling
    stretches the result and the sprite comes out jagged — this is exactly why it once looked
    broken next to Tama's crisp cat. Pass a larger `pixelSize` instead, in whole numbers, so every
    rectangle lands on a whole pixel. Tama draws at native size for the same reason.
  - **It perches, it does not hide.** The caller overlaps it into the opaque surface below by
    `GhostView.tailTuck()` — two rows, so only the tails tuck behind the edge. An earlier version
    sank ten rows so only the eyes showed, and the first question anyone asked was why the mascot
    was hiding. `Palette.fieldFill` is opaque so the overlap reads as occlusion.
  - **Small vertical eyes, and no mouth.** Three-by-three blocks read as goggles, two-by-two as a
    stare; slits read as a face. At this size a mouth is either a slab or a nose, and Tama's cat
    proves two holes are enough.
  - Proportions follow `icon.png` in the repo root. Earlier misses: a near-square body (reads as a
    rounded hill), a crown that reached full width in three rows, and a hem of shallow notches
    (the tails need two rows at full gap width).
  - Colour history: an outlined body with a yellow mouth read as cluttered — three tones fighting
    inside sixteen pixels.
- **Menu-bar glyph** (`MenuBarIcon.swift`) — Kibo's silhouette, eyes kept as holes (a template
  image preserves alpha, and the holes are what stop it reading as a blob at 16px). **The mascot
  can be the glyph only because it is a ghost.** When the mascot was a cat forked from Tama's
  sprite, the glyph was indistinguishable from Tama's in a real menu bar, and a `ก` keycap outline
  stood in. A ghost beside a cat has no such problem. Rejected glyphs, all rendered at true size
  first: a pixel keycap (read as a monitor), pixel swap arrows (a smudge), `ก⇄A` (too wide).
- **Language** — the interface is entirely English, matching the app's English name. Thai appears
  only in the text being converted, which is why `AppFont.thai` is now used only by the input and
  result fields.

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
`C:\Users\alice` into Thai. That is why the vowel rule needs six letters, why `[ ] \` are *not*
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
