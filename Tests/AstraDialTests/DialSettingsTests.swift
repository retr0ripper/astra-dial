import AstraCore
import Foundation
import Testing
@testable import AstraDial

/// Each test gets its own UserDefaults suite, removed afterwards.
private func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
    let name = "AstraDialTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    try body(defaults)
}

@Suite struct DialSettingsTests {
    @Test func freshSettingsLeaveCustomOffTheWheel() {
        withDefaults { defaults in
            let settings = DialSettings(defaults: defaults)
            #expect(!settings.enabledModes.contains(.custom))
            #expect(settings.enabledModes.contains(.scroll))
        }
    }

    @Test func changesSurviveReload() {
        withDefaults { defaults in
            let settings = DialSettings(defaults: defaults)
            settings.scrollSpeed = 96
            settings.disabledModes = [.zoom]
            settings.customForward = KeyShortcut(keyCode: 0x1E, modifiers: [.command], keyLabel: "]")
            settings.checkForUpdates = false

            let reloaded = DialSettings(defaults: defaults)
            #expect(reloaded.scrollSpeed == 96)
            #expect(reloaded.disabledModes == [.zoom])
            #expect(reloaded.customForward?.display == "⌘]")
            #expect(!reloaded.checkForUpdates)
        }
    }

    @Test func settingsFromBeforeCustomGetItOffAndAtTheEnd() throws {
        try withDefaults { defaults in
            let old = #"{"modeOrder":["scroll","volume","brightness","zoom","apps","tabs","desktops","undo","scrub","slides"],"disabledModes":[]}"#
            defaults.set(Data(old.utf8), forKey: "settings")

            let settings = DialSettings(defaults: defaults)
            #expect(settings.modeOrder.first == .scroll)
            #expect(settings.modeOrder.last == .custom)
            #expect(settings.disabledModes == [.custom])
        }
    }

    @Test func turningCustomOnSticksAcrossReload() {
        withDefaults { defaults in
            let settings = DialSettings(defaults: defaults)
            settings.disabledModes.remove(.custom)
            #expect(DialSettings(defaults: defaults).enabledModes.contains(.custom))
        }
    }

    @Test func unknownModesAndProfilesAreDropped() {
        withDefaults { defaults in
            let stored = #"{"modeOrder":["volume","teleport"],"appProfiles":[{"bundleID":"a","name":"A","mode":"teleport"},{"bundleID":"b","name":"B","mode":"tabs"}]}"#
            defaults.set(Data(stored.utf8), forKey: "settings")

            let settings = DialSettings(defaults: defaults)
            #expect(Set(settings.modeOrder) == Set(DialMode.allCases))
            #expect(settings.appProfiles.map(\.bundleID) == ["b"])
        }
    }

    @Test func volumeStaysOnEvenWhenDisabled() {
        withDefaults { defaults in
            let settings = DialSettings(defaults: defaults)
            settings.disabledModes.insert(.volume)
            #expect(settings.enabledModes.contains(.volume))
        }
    }

    @Test func profileModeIsSkippedWhenItsModeIsOff() {
        withDefaults { defaults in
            let settings = DialSettings(defaults: defaults)
            settings.addProfile(bundleID: "com.example", name: "Example", mode: .slides)
            #expect(settings.profileMode(forBundleID: "com.example") == .slides)
            settings.disabledModes.insert(.slides)
            #expect(settings.profileMode(forBundleID: "com.example") == nil)
            settings.disabledModes.remove(.slides)
            settings.autoProfiles = false
            #expect(settings.profileMode(forBundleID: "com.example") == nil)
        }
    }
}
