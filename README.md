# Astra Dial

A macOS menu bar app that turns the volume knob on the Cosmic Byte CB-GK-33 Astra keyboard
into a mode wheel, in the spirit of [Dial](https://github.com/athulrajt/dial) and
[Orbit](https://github.com/harsha20599/orbit) for the CMF Buds Pro 2.

The knob sends standard HID media keys (Volume Up/Down per detent, Mute on press). Astra Dial
reads them with IOHIDManager, only from the keyboard you pair, so other keyboards' volume keys
are unaffected.

**Status:** milestone 1–2. The probe tool and menu bar shell work: permissions, pairing by turning
the knob, and a live readout of turns and presses. Modes, the wheel and volume suppression are next.
Until then the knob keeps controlling volume as normal.

Requires macOS 14+ and Swift 6 (Xcode 16 or later).

## Probe the knob

```sh
make probe-list   # list keyboards / media-key devices with VID:PID
make probe        # print every media-key event; Ctrl-C prints a summary
```

Your terminal needs **Input Monitoring** (System Settings › Privacy & Security). Run it once over
the cable and once over Bluetooth and record the results in `docs/phase0-findings.md`.

## Run the app

```sh
make run          # builds build/Astra Dial.app and opens it
```

Grant Input Monitoring when asked, then turn the knob to pair the keyboard. Accessibility isn't
used yet but will be needed for modes. `swift run AstraDial` also works for quick iteration, but
launch at login only works from the bundled app.

Run `Scripts/create-signing-cert.sh` once first. It creates a self-signed "Astra Dial Local Signing"
certificate that `bundle.sh` picks up, so every build has the same identity and macOS keeps
Input Monitoring and Accessibility across rebuilds. Without it, builds are signed ad-hoc and macOS
asks again after each one. `SIGN_IDENTITY` overrides the choice (for example a Developer ID).

## Layout

```
Sources/AstraCore/    HIDMonitor (IOHIDManager), HIDEvent, KnobDecoder
Sources/AstraDial/    SwiftUI MenuBarExtra app
Tools/astra-probe/    command-line probe
Tests/AstraCoreTests/ decoder tests
Scripts/bundle.sh     builds and signs the .app
```
