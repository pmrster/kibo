# Privacy

Kibo fixes text you typed with the wrong keyboard layout. In practice that means people paste
passwords into it — a password typed with the Thai layout on is exactly the kind of thing this app
exists to rescue. Everything below follows from taking that seriously.

No account, no telemetry, no analytics, no crash reporting, no update check.

## What the app does with your text

| | |
| --- | --- |
| **Sent over the network** | Nothing. The app has no network code and no network entitlement. |
| **Written to disk** | Nothing. Not the input, not the result, not a history. |
| **Kept in memory** | The current input and result, for as long as the window is open. |
| **Put on the clipboard** | Only the result, only when you press Copy. |
| **Seen from other apps** | Only the text you select and then hand over via Services → Fix Layout with Kibo. It arrives on a private pasteboard, not the clipboard. |

The only things Kibo stores anywhere are three display preferences: appearance, text size, and the
last conversion mode you used. They live in `~/Library/Containers/pmrster.kibo/Data/Library/
Preferences/`. There is nowhere in that store to put text, which is the point.

## How each claim is enforced

**No network.** The app is signed with `com.apple.security.app-sandbox` and *no* network
entitlement (see `Packaging/Kibo.entitlements`). This is stronger than a promise not to connect:
the kernel refuses the connection, so a future change that tried to phone home would simply fail.
`Packaging/package.sh` refuses to build if the entitlements file is missing, and verifies after
signing that the sandbox actually made it into the signature.

**The clipboard is touched twice, by hand.** `Clipboard` is a two-method protocol — read, write —
with no "watch" or "poll" operation to start using by accident. `ConverterModel` calls read only
from Paste and write only from Copy. `ConverterModelTests` counts every access and fails the build
if anything else reaches for it.

**The Services item is not a third touch.** When you pick *Fix Layout with Kibo* from another
app's right-click menu, macOS copies your selection onto a private, single-use pasteboard and
hands that to Kibo; the converted text goes back the same way. The general clipboard — the one
Universal Clipboard syncs and clipboard managers watch — is never involved, and the tests above
assert that the code path the Service uses does not reach for it. Nothing is read until you pick
the item: there is no selection watching, and no Accessibility permission is requested.

**Copies are marked as secrets.** A Copy writes the text with the `org.nspasteboard.ConcealedType`
and `org.nspasteboard.TransientType` markers, which clipboard managers (Raycast, Maccy, Paste,
Alfred) honour by refusing to record the item.

**No window restoration.** macOS can save a window's text contents to
`~/Library/Saved Application State/` so it can redraw the window after a relaunch. Kibo turns that
off for every panel, so your text cannot reach disk through it.

## Verify it yourself

```bash
# 1. No network sockets. No output = no connections.
#    The -a matters: without it, lsof ORs the filters and shows you every other app's traffic.
lsof -a -p $(pgrep -x Kibo) -i

# 2. The sandbox is real, and network entitlements are absent.
codesign -d --entitlements - /Applications/Kibo.app

# 3. Everything the app has stored.
defaults read pmrster.kibo
```

The source is here in full, and the build is reproducible from it with `Packaging/package.sh`.

## What Kibo cannot control

**The macOS text context menu.** Right-clicking in the input or result field gives you the system
menu, which includes **Look Up** and **Translate**. Those are Apple features, and they send the
selected text to Apple's servers when you choose them. Kibo does not invoke them and cannot see
what they do. If the text is sensitive, don't pick those items.

**Universal Clipboard.** If Handoff is on, macOS may sync the general clipboard to your other
Apple devices — that applies to anything you copy, in any app. Kibo marks its copies concealed and
transient, which is the strongest signal an app can send about clipboard contents, but the
transfer itself belongs to the system. Turn off Handoff in System Settings → General → AirDrop &
Handoff if you would rather it never happened.

**Whatever you paste it into.** Once the corrected text is on your clipboard, it is subject to
whatever the destination app does with it.

## Contact

Report a privacy or security concern via [`SECURITY.md`](SECURITY.md).
