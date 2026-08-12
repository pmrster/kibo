# Security

## Reporting a vulnerability

Report privately, not as a public issue: use GitHub's
[private vulnerability reporting](https://github.com/pmrster/kibo/security/advisories/new) on this
repository.

Please include what you did, what happened, and the macOS version you saw it on. A proof of
concept helps. Expect an acknowledgement within a week — this is a personal project, not a funded
one, so that is a realistic promise rather than a generous-sounding one.

## What counts as a vulnerability here

Kibo is an offline text converter. It has no server, no account, and no network code, so the
interesting failures are all about **text escaping the process**. Anything in this list is a real
bug and worth reporting:

- Input or converted text reaching disk, a log, a crash report, or any file.
- The clipboard being read at any moment other than a Paste, or written other than by a Copy.
- The app opening a network connection at all.
- A Copy landing on the pasteboard without the concealed/transient markers.
- Anything that lets another process on the machine read the text Kibo is holding.
- A crafted input that crashes or hangs the app — a crash log can carry state with it.

Out of scope, and already documented in [`PRIVACY.md`](PRIVACY.md): the macOS text context menu's
Look Up and Translate items, and Universal Clipboard syncing the general pasteboard. Both are
system features that act on the user's own choice, and no app can suppress them.

## Verifying a release

Every DMG ships with a `.sha256` beside it. Note what that does and does not tell you: it is
generated on the same machine that built the DMG, so it detects a corrupted download, not a
tampered release.

Builds are currently **ad-hoc signed and not notarized** — there is no paid Developer ID behind
this project yet. That means macOS cannot attribute a downloaded build to anyone, and Gatekeeper
will make you right-click → Open the first time. If that trade is not one you want to make, build
from source; `Packaging/package.sh` produces the same app from the code in this repository.

## Hardening already in place

- App Sandbox, with **no** network entitlement — see `Packaging/Kibo.entitlements`.
- Hardened runtime on signed builds.
- No third-party dependencies at all, so there is no supply chain to compromise: `Package.swift`
  declares zero packages.
- Window state restoration disabled, so text is never written to saved application state.
- `Packaging/package.sh` refuses to produce a build whose signature lacks the sandbox.
