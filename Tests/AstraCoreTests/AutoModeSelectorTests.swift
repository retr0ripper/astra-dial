import Testing
@testable import AstraCore

private enum Mode: Hashable, Sendable { case volume, scroll, slides, scrub }

@Suite struct AutoModeSelectorTests {
    @Test func profiledAppSwitchesToItsMode() {
        var selector = AutoModeSelector(baseMode: Mode.volume)
        #expect(selector.appActivated(profileMode: .slides) == .slides)
    }

    @Test func leavingProfiledAppReturnsToBase() {
        var selector = AutoModeSelector(baseMode: Mode.scroll)
        _ = selector.appActivated(profileMode: .slides)
        #expect(selector.appActivated(profileMode: nil) == .scroll)
    }

    @Test func unprofiledToUnprofiledLeavesModeAlone() {
        var selector = AutoModeSelector(baseMode: Mode.volume)
        #expect(selector.appActivated(profileMode: nil) == nil)
        #expect(selector.appActivated(profileMode: nil) == nil)
    }

    @Test func choiceOutsideProfiledAppBecomesBase() {
        var selector = AutoModeSelector(baseMode: Mode.volume)
        selector.userChose(.scroll)
        _ = selector.appActivated(profileMode: .slides)
        #expect(selector.appActivated(profileMode: nil) == .scroll)
    }

    @Test func choiceInsideProfiledAppIsTemporary() {
        var selector = AutoModeSelector(baseMode: Mode.volume)
        _ = selector.appActivated(profileMode: .slides)
        selector.userChose(.scroll)
        #expect(selector.baseMode == .volume)
        #expect(selector.appActivated(profileMode: nil) == .volume)
    }

    @Test func profiledToProfiledSwitchesDirectly() {
        var selector = AutoModeSelector(baseMode: Mode.volume)
        _ = selector.appActivated(profileMode: .slides)
        #expect(selector.appActivated(profileMode: .scrub) == .scrub)
        #expect(selector.appActivated(profileMode: nil) == .volume)
    }

    @Test func disableReturnsToBaseOnlyFromProfiledApp() {
        var selector = AutoModeSelector(baseMode: Mode.scroll)
        #expect(selector.disable() == nil)
        _ = selector.appActivated(profileMode: .slides)
        #expect(selector.disable() == .scroll)
        #expect(!selector.isInProfiledApp)
    }
}
