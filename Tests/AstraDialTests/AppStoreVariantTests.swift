import Foundation
import Testing
@testable import AstraDial

/// Run with `swift test -Xswiftc -DAPP_STORE` to check the App Store variant.
@Suite struct AppStoreVariantTests {
    @Test func brightnessIsOnlyInTheDirectBuild() {
        #if APP_STORE
        #expect(!DialMode.available.contains(.brightness))
        #else
        #expect(DialMode.available == DialMode.allCases)
        #endif
    }

    @Test func freshSettingsUseTheAvailableModes() {
        withDefaults { defaults in
            #expect(DialSettings(defaults: defaults).modeOrder == DialMode.available)
        }
    }

    @Test func storedUnavailableModesAreDropped() {
        withDefaults { defaults in
            defaults.set(Data(#"{"modeOrder":["brightness","volume","scroll"]}"#.utf8), forKey: "settings")
            let settings = DialSettings(defaults: defaults)
            #expect(settings.modeOrder.allSatisfy(DialMode.available.contains))
            #expect(Set(settings.modeOrder) == Set(DialMode.available))
        }
    }

    @Test func updateChecksAreOnlyInTheDirectBuild() {
        #if APP_STORE
        #expect(!UpdateChecker.isSupported)
        #else
        #expect(UpdateChecker.isSupported)
        #endif
    }
}
