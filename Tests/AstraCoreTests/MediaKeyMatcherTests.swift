import Testing
@testable import AstraCore

private let ms: UInt64 = 1_000_000
private let upDown = MediaKeyMatcher.Press(.soundUp, isDown: true)
private let upUp = MediaKeyMatcher.Press(.soundUp, isDown: false)
private let muteDown = MediaKeyMatcher.Press(.mute, isDown: true)

@Suite struct MediaKeyMatcherTests {
    @Test func hidUsagesMapToMediaKeys() {
        #expect(MediaKey(hidUsage: HIDUsage.volumeIncrement) == .soundUp)
        #expect(MediaKey(hidUsage: HIDUsage.volumeDecrement) == .soundDown)
        #expect(MediaKey(hidUsage: HIDUsage.mute) == .mute)
        #expect(MediaKey(hidUsage: HIDUsage.playPause) == nil)
    }

    @Test func knobFirstThenTapIsDropped() {
        var matcher = MediaKeyMatcher()
        #expect(matcher.recordKnob(upDown, at: 0).isEmpty)
        #expect(matcher.tapEvent(id: 1, upDown, at: 2 * ms) == .knob)
    }

    @Test func tapFirstThenKnobDropsPending() {
        var matcher = MediaKeyMatcher()
        #expect(matcher.tapEvent(id: 1, upDown, at: 0) == .pending)
        #expect(matcher.recordKnob(upDown, at: 3 * ms) == [1])
        #expect(!matcher.hasPending)
        #expect(matcher.expire(at: 100 * ms).isEmpty)
    }

    @Test func tapWithNoKnobIsReleased() {
        // Another keyboard's volume key.
        var matcher = MediaKeyMatcher()
        #expect(matcher.tapEvent(id: 1, upDown, at: 0) == .pending)
        #expect(matcher.expire(at: 10 * ms).isEmpty)
        #expect(matcher.expire(at: 25 * ms) == [1])
        #expect(!matcher.hasPending)
    }

    @Test func staleKnobValueDoesNotClaimLaterTap() {
        var matcher = MediaKeyMatcher()
        _ = matcher.recordKnob(upDown, at: 0)
        #expect(matcher.tapEvent(id: 1, upDown, at: 200 * ms) == .pending)
    }

    @Test func directionAndKeyMustMatch() {
        var matcher = MediaKeyMatcher()
        _ = matcher.recordKnob(upDown, at: 0)
        #expect(matcher.tapEvent(id: 1, upUp, at: 1 * ms) == .pending)
        #expect(matcher.tapEvent(id: 2, muteDown, at: 1 * ms) == .pending)
        #expect(matcher.tapEvent(id: 3, upDown, at: 1 * ms) == .knob)
    }

    @Test func eachKnobValueClaimsOneTapEvent() {
        var matcher = MediaKeyMatcher()
        _ = matcher.recordKnob(upDown, at: 0)
        #expect(matcher.tapEvent(id: 1, upDown, at: 1 * ms) == .knob)
        #expect(matcher.tapEvent(id: 2, upDown, at: 2 * ms) == .pending)
    }
}
