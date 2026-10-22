import Foundation

/// Drops the second copy of an event that arrives through two HID services at once.
/// Over Bluetooth the Astra shows up as two keyboard devices with the same VID:PID, and
/// both deliver every report with the same timestamp, so each knob click arrives twice.
public struct EventDeduplicator: Sendable {
    private struct Key: Hashable {
        let device: DeviceID
        let page: UInt32
        let usage: UInt32
        let value: Int
    }

    /// Copies closer together than this count as one event. A real knob detent repeats
    /// far less often (each click is a down then an up, several ms apart at the fastest spin).
    public var windowTicks: UInt64
    private var recent: [(key: Key, timestamp: UInt64)] = []
    private let capacity = 32

    public init(windowNanoseconds: UInt64 = 1_000_000) {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        windowTicks = windowNanoseconds * UInt64(timebase.denom) / UInt64(timebase.numer)
    }

    /// Returns true when the event is new and should be handled.
    public mutating func accept(_ event: HIDEvent) -> Bool {
        let key = Key(device: event.device, page: event.usagePage, usage: event.usage, value: event.value)
        let isDuplicate = recent.contains { entry in
            entry.key == key && Self.distance(entry.timestamp, event.timestamp) <= windowTicks
        }
        if isDuplicate { return false }
        recent.append((key, event.timestamp))
        if recent.count > capacity { recent.removeFirst(recent.count - capacity) }
        return true
    }

    private static func distance(_ a: UInt64, _ b: UInt64) -> UInt64 { a > b ? a - b : b - a }
}
