# Astra Dial

A macOS menu bar app that turns the volume knob on the Cosmic Byte CB-GK-33 Astra keyboard
into a mode wheel, in the spirit of [Dial](https://github.com/athulrajt/dial) and
[Orbit](https://github.com/harsha20599/orbit) for the CMF Buds Pro 2.

The knob sends standard HID media keys (Volume Up/Down per detent, Mute on press). Astra Dial
reads them with IOHIDManager, only from the keyboard you pair, so other keyboards' volume keys
are unaffected.

Double-press the knob to open the mode wheel, turn to pick a mode, press to switch. Modes:
Volume, Brightness (external displays over DDC/CI), Scroll, Zoom, Apps (⌘Tab), Tabs, Desktops,
Undo, Scrub, Slides and Custom (your own shortcuts for turn and press). Long-press returns to
Volume. Settings reorders and hides modes, sets a press action per mode, records Custom's
shortcuts, tunes speeds and timings, and assigns modes to apps so they switch automatically.

## Install

```sh
brew install --cask retr0ripper/tap/astra-dial
```

Or download the DMG from [Releases](https://github.com/retr0ripper/astra-dial/releases). Builds
are signed with a Developer ID and notarized. Requires macOS 14 or later.

On first launch, grant **Input Monitoring** (to read the knob) and **Accessibility** (to take the
knob from macOS and send shortcuts and scrolls), then turn the knob to pair the keyboard. Astra Dial
checks GitHub once a day and shows newer releases in its menu; update with
`brew upgrade astra-dial`. Turn the check off in Settings.

## Build

Requires Swift 6 (Xcode 16 or later).

### Probe the knob

```sh
make probe-list   # list keyboards / media-key devices with VID:PID
make probe        # print every media-key event; Ctrl-C prints a summary
```

Your terminal needs **Input Monitoring** (System Settings › Privacy & Security). Run it once over
the cable and once over Bluetooth and record the results in `docs/phase0-findings.md`.

### Run the app

```sh
make run          # builds build/Astra Dial.app and opens it
```

Grant Input Monitoring and Accessibility when asked, then turn the knob to pair the keyboard.
`swift run AstraDial` also works for quick iteration, but launch at login and update checks only
work from the bundled app.

Run `Scripts/create-signing-cert.sh` once first. It creates a self-signed "Astra Dial Local Signing"
certificate that `bundle.sh` picks up, so every build has the same identity and macOS keeps
Input Monitoring and Accessibility across rebuilds. Without it, builds are signed ad-hoc and macOS
asks again after each one. `SIGN_IDENTITY` overrides the choice (for example a Developer ID).

### Test

```sh
make test         # AstraCore unit tests; CI runs these on every push and pull request
```

### Release

```sh
make release      # universal app, DMG and Homebrew cask in build/release/
```

The version comes from `VERSION`, and the build number from the commit count. With a
**Developer ID Application** certificate in the keychain, `release.sh` signs with it and, when
`NOTARY_PROFILE` is set, notarizes and staples the DMG:

```sh
xcrun notarytool store-credentials astra-dial --apple-id <apple id> --team-id <team id>
NOTARY_PROFILE=astra-dial GITHUB_REPO=<owner>/astra-dial make release
```

Without one, it signs with the local certificate. Gatekeeper then blocks the first open on other
Macs until the user right-clicks → Open or runs
`xattr -dr com.apple.quarantine "/Applications/Astra Dial.app"`.

`build/release/astra-dial.rb` is a Homebrew cask pointing at the GitHub release asset; copy it to
`Casks/` in [retr0ripper/homebrew-tap](https://github.com/retr0ripper/homebrew-tap). Bump
`VERSION` before each release so the in-app update check sees it. `make icon` re-renders `Resources/AppIcon.icns` from `Scripts/make-icon.swift`.

## Layout

```
Sources/AstraCore/    HID input, knob decoding and gestures, DDC, and other app-free logic
Sources/AstraDial/    SwiftUI MenuBarExtra app: engine, modes, HUD, Settings, update check
Tools/astra-probe/    command-line probe
Tests/AstraCoreTests/ AstraCore unit tests
Scripts/bundle.sh     builds and signs the .app
Scripts/release.sh    universal build, DMG, notarization, cask
packaging/            Homebrew cask template
.github/workflows/    CI: build and test
```
