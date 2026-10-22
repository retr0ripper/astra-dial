import Testing
@testable import AstraCore

private let astra = DeviceID(vendorID: 0x1234, productID: 0x5678)
private let macbook = DeviceID(vendorID: 0x05AC, productID: 0x0281)

private func event(_ usage: UInt32, _ value: Int, page: UInt32 = HIDUsage.consumerPage, device: DeviceID = astra) -> HIDEvent {
    HIDEvent(device: device, productName: "Astra", transport: "Bluetooth",
             usagePage: page, usage: usage, value: value, timestamp: 0)
}

@Suite struct KnobDecoderTests {
    let decoder = KnobDecoder(devices: [astra])

    @Test func volumeUpKeyDownIsClockwiseTurn() {
        #expect(decoder.decode(event(HIDUsage.volumeIncrement, 1)) == .turn(1))
    }

    @Test func volumeDownKeyDownIsCounterClockwiseTurn() {
        #expect(decoder.decode(event(HIDUsage.volumeDecrement, 1)) == .turn(-1))
    }

    @Test func turnKeyUpIsIgnored() {
        #expect(decoder.decode(event(HIDUsage.volumeIncrement, 0)) == nil)
        #expect(decoder.decode(event(HIDUsage.volumeDecrement, 0)) == nil)
    }

    @Test func muteGivesPressDownAndUp() {
        #expect(decoder.decode(event(HIDUsage.mute, 1)) == .pressDown)
        #expect(decoder.decode(event(HIDUsage.mute, 0)) == .pressUp)
    }

    @Test func playPauseAlsoCountsAsPress() {
        #expect(decoder.decode(event(HIDUsage.playPause, 1)) == .pressDown)
    }

    @Test func otherDevicesAreIgnored() {
        #expect(decoder.decode(event(HIDUsage.volumeIncrement, 1, device: macbook)) == nil)
    }

    @Test func emptyDeviceSetAcceptsAnyDevice() {
        #expect(KnobDecoder().decode(event(HIDUsage.volumeIncrement, 1, device: macbook)) == .turn(1))
    }

    @Test func keyboardPageIsIgnored() {
        #expect(decoder.decode(event(0x04, 1, page: HIDUsage.keyboardPage)) == nil)
    }

    @Test func keyboardPageVolumeKeysAreTurnsAndPress() {
        #expect(decoder.decode(event(HIDUsage.keyboardVolumeUp, 1, page: HIDUsage.keyboardPage)) == .turn(1))
        #expect(decoder.decode(event(HIDUsage.keyboardVolumeDown, 1, page: HIDUsage.keyboardPage)) == .turn(-1))
        #expect(decoder.decode(event(HIDUsage.keyboardMute, 1, page: HIDUsage.keyboardPage)) == .pressDown)
        #expect(decoder.decode(event(HIDUsage.keyboardMute, 0, page: HIDUsage.keyboardPage)) == .pressUp)
        #expect(KnobDecoder.isPairingCandidate(event(HIDUsage.keyboardVolumeUp, 1, page: HIDUsage.keyboardPage)))
    }

    @Test func pairingCandidateIsVolumeKeyDownOnly() {
        #expect(KnobDecoder.isPairingCandidate(event(HIDUsage.volumeIncrement, 1)))
        #expect(KnobDecoder.isPairingCandidate(event(HIDUsage.volumeDecrement, 1)))
        #expect(!KnobDecoder.isPairingCandidate(event(HIDUsage.volumeIncrement, 0)))
        #expect(!KnobDecoder.isPairingCandidate(event(HIDUsage.mute, 1)))
    }
}
