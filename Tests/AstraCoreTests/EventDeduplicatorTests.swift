import Testing
@testable import AstraCore

private let astra = DeviceID(vendorID: 0x05AC, productID: 0x024F)

private func event(_ usage: UInt32, _ value: Int, at ticks: UInt64) -> HIDEvent {
    HIDEvent(device: astra, productName: "CB Astra", transport: "Bluetooth",
             usagePage: HIDUsage.consumerPage, usage: usage, value: value, timestamp: ticks)
}

/// Feeds events through a fresh deduplicator and returns which ones it accepted.
/// A 1-tick window keeps the tests independent of the machine's timebase.
private func accepted(_ events: [HIDEvent]) -> [Bool] {
    var dedup = EventDeduplicator()
    dedup.windowTicks = 1
    return events.map { dedup.accept($0) }
}

@Suite struct EventDeduplicatorTests {
    @Test func secondCopyWithSameTimestampIsDropped() {
        #expect(accepted([
            event(HIDUsage.volumeIncrement, 1, at: 100),
            event(HIDUsage.volumeIncrement, 1, at: 100),
        ]) == [true, false])
    }

    @Test func interleavedCopiesAreDropped() {
        // Recorded order from the Astra over Bluetooth: down, down, up, up.
        #expect(accepted([
            event(HIDUsage.mute, 1, at: 100),
            event(HIDUsage.mute, 1, at: 100),
            event(HIDUsage.mute, 0, at: 250),
            event(HIDUsage.mute, 0, at: 250),
        ]) == [true, false, true, false])
    }

    @Test func separateDetentsAreKept() {
        #expect(accepted([
            event(HIDUsage.volumeIncrement, 1, at: 100),
            event(HIDUsage.volumeIncrement, 0, at: 103),
            event(HIDUsage.volumeIncrement, 1, at: 110),
            event(HIDUsage.volumeIncrement, 0, at: 113),
        ]) == [true, true, true, true])
    }

    @Test func differentUsagesAtSameTimeAreKept() {
        #expect(accepted([
            event(HIDUsage.volumeIncrement, 1, at: 100),
            event(HIDUsage.volumeDecrement, 1, at: 100),
        ]) == [true, true])
    }
}
