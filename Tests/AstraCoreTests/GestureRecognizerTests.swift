import Foundation
import Testing
@testable import AstraCore

/// Replays (time, signal) steps and, between them, ticks at every deadline that falls due,
/// the way the app's timer does. Returns all gestures in order.
private func run(_ steps: [(TimeInterval, KnobSignal)], until end: TimeInterval? = nil) -> [KnobGesture] {
    var recognizer = GestureRecognizer()
    var gestures: [KnobGesture] = []

    func tickUntil(_ time: TimeInterval) {
        while let deadline = recognizer.nextDeadline, deadline <= time {
            gestures += recognizer.tick(at: deadline)
        }
    }

    for (time, signal) in steps {
        tickUntil(time)
        gestures += recognizer.handle(signal, at: time)
    }
    tickUntil(end ?? (steps.last?.0 ?? 0) + 10)
    return gestures
}

@Suite struct GestureRecognizerTests {
    @Test func tapIsPressAfterDoublePressWindow() throws {
        var recognizer = GestureRecognizer()
        #expect(recognizer.handle(.pressDown, at: 0).isEmpty)
        #expect(recognizer.handle(.pressUp, at: 0.15).isEmpty)
        let deadline = try #require(recognizer.nextDeadline)
        #expect(abs(deadline - 0.45) < 1e-9)
        #expect(recognizer.tick(at: 0.44).isEmpty)
        #expect(recognizer.tick(at: deadline) == [.press])
        #expect(recognizer.nextDeadline == nil)
    }

    @Test func twoQuickTapsAreDoublePress() {
        #expect(run([(0, .pressDown), (0.12, .pressUp), (0.25, .pressDown), (0.37, .pressUp)]) == [.doublePress])
    }

    @Test func doublePressFiresOnSecondDown() {
        var recognizer = GestureRecognizer()
        _ = recognizer.handle(.pressDown, at: 0)
        _ = recognizer.handle(.pressUp, at: 0.1)
        #expect(recognizer.handle(.pressDown, at: 0.2) == [.doublePress])
        #expect(recognizer.handle(.pressUp, at: 0.3).isEmpty)
    }

    @Test func slowSecondTapIsTwoPresses() {
        #expect(run([(0, .pressDown), (0.1, .pressUp), (0.5, .pressDown), (0.6, .pressUp)]) == [.press, .press])
    }

    @Test func holdIsLongPressWithNoPressAfterRelease() {
        // Recorded on the Astra: Mute held 2452 ms.
        #expect(run([(0, .pressDown), (2.452, .pressUp)]) == [.longPress])
    }

    @Test func longPressFiresWhileStillHeld() {
        var recognizer = GestureRecognizer()
        _ = recognizer.handle(.pressDown, at: 0)
        #expect(recognizer.nextDeadline == 0.6)
        #expect(recognizer.tick(at: 0.6) == [.longPress])
        #expect(recognizer.nextDeadline == nil)
    }

    @Test func secondPressOfDoubleNeverBecomesLongPress() {
        #expect(run([(0, .pressDown), (0.1, .pressUp), (0.2, .pressDown), (2.0, .pressUp)]) == [.doublePress])
    }

    @Test func turnSettlesWaitingPress() {
        #expect(run([(0, .pressDown), (0.1, .pressUp), (0.2, .turn(1))])
                == [.press, .turn(1, detentsPerSecond: 0)])
    }

    @Test func spinReportsSpeed() {
        let gestures = run([(0, .turn(1)), (0.05, .turn(1)), (0.1, .turn(1))])
        #expect(gestures.count == 3)
        #expect(gestures[0] == .turn(1, detentsPerSecond: 0))
        guard case .turn(1, let speed) = gestures[2] else { Issue.record("expected turn"); return }
        #expect(abs(speed - 20) < 0.001)
    }

    @Test func directionChangeOrPauseResetsSpeed() {
        #expect(run([(0, .turn(1)), (0.05, .turn(-1)), (1.0, .turn(-1))]) == [
            .turn(1, detentsPerSecond: 0),
            .turn(-1, detentsPerSecond: 0),
            .turn(-1, detentsPerSecond: 0),
        ])
    }

    @Test func repeatedDownWithoutUpIsIgnored() {
        #expect(run([(0, .pressDown), (0.05, .pressDown), (0.1, .pressUp)]) == [.press])
    }

    @Test func strayUpIsIgnored() {
        #expect(run([(0, .pressUp)]).isEmpty)
    }
}
