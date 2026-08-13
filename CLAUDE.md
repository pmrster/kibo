# CLAUDE.md

## What this is

**Kibo** — “ใครลืมเปลี่ยนภาษา”, a macOS menu-bar utility that fixes text typed with the wrong keyboard
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
swift run Kibo               # run from source; glyph appears top-right
swift test --filter KeyboardConverterTests    # one test class
swift test --filter RunJudgeTests/test_neutral_runs_are_never_converted   # one method
swift Tools/dump-kedmanee.swift               # re-dump the key table from macOS layout data
swift Tools/dump-kedmanee.swift --json        # same, as the Fixtures mapping array
Packaging/package.sh [version]                # → dist/Kibo.app + .dmg

# Design review. Opt-in behind a compile flag, so it is absent from normal debug AND release
# builds — renders the surfaces to PNGs offscreen and exits:
swift run -Xswiftc -DKIBO_SNAPSHOT Kibo --snapshot [dir]   # → ./assets
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
`pkill -x Kibo`.

## Naming

The app is **Kibo**, and so is everything else: SwiftPM package, executable target and source dir
(`Sources/Kibo/`), library target `KiboCore`, tests `KiboCoreTests`, and the `.app`. Kibo is also
the mascot — the app is named after the ghost, which is why `KiboView` draws a ghost and not a
window.

“Who Forgot To Change Lang” is now the **subtitle**: it appears under the name in About and in
prose, because it says what the thing does where "Kibo" only says what it is called. The Thai name
“ใครลืมเปลี่ยนภาษา” remains the project's name in Thai. The repo directory is `kibo` too — unlike
Tama, whose directory is still `tama-widget`, this one has no legacy path to work around.

## Architecture

Two targets, with a deliberate split:

- **`KiboCore`** — all logic, zero AppKit/SwiftUI. Dependencies are injected
  (the clipboard, the converter, the defaults store) so everything is testable without a running
  app. Fully unit-tested.
- **`Kibo`** — the SwiftUI/AppKit shell. Thin; not unit-tested.

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
  picker never did. It now lives in `SharedViews.swift` as `ThemedSegmentedControl` and Settings
  uses it too — Settings kept its two segmented `Picker`s long after the ban, which is why its
  snapshots were yellow no-entry blocks. **Use it anywhere a segmented picker is tempting.**
- **Type** — `AppFont.title` for the app's name: the system font at semibold, the same face
  as the `INPUT` / `RESULT` labels. It arrived by elimination — rounded heavy read as a toy,
  condensed black as dated, and Space Grotesk looked right but lived in one developer's
  `~/Library/Fonts`, so every other Mac would have fallen back silently. **Do not depend on a face
  the app cannot guarantee.** If this ever wants more character without bundling anything, macOS
  also ships Avenir Next and Chakra Petch (the latter covers Thai). `AppFont.ui` for other English
  chrome; `AppFont.thai` for
  the input and result fields, which can contain Thai. That is **Noto Sans Thai**, which macOS ships: the system
  Thai face crowds vowel and tone marks at 11–13pt, and those marks are the whole point here.
  Nothing is bundled, and the helper falls back to the system font if the family is missing.
- **Mascot** (`KiboSprite.swift`, `KiboView.swift`) — an original 8-bit ghost. **One colour,
  features cut out as holes**, the same construction Tama uses; it flips between midnight and pale
  so it is always the opposite of what it sits on.
  - **Never apply `scaleEffect` to it.** A `Canvas` rasterises at its natural size, so scaling
    stretches the result and the sprite comes out jagged — this is exactly why it once looked
    broken next to Tama's crisp cat. Pass a larger `pixelSize` instead, in whole numbers, so every
    rectangle lands on a whole pixel. Tama draws at native size for the same reason.
  - **It perches, it does not hide.** The caller overlaps it into the opaque surface below by
    `KiboView.tailTuck()` — two rows, so only the tails tuck behind the edge. An earlier version
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
- **Language** — the interface is English, matching the app's English name: labels, buttons and
  badges, all of them. **The one exception is the mode picker's tooltips, which are Thai**
  (`ConverterView.helpText(for:)`). Four labels that terse cannot say what separates them, and the
  distinction that costs the most to learn by accident — Both converts correct text, Mixed spares
  it — is worth more to a Thai speaker in Thai than the consistency is worth. Keep the exception
  to explanatory text; if a *label* ever wants Thai, that is a different decision. Everywhere else
  Thai appears only in the text being converted, which is why `AppFont.thai` is used by the input
  and result fields and nothing else.
- **Mode order is most-used first** — Both, EN → TH, TH → EN, Mixed — set by the declaration order
  of `ConversionMode`, which the picker and the ⌘1–⌘4 shortcuts are both built from.
- **A fresh install opens in Both**, via `ConversionMode.default` — one constant, because three
  sites need the answer and two of them could otherwise drift. It is deliberately *not*
  `allCases.first`: picker order is presentation and may be reshuffled, the default is behaviour.
  This is a product decision that trades safety for usefulness — Both converts correct text, so a
  first-time user pasting something already right will see it mangled, against a Mixed default
  that would sometimes appear to do nothing at all. The result field is a preview, not an action,
  which is what makes the trade acceptable. Returning users are unaffected: they get `lastMode`.

`AppSettings` is an `ObservableObject` while `ConverterModel` is `@Observable`. That is not an
oversight: `StatusItemController` is AppKit and needs to *subscribe* to appearance changes
(`NSPopover` does not inherit `NSApp.appearance` and must be recoloured by hand), which Combine
gives for free. `ConverterModel` has only SwiftUI consumers.

### The conversion path

```
input ──▶ RunSplitter ──▶ RunJudge ──▶ KedmaneeMapping ──▶ output
             (runs)      (convert?)      (per scalar)
                                     ↖ TypographicSubstitutes
                                        (which key was that?)
```

- **`KedmaneeMapping`** — 94 key pairs, all printable ASCII, a bijection. **Dumped from macOS's
  own layout data**, not transcribed: `Tools/dump-kedmanee.swift` asks `UCKeyTranslate` what each
  physical key produces under `com.apple.keylayout.US` and `com.apple.keylayout.Thai`. This is the
  verification `PLAN.md` asked for, and it corrected two keys a hand table had backwards (`3`
  produces `_`, and the backtick produces `-`).
- **`TypographicSubstitutes`** — **the OS rewrites the keystroke before the converter sees it.**
  `NSTextView`, which backs `TextEditor`, enables quote and dash substitution by default, so a
  typed `'` arrives as `’`. Three of those substituted keys carry Kedmanee characters — `'` is
  `ง`, `"` is `.`, `-` is `ข` — so `ง` was unreachable from the keyboard, surviving even the
  mechanical EN → TH flip because `’` is in no table. Note `.autocorrectionDisabled(true)` does
  **not** cover this; it clears spelling correction alone, and a comment here claimed otherwise
  for a while. `AppDelegate.disableTypographicSubstitution` now registers the two defaults off,
  but that is a courtesy to the user's text, not the fix: **Paste is a first-class path**, and
  text copied from Messages or Slack arrives already curled. The fold is deliberately *outside*
  `KedmaneeMapping` — it is many-to-one, has no inverse, and applies in the QWERTY → Thai
  direction only. It also fires **only on scalars actually being converted**, so text Mixed mode
  passes through keeps its curls; straightening them would mangle text the app promised not to
  touch. `…` is excluded because it stands for three keystrokes, not one.
- **`RunSplitter`** — maximal runs of Thai (`U+0E00–U+0E7F`), Latin (printable ASCII, space
  excluded so whitespace is a boundary), or neutral. Runs always rejoin to the input exactly.
  The typographic substitutes count as Latin despite being outside ASCII: left neutral, `’` cut
  `don’t` into three runs and `RunJudge` never saw a word to judge.
- **`RunJudge`** — the convert-or-keep decision, used only by Mixed mode.
- **`KeyboardConverter`** — the public `KeyboardConverting` interface. The two explicit directions
  are mechanical whole-string flips; Mixed and `swapAll` share one run walk and differ only in the
  predicate they pass it — `RunJudge.shouldConvert` against a constant `true`. **`swapAll` ("Both"
  in the UI) flips every run the way its own script implies**, which is the only mode that fixes
  text mistyped in *both* directions at once — switch layout mid-sentence and neither explicit
  direction helps, because each leaves the other script alone. It exists because Mixed provably
  cannot do this: see the three rejected approaches below.

**Everything walks `unicodeScalars`, never `Character`.** Thai combining marks fuse with the
consonant before them, so `"สวัสดี"` is six scalars but only four Characters. A Character-based
loop would be handed clusters that appear in no table and would pass them through unconverted.
The mapping table is typed `[(UnicodeScalar, UnicodeScalar)]` so the compiler rejects a
multi-scalar entry outright.

### Mixed mode and what it cannot do

Mixed converts a run **only if that run is malformed in its own script**, which is why
`สวัสดี hello ครับ 2024 :)` keeps `ครับ` and `2024`. The gate is dictionary-free, judged on
orthography:

- **Thai** — a vowel or tone mark needs a consonant before it; a leading vowel (`เ แ โ ใ ไ`) needs
  a consonant after it; the same mark never repeats; and **a combining vowel never follows a
  spacing vowel** (`ะ า ำ ๅ`), which complete the syllable and leave nothing to attach to. That
  last rule is what catches the `-ture` family — `t` is `ะ` and `u` is `ี`, so `feature` lands
  `ะี` mid-word — and it needed adding because `hasBase` alone still counted the consonant two
  characters back. **Tone marks are exempt from it on purpose**: `นำ้` is `น้ำ` with the tone and
  the sara am the wrong way round, which is sloppy but real Thai, and it was the one false
  positive found when the rule was measured against 103 real words. No dictionary means no word
  segmentation, which matters because written Thai has no spaces.
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

The corpora live in `Tests/KiboCoreTests/AccuracyCorpus.swift` and the figures are asserted by
`MeasuredAccuracyTests`, **end to end through `KeyboardConverter` in Mixed mode** — a gate verdict
is not a promise about the output. Counts are asserted too, so deleting an awkward entry fails
rather than quietly lowering the bar. Every case is mirrored into `Fixtures/conversion-cases.json`,
so a Windows port inherits the same numbers instead of a sample of them.

| Measure | Result | Notes |
| --- | --- | --- |
| **Precision** — correct text left untouched | 36 of 36 | `AccuracyCorpus.mustSurvive` |
| Recall — English mistyped as Thai | 19 of 30 | missed: about, please, sorry, code, ok, and, report, great, work, value, issue |
| Recall — Thai mistyped as Latin | 4 of 12 | missed: โรงเรียน, ผม, แมว, ไป, กิน, ทำงาน, วันนี้, พรุ่งนี้ |

(The English figure read "16 of 25" here for a while, "17 of a 26-word sample" in a test comment,
and measured 15 of 24. Three numbers, no test counting any of them — which is what the count
assertions now prevent. It later went to 19 of 30 when the spacing-vowel rule landed: the corpus
grew by the whole `-ture`/`-ue` family that was measured together — feature, picture, future,
nature, value, issue — and not just the four the rule rescued. **Add the losses with the wins**,
or the figure is advertising rather than measurement.)

The misses are wreckage that happens to be well-formed — `แนกำ` ("code") breaks no Thai rule, and
`นา` ("ok") is a real Thai word that not even a dictionary would rescue. **The escape hatch is the
three mechanical modes, which never consult the gate.** Do not "improve" recall without
re-measuring precision: mangling correct text is a worse failure than leaving a mistyping, because
the user can see and fix the latter.

### Three ways to raise recall that were measured and rejected

Reported as "Mixed does nothing" against `vtwiot gTv0twxpy'w'vt เพฟิ sinv0twxi5g,]N` — a Thai
sentence typed on the US layout with one English word typed on the Thai one. Every run is a miss.
Each fix below looks obvious, and each was killed by measurement. **Do not re-attempt these
without new evidence.**

1. **Apply the letter-poor path's question — "does this flip to well-formed Thai?" — to runs that
   have letters.** Measured against `/usr/share/dict/words` (235,762 words): **36% flip to
   well-formed, entirely-Thai text containing a vowel mark** — `abandon`, `aardvark`, `abalone`,
   `abdicate`. `rhythm` is not an outlier, it is a third of English. Requiring a leading-vowel
   syllable as well only cuts it to 14%. This is why the path is fenced to runs with too few
   letters to judge, and the fence must stay.
2. **Flag letter pairs English never writes.** Only 59 of 676 bigrams are absent from that
   dictionary, and the reported runs hit two of them (`vt`, `wx`), with just one false positive in
   the precision corpus (`SQL`, already covered by the all-caps skip). It still fails: the word
   list is pre-war and has no technical vocabulary, so the rule mangles `json`, `sqlite`,
   `qwerty`, `docx`, `xlsx`, `tsx`, `jsx` and `mysqldump`.
3. **Require every Latin run in the input to flip, so agreement carries the decision.** Zero of
   ten ordinary English sentences tripped it, and the reported input is 3 of 3 — but `come look at
   my one` and `let me look at it` are 5 of 5, and `let me make some` is 4 of 4. Dead at any
   threshold.

The conclusion is not "try harder": **Thai-on-QWERTY and English are the same distribution by
spelling shape.** The only signal with real information is a Thai wordlist, which would segment
`อะไรนะ` into `อะไร` + `นะ` while `let me make some` flips to non-words. That stays unbuilt —
it contradicts the dictionary-free design, and `swapAll` covers the reported case for nothing.

## Testing

- Add a failing behaviour test before fixing a converter defect.
- Tests exercise the public converter interface, not mapping internals.
- `Fixtures/conversion-cases.json` is the portable behaviour contract for a later Windows port:
  the full key table, the `typographicSubstitutes` fold, a `schema` block describing the format
  for a non-Swift reader, and 136 cases across all four modes — the whole precision corpus, both
  recall corpora, and the known misses.
  `FixtureConformanceTests` reads it from the repo via `#filePath` — there is no resource bundle,
  and a test that reaches for the real file cannot silently pass against a stale copy. It also
  asserts the JSON still carries every string in `AccuracyCorpus`, so the two cannot drift.
  **Regenerate rather than hand-edit**, and bump `version` when the shape changes.
- Known limitations are asserted as tests, not left as comments, so the miss rate stays visible.

## Privacy invariant (do not break)

- **No network.** Not for updates, not for analytics, not for dictionaries. Enforced by the
  sandbox — `Packaging/Kibo.entitlements` grants `app-sandbox` and *no* network entitlement, so
  the kernel refuses the connection rather than the code declining to make one. `package.sh`
  refuses to build without that file and verifies the signature carries it. Verify a running app
  with `lsof -a -p $(pgrep -x Kibo) -i`. **The `-a` matters**: `lsof` ORs its selectors, so the
  command without it prints every *other* process's sockets and looks alarming.
- **A Copy is marked as a secret.** `SystemClipboard.write` sets `org.nspasteboard.ConcealedType`
  and `TransientType` alongside the string, which is what keeps the text out of clipboard-manager
  history. This matters more than it looks: the app's use case means the text is often a password,
  and Universal Clipboard hands `NSPasteboard.general` to nearby Apple devices — the one route by
  which a local-only app can still put a secret on the air, and one `lsof` will never show.
- **Window restoration is off** (`FloatingPanel`, plus `applicationSupportsSecureRestorableState`).
  AppKit would otherwise encode a text view's contents into `~/Library/Saved Application State/`.
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

The script owns three things the test suite cannot see, so read its output rather than assuming:

- **Version and build number are injected**, by key name via PlistBuddy — `CFBundleShortVersionString`
  from the argument, `CFBundleVersion` from `git rev-list --count HEAD`. The literals in
  `Packaging/Info.plist` are placeholders; editing them changes nothing. About reads the packaged
  plist, so there is one source of truth. Tag releases `v<version>` to match.
- **The sandbox is applied on both signing paths**, ad-hoc included, and the script *fails* if
  `Packaging/Kibo.entitlements` is missing or if the signature comes out without the entitlement.
  It referenced an entitlements file that never existed for a while, which meant every build —
  including the Developer ID path — shipped unsandboxed.
- **The icon is generated** from `icon.png` with `sips`/`iconutil`. `Info.plist` declares
  `CFBundleIconFile`, so before this the DMG shipped a blank generic icon.

## Commit hygiene

Before every commit, review `git status --short --ignored` and keep local-only files out. Do not
commit build outputs, release artifacts, local state, agent caches, IDE metadata, secrets, or
temporary files. Expected local-only paths: `.build/`, `dist/`, `state/`, `.superpowers/`,
`.DS_Store`, `.env*`, certificates and profiles. If a new local-only artifact appears, add it to
`.gitignore` before committing.
