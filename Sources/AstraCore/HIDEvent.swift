import Foundation

/// A USB/Bluetooth HID device identity. The Astra may report a different
/// product ID over the cable than over Bluetooth, so each is stored separately.
public struct DeviceID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let vendorID: Int
    public let productID: Int

    public init(vendorID: Int, productID: Int) {
        self.vendorID = vendorID
        self.productID = productID
    }

    public var description: String { String(format: "%04X:%04X", vendorID, productID) }
}

/// One HID input value, flattened out of IOKit so the rest of the app never touches CF types.
public struct HIDEvent: Sendable {
    public let device: DeviceID
    public let productName: String
    public let transport: String
    public let usagePage: UInt32
    public let usage: UInt32
    public let value: Int
    /// Mach absolute time from the HID report.
    public let timestamp: UInt64

    public init(device: DeviceID, productName: String, transport: String,
                usagePage: UInt32, usage: UInt32, value: Int, timestamp: UInt64) {
        self.device = device
        self.productName = productName
        self.transport = transport
        self.usagePage = usagePage
        self.usage = usage
        self.value = value
        self.timestamp = timestamp
    }

    public var usageName: String { HIDUsage.name(page: usagePage, usage: usage) }
}

public enum HIDUsage {
    public static let keyboardPage: UInt32 = 0x07
    public static let consumerPage: UInt32 = 0x0C

    // Consumer page (HID Usage Tables §15)
    public static let playPause: UInt32 = 0xCD
    public static let scanNext: UInt32 = 0xB5
    public static let scanPrevious: UInt32 = 0xB6
    public static let stop: UInt32 = 0xB7
    public static let mute: UInt32 = 0xE2
    public static let volumeIncrement: UInt32 = 0xE9
    public static let volumeDecrement: UInt32 = 0xEA
    public static let brightnessIncrement: UInt32 = 0x6F
    public static let brightnessDecrement: UInt32 = 0x70

    // Keyboard page volume keys, used by boards that present themselves as Apple keyboards
    public static let keyboardMute: UInt32 = 0x7F
    public static let keyboardVolumeUp: UInt32 = 0x80
    public static let keyboardVolumeDown: UInt32 = 0x81

    /// Keyboard-page usages that aren't typing: F-keys, navigation, media and the like.
    /// Letters, digits, punctuation and modifiers are excluded so the probe never logs typing.
    public static func isNonTypingKey(_ usage: UInt32) -> Bool {
        (0x3A...0x45).contains(usage) || (0x46...0x52).contains(usage) || (0x68...0x81).contains(usage)
    }

    private static let consumerNames: [UInt32: String] = [
        playPause: "Play/Pause",
        scanNext: "Next Track",
        scanPrevious: "Previous Track",
        stop: "Stop",
        mute: "Mute",
        volumeIncrement: "Volume Up",
        volumeDecrement: "Volume Down",
        brightnessIncrement: "Brightness Up",
        brightnessDecrement: "Brightness Down",
    ]

    public static func name(page: UInt32, usage: UInt32) -> String {
        switch page {
        case consumerPage: return consumerNames[usage] ?? String(format: "Consumer 0x%02X", usage)
        case keyboardPage:
            switch usage {
            case keyboardMute: return "Key Mute"
            case keyboardVolumeUp: return "Key Volume Up"
            case keyboardVolumeDown: return "Key Volume Down"
            case 0x3A...0x45: return "F\(usage - 0x39)"
            case 0x68...0x73: return "F\(usage - 0x68 + 13)"
            default: return String(format: "Key 0x%02X", usage)
            }
        default: return String(format: "Page 0x%02X Usage 0x%02X", page, usage)
        }
    }
}
