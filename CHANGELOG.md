# Changelog

All notable changes to this project are recorded here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.3.0] — 2026-08-24

First public release.

### Added

- **Fix it where it is.** A macOS Service, *Fix Layout with Kibo*: select mistyped text in any
  app, right-click → Services, and the selection is replaced in place, in whatever mode the
  converter is set to. Declared under `NSServices`, so the system launches Kibo on demand. It goes
  through `ConverterModel.convert(_:)`, which bypasses the input field — a conversion elsewhere
  never overwrites the popover — and never touches the general clipboard: the selection travels
  on the private per-invocation pasteboard macOS provides, and the tests count clipboard accesses
  on that path and require zero. There is no preview on this path; the host app's ⌘Z is the undo.
  It can be given a system-wide shortcut in System Settings → Keyboard → Keyboard Shortcuts →
  Services.
- **Open at login**, a switch in Settings, off by default. Backed by `SMAppService` with no
  defaults key of its own: the status is read back from the system after every request, so the
  switch cannot disagree with Login Items. `ThemedToggle` joins `ThemedSegmentedControl`, for the
  same reason it exists — a SwiftUI `Toggle` paints with the system accent.
- Neither works under `swift run`, which has no bundle; both are verified from a `package.sh`
  build.

### Changed

- **The README is written for a public repository**: name, subtitle and badges first, then a
  banner drawn from the sprite grid at a whole-number scale (`Tools/make-banner.py`), the worked
  example, converter mockups rendered from the app's own palette (`Tools/make-mockups.py`), and
  the mascot's blink and "boo~" as GIFs (`Tools/make-ghost-gif.py`). The status row carries no
  version number, so it cannot go stale.
- **Corrected a font claim.** `Theme.swift` and `CLAUDE.md` said macOS ships Noto Sans Thai. It
  does not: it resolved on the development Mac only because it was installed in
  `~/Library/Fonts`. The fallback to the system Thai face was already in place, so a stock Mac
  shows Thonburi in the text fields; the docs now say so.
- Stale counts in `CONTRIBUTING.md` and the CI workflow brought in line with the suite.
- Dependabot watches the GitHub Actions used by CI — the repository's only dependency of any kind.

## [0.2.4] — 2026-08-14

### Changed

- **The mode picker is ordered most-used first**: Both, EN → TH, TH → EN, Mixed, with `⌘1`–`⌘4`
  following.
- **A fresh install now opens in Both rather than Mixed.** New constant `ConversionMode.default`,
  because three sites needed the answer and two could have drifted from the third; it is not
  derived from the picker order, since that is presentation and this is behaviour. The trade is
  deliberate: Both converts correct text, so a first-time user pasting something already right
  will see it mangled, against a Mixed default that can appear to do nothing at all on text it
  cannot judge. The result field is a preview rather than an action, which is what makes that
  acceptable.
- *Upgrade note:* returning users are unaffected — a stored `lastMode` still wins, so only a fresh
  install or an unparseable stored value lands in Both.
- The `--snapshot` tooling now renders the default mode, which also makes it the run that catches
  badge overflow: "everything, both directions" is the longest of the four.
- **The worked example is now `l;ylfu ้ำสสน ครับ 2024 :)` → `สวัสดี hello ครับ 2024 :)`**, replacing
  `ไำะ` → `wet`, which read as an odd thing for anyone to have typed. It runs through the docs, the
  Settings preview, the snapshots and the fixture, so all of them move together. `world` was the
  first choice and cannot be used: it mistypes to `ไนพสก`, which breaks no Thai spelling rule — the
  leading vowel `ไ` has a consonant after it — so Mixed correctly leaves it alone, and an example
  that claimed otherwise would be advertising a conversion the app does not make.
- **The modes now carry Thai tooltips**, the only Thai in an otherwise English interface. Four
  labels that terse cannot say what separates them, and the distinction that costs most to learn
  by accident — Both converts correct text, Mixed spares it — is worth more to a Thai speaker in
  Thai than the consistency is worth. Labels, buttons and badges stay English. The same text is
  set as the accessibility hint.

## [0.2.3] — 2026-08-14

### Added

- **A fourth mode, "Both"**, which flips every run in the direction its own script implies — Thai
  runs to English, Latin runs to Thai, in one pass. Mechanical, like the two explicit directions,
  but per run rather than whole-string, so it is the only mode that fixes text mistyped in *both*
  directions at once. Switch layout halfway through a sentence and neither EN → TH nor TH → EN
  helps, because each leaves the other script alone. `⌘4`, and the Swap button is disabled for it
  as it is for Mixed, both being direction-symmetric.
- It converts correct text too. That is the deal: the user supplies the judgement, so there is
  nothing left for a gate to guess wrong.

### Changed

- Mixed and Both now share one run walk in `KeyboardConverter`, differing only in the predicate,
  so a run boundary fixed in one cannot drift from the other.
- **Recorded three ways to raise Mixed's recall that were measured and rejected**, so they are not
  re-attempted: relaxing the "does it flip to good Thai?" test (36% of a 235k-word dictionary flips
  to well-formed Thai), flagging letter pairs English never writes (mangles `json`, `sqlite`,
  `qwerty`, `docx`, `tsx`), and requiring every run in the input to agree (`come look at my one` is
  5 of 5). Thai-on-QWERTY and English are the same distribution by spelling shape; only a wordlist
  carries real information, and that stays unbuilt.

## [0.2.2] — 2026-08-14

### Fixed

- **Mixed mode now catches the `-ture` family** — `feature`, `picture`, `future`, `nature` typed
  with the Thai layout on. `ThaiOrthography` gained one rule: a *combining* vowel may not follow a
  *spacing* vowel (`ะ า ำ ๅ`), which completes the syllable and leaves nothing to attach to. On
  the Thai layout `t` is `ะ` and `u` is `ี`, so those words land `ะี` mid-word — unpronounceable,
  but every earlier rule was satisfied because the consonant two characters back still counted as
  a base. Reported against `ดำฟะีพำ`, which Mixed handed back untouched.
- Tone marks are exempt from the new rule, deliberately. `นำ้` is `น้ำ` with the tone mark and the
  sara am encoded the wrong way round — sloppy, but real Thai, and it was the only false positive
  the rule produced when measured against 103 real Thai words.

### Changed

- **English recall is now 19 of 30, up from 15 of 24.** The corpus grew by the whole family that
  was measured together — feature, picture, future, nature, *and* the two the rule does not
  rescue, value and issue. Adding only the wins would have inflated the figure. Precision is
  unchanged at 36 of 36, and Thai recall at 4 of 12.
- `Fixtures/conversion-cases.json` carries the six new cases (132 total).

## [0.2.1] — 2026-08-14

### Fixed

- **A typed apostrophe could not produce `ง`.** `NSTextView`, which backs SwiftUI's `TextEditor`,
  enables quote and dash substitution by default, so `'` reached the converter as `’` (U+2019) — a
  character on no key, absent from the dumped table, and neutral to `RunSplitter`. It survived
  even the mechanical EN → TH flip. The same applied to `"` → `“”` (the `.` key) and `-` → `–`
  (the `ข` key). `autocorrectionDisabled(true)` does not cover this; measured against the real
  view hierarchy, it clears spelling correction alone.
- `TypographicSubstitutes` folds those six characters back onto the key that was pressed, in the
  QWERTY → Thai direction only and only on scalars actually being converted — so Mixed mode still
  returns `don’t` with its curl intact. Pasted text is the reason this lives in Core rather than
  only in the shell: other apps curl quotes whatever Kibo does.
- The shell also registers the two substitution defaults off, so the input field stops rewriting
  text at the point of entry.
- `RunSplitter` counts the substitutes as Latin; left neutral, `’` cut `don’t` into three runs and
  the gate never saw a word to judge.

### Changed

- The fixture gains a `typographicSubstitutes` table and is at `version` 3.

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
