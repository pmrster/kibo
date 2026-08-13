# Product Specification: Kibo

_“Who Forgot To Change Lang” · ใครลืมเปลี่ยนภาษา_

## Overview

A macOS-first desktop utility for Thai users who occasionally type with the wrong keyboard layout active. It lives in the menu bar, converts mistyped text between Thai and English instantly, and works without a network connection.

A WidgetKit widget may be added as a companion for glanceable state and shortcuts. It is not the primary converter because system widgets do not support the free-form text-entry workflow this product needs. A Windows tray utility is planned after the macOS version is stable.

## Problem

- Users often forget to switch between the Thai Kedmanee layout and the US QWERTY layout.
- Typing the same text again is annoying, especially while working on a laptop.
- Existing tools usually require picking one direction; mixed Thai/English sentences need manual handling.
- A converter should be reachable without finding a browser tab or interrupting the current task.

## Solution

A simple converter that accepts text typed on the wrong keyboard and returns the corrected version. Four modes cover all common cases:

1. **Mixed** — separates the text into Thai, Latin, and neutral runs and converts a run **only when that run is malformed in its own script**. Already-correct words, numbers, and punctuation are left exactly as typed. The judgement is deterministic and dictionary-free, based on Thai and English spelling structure; see *Mixed-mode judgement* below for what it can and cannot detect.
2. **EN → TH** — converts English-keyboard keystrokes into Thai characters. Mechanical: converts everything mappable, without judgement.
3. **TH → EN** — converts Thai-keyboard keystrokes into English characters. Also mechanical.
4. **Both** — flips *every* run in the direction its current script implies: Thai runs to English, Latin runs to Thai, in one pass. Mechanical, like the two explicit directions, but per run rather than whole-string.

The three mechanical modes exist as the escape hatch for when Mixed's judgement is wrong. **Both** covers the case neither explicit direction can: text mistyped in *both* directions at once, which happens when the layout is switched partway through a sentence.

## Target user

Thai speakers who type in both Thai and English on macOS. Windows users are the next target after the macOS release.

## User stories

- As a user, I want to paste text I typed on the wrong keyboard and get the correct version back so I do not have to retype it.
- As a user, I want to open the converter from the menu bar so it is available from any app.
- As a user, I want mixed Thai/English runs to be flipped in one operation so I do not have to process each run manually.
- As a user, I want to copy the result with one click so I can paste it where I need it.
- As a user, I want the utility to feel native and stay out of the Dock while I am not using it.
- As a user, I want light and dark modes so it matches my system preference.

## Modes and behavior

| Mode | Input example | Output example | Notes |
| --- | --- | --- | --- |
| Mixed | `l;ylfu ไำะ ครับ 2024 :)` | `สวัสดี wet ครับ 2024 :)` | Only the malformed runs convert. `ครับ` is correct Thai, `2024` is a number, `:)` has no letters — all three are left alone. |
| EN → TH | `vpkddbodkca` | `อยากกินกาแฟ` | Whole string treated as English keystrokes. |
| TH → EN | `ะ้ฟืา` | `thank` | Whole string treated as Thai keystrokes. |
| Both | `vtwiot เพฟิ` | `อะไรนะ grab` | Each run flipped by its own script. Converts correct text too — the user is supplying the judgement. |

### Mixed-mode judgement

A run is converted only if it breaks the spelling rules of the script it is currently written in.

- **Thai** — a vowel or tone mark must have a consonant before it; a leading vowel (`เ แ โ ใ ไ`) must have a consonant after it; the same mark never repeats *immediately*. Typing English on the Thai layout breaks these almost immediately, because vowel marks land wherever the English letters happen to sit.
- **Latin** — a run with fewer than three letters is never judged, which is what protects numbers, punctuation, and short acronyms. Otherwise a `;` between two letters, or a pile-up of six or more consonants, marks it as wreckage; a total absence of vowels does too, but only in words of six letters or more. All-capital words are treated as acronyms and never converted.
- **Letter-poor runs** — Thai consonants sit on digit and punctuation keys, so a mistyped Thai word can arrive with almost no letters (`ขอบคุณ` becomes `-v[86I`). For these, the converter instead asks whether the run turns into well-formed Thai containing a vowel mark. It needs at least four characters to try.

**Limits — precision first.** The core trade is stated plainly: **mangling correct text is a worse failure than leaving a mistyping**, because the user can see and fix the latter by switching to an explicit mode. The rules above are therefore tuned for precision, and both sides of that trade are measured:

| | Result |
| --- | --- |
| **Precision** — correct text left untouched | 36 of 36 sampled (acronyms, URLs, paths, code, English, numbers, Thai) |
| **Recall** — English mistypings fixed | 19 of 30 sampled |
| **Recall** — Thai mistypings fixed | 4 of 12 sampled |

The judgement is structural, not semantic, so wreckage that happens to be well-formed passes through unchanged: `แนกำ` (which was `code`) breaks no Thai rule, and `นา` (which was `ok`) is a real Thai word. All three figures are pinned by `MeasuredAccuracyTests`, counts included, so a change that trades one for the other is visible rather than silent — and mirrored into `Fixtures/conversion-cases.json` so a port inherits the same promise.

A dictionary-backed judgement was considered and rejected for the MVP — written Thai has no spaces, so it would require word segmentation before any lookup.

## Features

- **Menu-bar access**: An `NSStatusItem` opens a compact converter window on left-click, and an About / Settings / Quit menu on right-click. (`MenuBarExtra` was the original plan; it offers no right-click hook, and a menu-bar-only app has no menu bar of its own to put those commands in.)
- **Pinnable window**: The converter can float above other apps, so it stays open while the user switches away to paste.
- **Four conversion modes**: Mixed, EN → TH, TH → EN, Both.
- **Live conversion**: Output updates locally on every input change.
- **One-click copy**: A prominent copy button with “Copied” feedback, retracted as soon as the result changes.
- **Explicit paste**: A paste button reads the clipboard only after the user asks it to.
- **Swap direction**: Quick toggle between EN → TH and TH → EN. Disabled for Mixed and Both, which are direction-symmetric.
- **Clear input**: Reset the input field.
- **System appearance**: Follow macOS light/dark appearance by default.
- **Privacy-first**: All conversion happens on-device; no server calls or analytics.
- **Optional global shortcut**: Open or focus the converter without reaching for the mouse. This follows the core MVP.
- **Optional launch at login**: User-controlled and disabled by default.

## Design

- **Fonts**: **Prefer system fonts, and bundle none** — a face the app cannot guarantee is a face it should not depend on, since the shipped build would silently fall back and look nothing like the approved design. Space Grotesk was tried and dropped for exactly that reason: it looked right, but it was installed on one machine only. The app's name uses the system font at semibold, the same face as the section labels; heavy read as shouty and dated. Other English chrome uses the plain system font so the app looks native. Thai content — the input and the result — uses **Noto Sans Thai**, which macOS ships: the system's Thai face crowds vowel and tone marks at these sizes, and reading those marks is precisely what this app asks of people. Where the family is unavailable, every call falls back to the system font.
- **Colors**: Warm neutrals — shared with Tama, so the two read as siblings — under a **near-monochrome accent** that matches the mascot: midnight on the light panel, pale on the dark one. Green survives as the one colour, on the copy confirmation and the privacy badge, because both are claims about safety and a monochrome tick reads as decoration. The accent was mango, and the orange fought everything around it once the mascot went midnight-and-pale.
- **Branding**: The app presents as **“Kibo”** — after its mascot — in the converter, the About and Settings windows, the menu, and distribution metadata. “Who Forgot To Change Lang” is the subtitle, shown under the name in About: the short name is what you call it, the long one is what it does. “ใครลืมเปลี่ยนภาษา” is the project's Thai name. The entire interface is English; Thai appears only in the text being converted. “ใครลืมเปลี่ยนภาษา” stays the project's Thai name in prose.
- **Mascot**: **Kibo**, an original 8-bit ghost — the wrong layout haunting your sentence. It says “boo~”, as Tama's cat says “meow~”: on the converter that appears only after a copy, so it stays a small reward rather than constant chatter beside a text field. It perches on the top edge of the input field with its tails tucked behind, blinks while it waits, and shuts its eyes contentedly after a copy. It appears in the converter, About, and Settings. Small vertical eyes and no mouth: at this size a mouth is either a slab or a nose, and two holes carry the whole expression.
- **Mascot colours**: One colour, with the eyes cut out of it as holes — the same construction Tama uses. Midnight on the light panel, pale on the dark one, so it is always the opposite of what it sits on. No outline and no second accent: an earlier version had both plus a yellow mouth and read as cluttered, three tones fighting inside sixteen pixels.
- **Menu-bar glyph**: Kibo's silhouette, with the eyes kept as holes. The glyph's job is to identify the app, which an earlier cat silhouette could not do — beside Tama in a real menu bar, two side-view pixel cats are indistinguishable at 18px. A ghost beside a cat has no such problem, so the mascot can serve as the glyph. (A `ก` keycap outline was used in between, while the mascot was still a cat.)
- **Visual style**: A compact, native macOS surface — rounded sections, clear focus states, clean spacing, and as few elements as the job needs. The converter is deliberately short: input, result, four actions.

## Keyboard mapping

The app uses the Thai Kedmanee layout mapped to the US QWERTY layout. Every supported unshifted and shifted physical key is mapped character by character in the platform-independent converter module. Unmapped characters, whitespace, line breaks, emoji, and symbols are preserved.

## Non-functional requirements

- No backend is required for the core feature.
- No user data is stored or transmitted.
- The app must work fully offline.
- Should be fast enough to update output on every keystroke.
- The converter must be deterministic and independently unit-testable.
- The macOS MVP targets macOS 14 or newer; this can be lowered before implementation if broader compatibility is required.
- The app should be usable with keyboard navigation, VoiceOver labels, and adequate contrast.

## Distribution

- The project is a SwiftPM package with no Xcode project. Development builds run with `swift run`; `Packaging/package.sh` assembles the `.app` and DMG.
- The first distributable build is a signed and notarized macOS app outside the Mac App Store. Until a Developer ID is provisioned, builds are ad-hoc signed and require right-click → Open on first launch.
- Mac App Store distribution is a later decision, not an MVP requirement.

## Future considerations

- Add a keyboard visualizer showing the mapping.
- Support other Thai layouts (Pattachote).
- Add opt-in, local-only recent conversion history.
- Add a WidgetKit companion that displays the last result and offers supported shortcut actions.
- Add a Windows notification-area utility using the same behavior contract and test fixtures.
- Explore selection replacement through macOS Accessibility only as an explicit opt-in feature; it is not required for the privacy-minimal MVP.
