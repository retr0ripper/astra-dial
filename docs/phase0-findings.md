# Phase 0: Astra knob findings

Recorded with `make probe` on macOS 27.0.1, 2026-10-22.

## Bluetooth

The keyboard reports as **CB Astra, VID:PID 05AC:024F**. That is Apple's vendor ID and the old
Apple Aluminum keyboard product ID, so macOS treats it as an Apple keyboard. It appears as **two**
HID devices with the same VID:PID and primary usage 0x01:0x06 (keyboard).

| Action | Page:Usage | Name | Notes |
|---|---|---|---|
| Turn clockwise | 0x0C:0xE9 | Volume Up | One down/up pair per detent, held 1–24 ms |
| Turn counter-clockwise | 0x0C:0xEA | Volume Down | Same |
| Press | 0x0C:0xE2 | Mute | Separate down and up; a tap held 135–157 ms |
| F5 (control) | 0x07:0x3E | F5 | Normal keys arrive on the keyboard page |

**Every event arrives twice**, once from each of the two HID devices, with the same timestamp.
`EventDeduplicator` drops the second copy (same device, usage and value within 1 ms). Verified on
hardware: after the fix each event appears once.

**Long press:** Mute stays down for the whole hold (recorded 2452 ms and 5558 ms) and does not
auto-repeat, so long-press is reliable.

**Hold + turn:** not available. No turn events arrived while the knob was held. Turns made during
the hold only came through after release. The gesture set is turn, press, double-press, long-press.

## Wired (USB)

Not recorded yet.

## Questions

- [x] One Volume Up/Down down+up pair per detent? Yes.
- [x] Press usage: Mute (0xE2).
- [x] Does a press report a separate key-up? Yes, for a tap.
- [x] Does a long hold stay down until release? Yes. Long-press works.
- [x] Does holding the press auto-repeat? No.
- [x] Hold + turn? No turn events while pressed. Dropped.
- [ ] VID:PID over the cable.
- [ ] Risk: a real Apple Aluminum keyboard also uses 05AC:024F. Pairing may need the product name too.
