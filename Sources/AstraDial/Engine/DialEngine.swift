import AstraCore
import Foundation

/// Runs knob gestures: against the mode wheel while it's open, otherwise against the active mode.
///
/// Closed: double-press opens the wheel, long-press returns to Volume, press and turn go to the mode.
/// Open: turn moves the highlight, press selects, double-press closes, long-press picks Volume.
/// The wheel closes by itself after `wheelTimeout` seconds without input.
final class DialEngine {
    let modes = DialMode.allCases
    private(set) var mode: DialMode = .volume
    private(set) var wheel = ModeWheel(slotCount: DialMode.allCases.count)

    var onModeChange: ((DialMode) -> Void)?
    var onWheelChange: ((ModeWheel) -> Void)?
    /// A mode was chosen with the knob; the HUD shows a short confirmation.
    var onModeChosen: ((DialMode) -> Void)?

    var wheelTimeout: TimeInterval = 5
    private var timeoutTimer: Timer?

    /// Whether knob turns should be taken from macOS right now.
    var claimsTurns: Bool { wheel.isOpen || mode.claimsTurns }

    func setMode(_ newMode: DialMode) {
        guard newMode != mode else { return }
        mode = newMode
        onModeChange?(newMode)
    }

    func closeWheel() {
        guard wheel.isOpen else { return }
        wheel.cancel()
        timeoutTimer?.invalidate()
        onWheelChange?(wheel)
    }

    /// Performs the gesture and returns a short description for the log.
    @discardableResult
    func perform(_ gesture: KnobGesture) -> String {
        wheel.isOpen ? performInWheel(gesture) : performInMode(gesture)
    }

    private func performInMode(_ gesture: KnobGesture) -> String {
        switch gesture {
        case .doublePress:
            wheel.open(at: modes.firstIndex(of: mode) ?? 0)
            wheelDidChange()
            return "Double-press → wheel"
        case .longPress:
            choose(.volume)
            return "Long-press → Volume"
        case .press:
            return "Press → \(mode.press())"
        case .turn(let direction, let speed):
            return "\(direction > 0 ? "⟳" : "⟲") \(mode.turn(direction, detentsPerSecond: speed))"
        }
    }

    private func performInWheel(_ gesture: KnobGesture) -> String {
        switch gesture {
        case .turn(let direction, _):
            wheel.turn(direction)
            wheelDidChange()
            return "Wheel → \(modes[wheel.highlighted].title)"
        case .press:
            guard let slot = wheel.select() else { return "" }
            wheelDidChange()
            choose(modes[slot])
            return "Wheel → selected \(modes[slot].title)"
        case .doublePress:
            closeWheel()
            return "Wheel closed"
        case .longPress:
            closeWheel()
            choose(.volume)
            return "Wheel → Volume"
        }
    }

    private func choose(_ newMode: DialMode) {
        setMode(newMode)
        onModeChosen?(newMode)
    }

    private func wheelDidChange() {
        timeoutTimer?.invalidate()
        if wheel.isOpen {
            let timer = Timer(timeInterval: wheelTimeout, repeats: false) { [weak self] _ in self?.closeWheel() }
            RunLoop.main.add(timer, forMode: .common)
            timeoutTimer = timer
        }
        onWheelChange?(wheel)
    }
}
