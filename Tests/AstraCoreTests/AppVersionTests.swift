import Testing
@testable import AstraCore

@Suite struct AppVersionTests {
    @Test func parsesPlainAndTaggedVersions() {
        #expect(AppVersion("0.1.0") == AppVersion(components: [0, 1, 0]))
        #expect(AppVersion("v1.2") == AppVersion(components: [1, 2]))
        #expect(AppVersion("V2.0.10") == AppVersion(components: [2, 0, 10]))
    }

    @Test func rejectsMalformedVersions() {
        #expect(AppVersion("") == nil)
        #expect(AppVersion("v") == nil)
        #expect(AppVersion("1.x") == nil)
        #expect(AppVersion("1..2") == nil)
        #expect(AppVersion("1.0.0-beta") == nil)
    }

    @Test func comparesNumericallyNotLexically() {
        #expect(AppVersion("0.2.0")! > AppVersion("0.1.9")!)
        #expect(AppVersion("0.10.0")! > AppVersion("0.9.0")!)
        #expect(AppVersion("1.0.0")! > AppVersion("0.99.99")!)
    }

    @Test func missingComponentsCountAsZero() {
        #expect(AppVersion("1.0") == AppVersion("1.0.0"))
        #expect(!(AppVersion("1.0")! < AppVersion("1.0.0")!))
        #expect(AppVersion("1.0.1")! > AppVersion("1")!)
    }

    @Test func descriptionJoinsComponents() {
        #expect(AppVersion("v1.2.3")!.description == "1.2.3")
    }
}
