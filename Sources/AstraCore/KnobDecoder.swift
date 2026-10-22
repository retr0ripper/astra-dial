import Foundation

/// What the knob did, independent of which HID usages it happens to send.
public enum KnobSignal: Equatable, Sendable {
    case turn(Int)      // +1 clockwise, -1 counter-clockwise, per detent
    case pressDown
    case pressUp
}

/// Turns raw HID events from the paired keyboard into knob signals.
/// The Astra's knob changes volume per detent and mutes on press. Depending on firmware that
/// arrives as consumer-page media keys or as keyboard-page volume keys; both are accepted.
public struct KnobDecoder: Sendable {
    /// Devices whose events count as the knob. Empty means "accept any device".
    public var devices: Set<DeviceID>

    public init(devices: Set<DeviceID> = []) {
        self.devices = devices
    }

    private enum Role { case up, down, press }

    private static func role(of event: HIDEvent) -> Role? {
        switch (event.usagePage, event.usage) {
        case (HIDUsage.consumerPage, HIDUsage.volumeIncrement), (HIDUsage.keyboardPage, HIDUsage.keyboardVolumeUp):
            return .up
        case (HIDUsage.consumerPage, HIDUsage.volumeDecrement), (HIDUsage.keyboardPage, HIDUsage.keyboardVolumeDown):
            return .down
        case (HIDUsage.consumerPage, HIDUsage.mute), (HIDUsage.consumerPage, HIDUsage.playPause),
             (HIDUsage.keyboardPage, HIDUsage.keyboardMute):
            return .press
        default:
            return nil
        }
    }

    public func decode(_ event: HIDEvent) -> KnobSignal? {
        if !devices.isEmpty, !devices.contains(event.device) { return nil }
        switch Self.role(of: event) {
        case .up: return event.value != 0 ? .turn(1) : nil
        case .down: return event.value != 0 ? .turn(-1) : nil
        case .press: return event.value != 0 ? .pressDown : .pressUp
        case nil: return nil
        }
    }

    /// A key-down of volume up/down: the signal used to pair a keyboard by turning its knob.
    public static func isPairingCandidate(_ event: HIDEvent) -> Bool {
        guard event.value != 0, let role = role(of: event) else { return false }
        return role == .up || role == .down
    }
}
