// astra-probe: prints every media-key (HID consumer page) value with the device that sent it,
// so you can confirm what the Astra's knob sends over the cable and over Bluetooth.
//
//   swift run astra-probe            media keys plus volume, F-keys and navigation keys (no typing)
//   swift run astra-probe --list     list matching devices and exit
//   swift run astra-probe --vendor   also print vendor-specific pages (some mice flood these)
//   swift run astra-probe --all      also print every keyboard key (this logs your typing)
//   swift run astra-probe --ddc      read each external display's brightness over DDC/CI and exit
//
// The terminal running it needs Input Monitoring (System Settings › Privacy & Security).

import AstraCore
import Foundation
import IOKit.hid

let args = Set(CommandLine.arguments.dropFirst())
if args.contains("-h") || args.contains("--help") {
    print("usage: astra-probe [--list] [--vendor] [--all] [--ddc]")
    exit(0)
}

if args.contains("--ddc") {
    let displays = DDCDisplay.all()
    print("External displays with an AV service: \(displays.count)")
    for display in displays {
        if let reply = display.read(DDCPacket.brightness) {
            print("  \(display.name): brightness \(reply.current) of \(reply.maximum)")
        } else {
            let raw = display.readRaw(DDCPacket.brightness)
            let hex = raw.bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
            print("  \(display.name): no DDC reply (write 0x\(String(UInt32(bitPattern: raw.write), radix: 16)), read 0x\(String(UInt32(bitPattern: raw.read), radix: 16)), bytes \(hex))")
        }
    }
    exit(0)
}
let includeKeyboardPage = args.contains("--all")
let listOnly = args.contains("--list")
let includeVendorPages = args.contains("--vendor")

setvbuf(stdout, nil, _IOLBF, 0)

let monitor = HIDMonitor()
let result = monitor.start()
guard result == kIOReturnSuccess else {
    InputMonitoringAccess.request()
    fputs("""
    Could not open HID devices (IOReturn 0x\(String(UInt32(bitPattern: result), radix: 16))).
    Grant Input Monitoring to your terminal app in
      System Settings › Privacy & Security › Input Monitoring
    then quit and reopen the terminal and run this again.

    """, stderr)
    exit(1)
}

func printDevices() {
    print("Keyboards and media-key devices:")
    for device in monitor.devices {
        let transport = device.transport.isEmpty ? "?" : device.transport
        print("  \(device.id)  \(device.productName)  [\(transport)]  primary usage \(String(format: "0x%02X:0x%02X", device.primaryUsagePage, device.primaryUsage))")
    }
}

// The device list is only populated once the run loop has spun.
DispatchQueue.main.async {
    printDevices()
    if listOnly { exit(0) }
    print("\nTurn the knob both ways, press it, then hold it. Ctrl-C prints a summary.\n")
}

struct Seen: Hashable {
    let device: DeviceID
    let name: String
    let transport: String
    let page: UInt32
    let usage: UInt32
}

/// Media keys and non-typing keyboard keys (volume, F-keys, navigation).
/// Vendor pages need --vendor; letters, digits and modifiers need --all.
func isShown(_ event: HIDEvent) -> Bool {
    switch event.usagePage {
    case HIDUsage.consumerPage: return true
    case HIDUsage.keyboardPage: return includeKeyboardPage || HIDUsage.isNonTypingKey(event.usage)
    case 0xFF, 0xFF00...0xFFFF: return includeVendorPages
    default: return false
    }
}

var counts: [Seen: (down: Int, up: Int)] = [:]
var lastDown: [Seen: UInt64] = [:]
var timebase = mach_timebase_info_data_t()
mach_timebase_info(&timebase)
func millis(_ ticks: UInt64) -> Double { Double(ticks) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000 }

// IOKit reports every existing device as "added" while the manager opens; only announce later changes.
var enumerated = false
DispatchQueue.main.async { enumerated = true }
monitor.onDevicesChanged = {
    if enumerated { print("· device connected or disconnected") }
}

monitor.onEvent = { event in
    guard isShown(event) else { return }

    var line = String(format: "%@  %@ [%@]  page 0x%02X usage 0x%02X  %-15@ %@",
                      event.device.description, event.productName, event.transport,
                      event.usagePage, event.usage, event.usageName, event.value != 0 ? "down" : "up")

    if event.usagePage != HIDUsage.keyboardPage || HIDUsage.isNonTypingKey(event.usage) {
        let key = Seen(device: event.device, name: event.productName, transport: event.transport,
                       page: event.usagePage, usage: event.usage)
        var count = counts[key] ?? (0, 0)
        if event.value != 0 {
            count.down += 1
            lastDown[key] = event.timestamp
        } else {
            count.up += 1
            if let start = lastDown[key] { line += String(format: "  (held %.0f ms)", millis(event.timestamp &- start)) }
        }
        counts[key] = count
        if KnobDecoder.isPairingCandidate(event) { line += "  ← knob turn" }
    }
    print(line)
}

let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
signal(SIGINT, SIG_IGN)
sigint.setEventHandler {
    print("\n\nSummary (paste into docs/phase0-findings.md):\n")
    if counts.isEmpty {
        print("  No knob, media-key or vendor-page events seen.")
    } else {
        print("| Device | VID:PID | Transport | Usage | Downs | Ups |")
        print("|---|---|---|---|---|---|")
        for (seen, count) in counts.sorted(by: { ($0.key.device.description, $0.key.page, $0.key.usage) < ($1.key.device.description, $1.key.page, $1.key.usage) }) {
            print("| \(seen.name) | \(seen.device) | \(seen.transport) | \(String(format: "0x%02X:0x%02X", seen.page, seen.usage)) \(HIDUsage.name(page: seen.page, usage: seen.usage)) | \(count.down) | \(count.up) |")
        }
    }
    exit(0)
}
sigint.resume()

RunLoop.main.run()
