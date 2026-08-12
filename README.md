# ใครลืมเปลี่ยนภาษา

A macOS menu-bar utility that fixes text typed with the wrong keyboard layout — Thai Kedmanee
against US QWERTY, in either direction.

Type `l;ylfu` when you meant `สวัสดี`? Paste it in and get it back.

```
l;ylfu ไำะ ครับ 2024 :)   →   สวัสดี wet ครับ 2024 :)
```

Note what *didn't* change. `ครับ` was already correct, `2024` is a number, `:)` is a smiley. Mixed
mode converts only the parts that are actually broken.

| | |
| --- | --- |
| **Status** | Slice 1 — the converter and the menu-bar app work; unsigned builds only |
| **Stack** | Swift 6, SwiftUI, AppKit, SwiftPM, XCTest, macOS 14+ |
| **Privacy** | Local-only. No network, no analytics, no stored text. |

## Install

No signed build is published yet. Build it yourself:

```bash
git clone <this repo> && cd who-forget-to-change-lang
Packaging/package.sh
open dist/
```

Drag the app to `/Applications`. Because it is ad-hoc signed rather than notarized, macOS will
refuse it on first launch — right-click the app → **Open** once, and it will not ask again.

## Using it

The app has no Dock icon. Look for the small pixel ghost in the menu bar — that's **Kibo**. Open
it and Kibo is there too, perched on the top edge of the input box. It blinks while it waits,
shuts its eyes after a copy, and says *boo~*.

- **Left-click** the glyph to open the converter.
- **Right-click** for About, Settings, and Quit.
- **Pin** (top-right of the window) floats the converter above other apps, so it stays put while
  you switch away to paste.

Three modes:

| Mode | What it does |
| --- | --- |
| **Mixed** | Converts only the runs that look wrong. Leaves correct text, numbers, and punctuation alone. |
| **EN → TH** | Treats the whole string as English keystrokes typed with the Thai layout on. |
| **TH → EN** | The reverse. |

The two explicit modes are mechanical — they flip everything, no judgement. They are the escape
hatch for when Mixed guesses wrong.

Everything happens as you type, and the whole flow works without a mouse:

| Action | Shortcut |
| --- | --- |
| Copy result | `⇧⌘C` |
| Paste | `⇧⌘V` |
| Clear | `⇧⌘K` |
| Swap direction | `⇧⌘S` |
| Pin as floating window | `⇧⌘P` |

## How Mixed decides

Thai spelling has hard structural rules, and typing English on the Thai layout breaks them almost
immediately — vowel marks land with no consonant to attach to:

```
"email" typed on the Thai layout  →  ำทฟรส
                                     ↑ a vowel mark with nothing to attach to → broken → converted

ครับ                                 ค(consonant) ร(consonant) ั(mark, attached) บ(consonant)
                                     → every rule satisfied → left alone
```

No dictionary is involved, which matters: written Thai has no spaces, so `สวัสดีครับ` arrives as a
single run and a dictionary would need to segment it first.

**Mixed is tuned to never break correct text, which means it misses things.** Wreckage that
happens to be well-formed passes through — `แนกำ` (which was "code") breaks no rule, and `นา`
(which was "ok") is a real Thai word.

| | |
| --- | --- |
| Correct text left untouched | 36 of 36 sampled — acronyms, URLs, paths, code, English, numbers, Thai |
| English mistypings fixed | 16 of 25 sampled |
| Thai mistypings fixed | 4 of 12 sampled |

That ordering is deliberate: leaving a mistyping is recoverable — you see it and switch to an
explicit mode — whereas mangling text you'd typed correctly is not. All three figures are pinned
in the test suite and written up in `CLAUDE.md`.

## Privacy

- **No network.** Not for updates, not for analytics. Check it yourself:
  `lsof -p $(pgrep -x WhoForgotToChangeLang) -i`
- **The clipboard is touched only when you ask.** Read on Paste, written on Copy, never watched or
  polled.
- **Nothing you type is stored.** Preferences hold your theme, text size, and last mode. That's it.

## Development

```bash
swift build
swift test
swift run WhoForgotToChangeLang

# Render the UI to PNGs without a display, for design review (light + dark):
swift run -Xswiftc -DWFCL_SNAPSHOT WhoForgotToChangeLang --snapshot ./assets
```

The key table is not hand-written — it is dumped from macOS's own layout data:

```bash
swift Tools/dump-kedmanee.swift
```

`Fixtures/conversion-cases.json` is a language-neutral behaviour contract: the full 94-key table
plus cases across all three modes. A future Windows port has to pass the same file.

See `CLAUDE.md` for architecture, `SPEC.md` for product behaviour, `PLAN.md` for sequencing.

## Related

A spin-off of [**Tama**](https://github.com/pmrster/tama), a menu-bar pixel cat that watches local
AI agent sessions. This app forks Tama's shell — the SwiftPM layout, theming, panel chrome and
packaging — and follows its approach to pixel-art character work, but Kibo is its own. Tama keeps
the cat and its "meow~"; Kibo gets the "boo~". Separate repos, separate releases.

## License

MIT.
