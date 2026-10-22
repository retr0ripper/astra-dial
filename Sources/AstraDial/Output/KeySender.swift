import CoreGraphics

/// Posts keyboard shortcuts to the frontmost app.
enum KeySender {
    /// macOS virtual key codes (kVK_*) for the keys the modes use.
    enum Key: CGKeyCode {
        case s = 0x01
        case z = 0x06
        case b = 0x0B
        case t = 0x11
        case equal = 0x18
        case minus = 0x1B
        case zero = 0x1D
        case tab = 0x30
        case space = 0x31
        case left = 0x7B
        case right = 0x7C
        case down = 0x7D
        case up = 0x7E

        var isArrow: Bool { [.left, .right, .down, .up].contains(self) }
    }

    static func press(_ key: Key, _ modifiers: CGEventFlags = []) {
        var flags = modifiers
        // Real arrow keys carry these flags; Spaces ignores ⌃← / ⌃→ without them.
        if key.isArrow { flags.formUnion([.maskSecondaryFn, .maskNumericPad]) }

        let source = CGEventSource(stateID: .hidSystemState)
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key.rawValue, keyDown: isDown) else { continue }
            event.flags = flags
            event.post(tap: .cghidEventTap)
        }
    }
}
