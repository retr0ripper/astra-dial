import AppKit
import AstraCore

/// Posts media-key events (volume, mute) the way a keyboard's media keys arrive, so macOS
/// changes the volume and shows its own HUD. Posted events carry `tag` so MediaKeyTap lets
/// them through.
enum MediaKeyPoster {
    static let tag: Int64 = 0x4153_5452 // "ASTR"

    static func tap(_ key: MediaKey) {
        post(key, isDown: true)
        post(key, isDown: false)
    }

    static func post(_ key: MediaKey, isDown: Bool) {
        let state = isDown ? 0xA : 0xB
        guard let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8, // NX_SUBTYPE_AUX_CONTROL_BUTTONS
            data1: (key.rawValue << 16) | (state << 8),
            data2: -1
        ), let cgEvent = event.cgEvent else { return }
        repost(cgEvent)
    }

    /// Re-sends an event the tap held back, keeping its modifiers (Shift+Option for fine volume).
    static func repost(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: tag)
        event.post(tap: .cghidEventTap)
    }
}
