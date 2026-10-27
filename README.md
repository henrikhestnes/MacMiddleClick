# MacMiddleClick

Middle clicks on a Mac trackpad, from the menu bar. Swift and AppKit, with no dependencies. Requires macOS 14 or newer.

**Tap** the trackpad with three fingers, or **press** it with three fingers, to middle-click at the pointer. Use it to open links in a new tab, close tabs, paste the selection in a terminal, or pan in CAD and 3D apps. A pressed middle click can also be dragged.

## Install

```sh
brew install --cask henrikhestnes/tap/macmiddleclick
```

Update with `brew update` and `brew upgrade --cask macmiddleclick`. You can also download `MacMiddleClick.zip` from the [latest release](https://github.com/henrikhestnes/MacMiddleClick/releases/latest) and move **MacMiddleClick.app** to **Applications**. The release is signed with a self-signed certificate and not notarized by Apple, so macOS may block it through Gatekeeper.

To build from source instead:

```sh
./scripts/build.sh
cp -R dist/MacMiddleClick.app /Applications/
open /Applications/MacMiddleClick.app
```

`./scripts/build.sh --universal` builds for both Apple silicon and Intel.

MacMiddleClick turns on **Launch at Login** the first time it runs. Turn it off from the menu bar icon; MacMiddleClick won't turn it back on.

On first launch, macOS asks for **Accessibility** access, which MacMiddleClick needs to turn clicks into middle clicks. Enable it in **System Settings → Privacy & Security → Accessibility**. MacMiddleClick picks the permission up within two seconds, without a relaunch.

Releases are signed with the same self-signed "MacSnip Release" certificate as MacSnip, so the permission carries over to upgrades. Builds from source are ad-hoc signed unless that certificate is in your keychain, and macOS treats every ad-hoc rebuild as a new app and silently stops honoring the permission. After rebuilding, remove MacMiddleClick from that list (−), add it again, and relaunch. To avoid this, sign with a stable certificate: `SIGN_IDENTITY="Apple Development: …" ./scripts/build.sh`.

## Menu

| Item | Effect |
| --- | --- |
| **Enabled** | Pause or resume all middle clicks |
| **Three-Finger Tap** | A quick tap with three fingers middle-clicks |
| **Three-Finger Click** | Pressing the trackpad with three fingers middle-clicks |
| **Fingers** | Use three or four fingers |
| **Launch at Login** | Start with your Mac |

A tap counts when exactly that many fingers touch, they don't move, and they all lift within 0.3 seconds. Resting a fourth finger or thumb on the trackpad cancels it.

## Conflicts with macOS gestures

Three-finger gestures in macOS can overlap with these:

- **Three-finger drag** (Accessibility → Pointer Control → Trackpad Options) turns a three-finger touch into a drag. Turn it off, or set MacMiddleClick to four fingers.
- **Look up & data detectors** set to *Tap with three fingers* (System Settings → Trackpad) fires along with the middle click. Set it to *Force Click with one finger*.
- Three-finger swipes for Mission Control and switching spaces don't conflict, because moving fingers never count as a tap.

## How it works

MacMiddleClick reads raw finger contacts from the private `MultitouchSupport.framework`, loaded at runtime with `dlopen`. It works with built-in trackpads and Magic Trackpads, and picks up trackpads that connect later or after sleep.

- **Tap**: `TapRecognizer` (in `MacMiddleClickCore`, unit tested) watches the contact frames and posts a middle click when it sees a tap.
- **Click**: a Quartz event tap rewrites left mouse down, drag, and up events into middle-button events while three fingers are on the trackpad.

Because the framework is private, a future macOS update could break it. The menu then shows *Trackpad access is unavailable on this macOS*.

## Development

```sh
swift build
swift test
```
