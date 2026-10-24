import AstraCore
import Foundation
import Testing
@testable import AstraDial

@Suite struct DialSettingsTests {
    @Test func freshSettingsLeaveCustomModesOffTheWheel() {
        withDefaults { defaults in
            let settings = DialSettings(defaults: defaults)
            for mode in DialMode.customModes { #expect(!settings.enabledModes.contains(mode)) }
            #expect(settings.enabledModes.contains(.scroll))
        }
    }

    @Test func changesSurviveReload() {
        withDefaults { defaults in
            let settings = DialSettings(defaults: defaults)
            settings.scrollSpeed = 96
            settings.disabledModes = [.zoom]
            settings.customSets[.custom2] = CustomShortcuts(
                name: "Video", forward: KeyShortcut(keyCode: 0x25, modifiers: [], keyLabel: "l")
            )
            settings.acceleratedModes = [.tabs]
            settings.checkForUpdates = false

            let reloaded = DialSettings(defaults: defaults)
            #expect(reloaded.scrollSpeed == 96)
            #expect(reloaded.disabledModes == [.zoom])
            #expect(reloaded.customSets[.custom2]?.forward?.display == "L")
            #expect(reloaded.title(for: .custom2) == "Video")
            #expect(reloaded.acceleratedModes == [.tabs])
            #expect(!reloaded.checkForUpdates)
        }
    }

    @Test func settingsFromBeforeCustomGetItOffAndAtTheEnd() throws {
        try withDefaults { defaults in
            let old = #"{"modeOrder":["scroll","volume","brightness","zoom","apps","tabs","desktops","undo","scrub","slides"],"disabledModes":[]}"#
            defaults.set(Data(old.utf8), forKey: "settings")

            let settings = DialSettings(defaults: defaults)
            #expect(settings.modeOrder.first == .scroll)
            #expect(Array(settings.modeOrder.suffix(3)) == DialMode.customModes)
            #expect(settings.disabledModes == Set(DialMode.customModes))
        }
    }

    @Test func turningCustomOnSticksAcrossReload() {
        withDefaults { defaults in
            let settings = DialSettings(defaults: defaults)
            settings.disabledModes.remove(.custom)
            #expect(DialSettings(defaults: defaults).enabledModes.contains(.custom))
        }
    }

    @Test func customShortcutsFrom020MoveToTheFirstCustomMode() {
        withDefaults { defaults in
            let stored = #"{"modeOrder":["volume","custom"],"disabledModes":[],"customForward":{"keyCode":30,"modifiers":8,"keyLabel":"]"},"customPress":{"keyCode":17,"modifiers":8,"keyLabel":"t"}}"#
            defaults.set(Data(stored.utf8), forKey: "settings")

            let settings = DialSettings(defaults: defaults)
            #expect(settings.customSets[.custom]?.forward?.display == "⌘]")
            #expect(settings.customSets[.custom]?.back == nil)
            #expect(settings.customSets[.custom]?.press?.display == "⌘T")
            #expect(settings.enabledModes.contains(.custom))
            #expect(!settings.enabledModes.contains(.custom2))
        }
    }

    @Test func spinAccelerationOffFrom020TurnsOffEveryMode() {
        withDefaults { defaults in
            defaults.set(Data(#"{"spinAcceleration":false}"#.utf8), forKey: "settings")
            #expect(DialSettings(defaults: defaults).acceleratedModes.isEmpty)
        }
    }

    @Test func accelerationDefaultsToScrollAndBrightness() {
        withDefaults { defaults in
            #expect(DialSettings(defaults: defaults).acceleratedModes == [.scroll, .brightness])
        }
    }

    @Test func titleFallsBackToTheModeTitle() {
        withDefaults { defaults in
            let settings = DialSettings(defaults: defaults)
            #expect(settings.title(for: .custom3) == "Custom 3")
            settings.customSets[.custom3] = CustomShortcuts(name: "  ")
            #expect(settings.title(for: .custom3) == "Custom 3")
            settings.customSets[.custom3] = CustomShortcuts(name: " Figma ")
            #expect(settings.title(for: .custom3) == "Figma")
            #expect(settings.title(for: .tabs) == "Tabs")
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
