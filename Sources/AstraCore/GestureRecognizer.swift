import Foundation

/// A gesture made with the knob. Hold + turn isn't here: the Astra sends no turn events
/// while the knob is pressed (docs/phase0-findings.md).
public enum KnobGesture: Equatable, Sendable {
    /// One detent. `detentsPerSecond` is 0 for the first detent after a pause or a direction change.
    case turn(Int, detentsPerSecond: Double)
    case press
    case doublePress
    case longPress
}

/// Turns knob signals into gestures. Pure and clock-free: callers pass the time with every
/// signal, and call `tick(at:)` at `nextDeadline` so timed gestures (a single press waiting
/// out the double-press window, a long press) fire without another signal.
public struct GestureRecognizer: Sendable {
    /// Longest gap between releasing the first press and starting the second.
    public var doublePressWindow: TimeInterval = 0.3
    /// How long the knob has to stay down to count as a long press.
    public var longPressDuration: TimeInterval = 0.6
    /// Detents further apart than this start a new spin, so speed resets to 0.
    public var spinGap: TimeInterval = 0.25

    private var downAt: TimeInterval?
    private var longPressFired = false
    private var inDoublePress = false
    private var releasedPressAt: TimeInterval?
    private var lastTurn: (direction: Int, at: TimeInterval)?

    public init() {}

    /// When `tick(at:)` next needs to run, or nil when nothing is waiting.
    public var nextDeadline: TimeInterval? {
        var deadlines: [TimeInterval] = []
        if let downAt, !longPressFired, !inDoublePress { deadlines.append(downAt + longPressDuration) }
        if let releasedPressAt { deadlines.append(releasedPressAt + doublePressWindow) }
        return deadlines.min()
    }

    public mutating func handle(_ signal: KnobSignal, at time: TimeInterval) -> [KnobGesture] {
        var gestures = tick(at: time)

        switch signal {
        case .pressDown:
            guard downAt == nil else { break }
            if releasedPressAt != nil {
                // Fire on the second down rather than its release so the wheel opens immediately.
                releasedPressAt = nil
                inDoublePress = true
                gestures.append(.doublePress)
            }
            downAt = time
            longPressFired = false

        case .pressUp:
            guard downAt != nil else { break }
            downAt = nil
            if inDoublePress {
                inDoublePress = false
            } else if !longPressFired {
                releasedPressAt = time
            }
            longPressFired = false

        case .turn(let direction):
            // Turning settles a waiting press: it was a single press, not the start of a double.
            if releasedPressAt != nil {
                releasedPressAt = nil
                gestures.append(.press)
            }
            var speed = 0.0
            if let last = lastTurn, last.direction == direction, time - last.at <= spinGap {
                speed = 1 / max(time - last.at, 0.001)
            }
            lastTurn = (direction, time)
            gestures.append(.turn(direction, detentsPerSecond: speed))
        }
        return gestures
    }

    public mutating func tick(at time: TimeInterval) -> [KnobGesture] {
        var gestures: [KnobGesture] = []
        // Compare against the same sums nextDeadline returns, so ticking at a deadline always fires it.
        if let downAt, !longPressFired, !inDoublePress, time >= downAt + longPressDuration {
            longPressFired = true
            gestures.append(.longPress)
        }
        if let releasedPressAt, time >= releasedPressAt + doublePressWindow {
            self.releasedPressAt = nil
            gestures.append(.press)
        }
        return gestures
    }
}
