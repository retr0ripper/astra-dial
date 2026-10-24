import Foundation
import Testing
@testable import AstraDial

@Suite struct ModeRunnerTests {
    private func runner(accelerated: Set<DialMode>) -> ModeRunner {
        withDefaults { defaults in
            let settings = DialSettings(defaults: defaults)
            settings.acceleratedModes = accelerated
            return ModeRunner(settings: settings)
        }
    }

    @Test func boostFollowsSpinSpeedInAcceleratedModes() {
        let runner = runner(accelerated: [.tabs])
        #expect(runner.boost(.tabs, detentsPerSecond: 4) == 1)
        #expect(runner.boost(.tabs, detentsPerSecond: 10) == 2)
        #expect(runner.boost(.tabs, detentsPerSecond: 20) == 4)
    }

    @Test func boostIsOneInOtherModes() {
        let runner = runner(accelerated: [.tabs])
        #expect(runner.boost(.scroll, detentsPerSecond: 20) == 1)
    }

    @Test func volumeNeverAccelerates() {
        let runner = runner(accelerated: [.volume])
        #expect(runner.boost(.volume, detentsPerSecond: 20) == 1)
    }
}
