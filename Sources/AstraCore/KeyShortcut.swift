import Foundation

/// A keyboard shortcut recorded in Settings: a macOS virtual key code, modifiers, and the
/// key's label as typed, so the shortcut displays without a keyboard-layout lookup.
public struct KeyShortcut: Codable, Hashable, Sendable {
    public struct Modifiers: OptionSet, Codable, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let control = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)
    }

    public var keyCode: UInt16
    public var modifiers: Modifiers
    public var keyLabel: String

    public init(keyCode: UInt16, modifiers: Modifiers, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    /// "⌃⌥⇧⌘K", in the order macOS menus use.
    public var display: String {
        let symbols: [(Modifiers, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
        return symbols.filter { modifiers.contains($0.0) }.map(\.1).joined() + keyLabel.uppercased()
    }

    /// A label for a key: a name or symbol for keys that type nothing visible, otherwise
    /// the character typed (without modifiers), uppercased.
    public static func label(forKeyCode keyCode: UInt16, characters: String?) -> String {
        if let name = namedKeys[keyCode] { return name }
        // Control characters and AppKit's private-use function-key characters aren't printable.
        let printable = characters?.unicodeScalars.allSatisfy { $0.value >= 0x20 && !(0xF700...0xF8FF).contains($0.value) }
        if let characters, !characters.isEmpty, printable == true { return characters.uppercased() }
        return "Key \(keyCode)"
    }

    /// Whether a key can be the key of a shortcut: modifier keys on their own can't.
    public static func isRecordable(keyCode: UInt16) -> Bool {
        !modifierKeyCodes.contains(keyCode)
    }

    private static let modifierKeyCodes: Set<UInt16> = [0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F]

    private static let namedKeys: [UInt16: String] = [
        0x24: "↩", 0x30: "⇥", 0x31: "Space", 0x33: "⌫", 0x35: "⎋", 0x4C: "⌤", 0x75: "⌦",
        0x73: "↖", 0x77: "↘", 0x74: "⇞", 0x79: "⇟",
        0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4", 0x60: "F5", 0x61: "F6", 0x62: "F7",
        0x64: "F8", 0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12", 0x69: "F13", 0x6B: "F14",
        0x71: "F15", 0x6A: "F16", 0x40: "F17", 0x4F: "F18", 0x50: "F19", 0x5A: "F20",
    ]
}
