import AstraCore
import Foundation

/// Runs knob gestures: against the mode wheel while it's open, otherwise against the active mode.
///
/// Closed: double-press opens the wheel, long-press returns to Volume, press and turn go to the mode.
/// Open: turn moves the highlight, press selects, double-press closes, long-press picks Volume.
/// The wheel closes by itself after the Settings timeout without input.
final class DialEngine {
    let settings: DialSettings
    let runner: ModeRunner
    private(set) var mode: DialMode = .volume
    private(set) var wheel = ModeWheel(slotCount: 1)
    /// The modes on the wheel while it's open, fixed when it opens.
    private(set) var wheelModes: [DialMode] = []

    var onModeChange: ((DialMode) -> Void)?
    var onWheelChange: ((ModeWheel) -> Void)?
    /// A mode was chosen with the knob; the HUD shows a short confirmation.
    var onModeChosen: ((DialMode) -> Void)?

    private var timeoutTimer: Timer?

    init(settings: DialSettings, runner: ModeRunner) {
        self.settings = settings
        self.runner = runner
    }

    /// Whether knob turns should be taken from macOS right now.
    var claimsTurns: Bool { wheel.isOpen || mode.claimsTurns }

    func setMode(_ newMode: DialMode) {
        guard newMode != mode else { return }
        runner.deactivate(mode)
        mode = newMode
        runner.activate(newMode)
        onModeChange?(newMode)
    }

    /// Falls back to Volume if the active mode was turned off in Settings.
    func settingsDidChange() {
        if !settings.enabledModes.contains(mode) { setMode(.volume) }
    }

    func closeWheel() {
        guard wheel.isOpen else { return }
        wheel.cancel()
        timeoutTimer?.invalidate()
        onWheelChange?(wheel)
    }

    /// Finishes anything in progress (a held ⌘Tab) and returns to Volume.
    func reset() {
        closeWheel()
        runner.deactivate(mode)
        setMode(.volume)
    }

    /// Performs the gesture and returns a short description for the log.
    @discardableResult
    func perform(_ gesture: KnobGesture) -> String {
        wheel.isOpen ? performInWheel(gesture) : performInMode(gesture)
    }

    private func performInMode(_ gesture: KnobGesture) -> String {
        switch gesture {
        case .doublePress:
            runner.deactivate(mode)
            wheelModes = settings.enabledModes
            wheel = ModeWheel(slotCount: wheelModes.count)
            wheel.open(at: wheelModes.firstIndex(of: mode) ?? 0)
            wheelDidChange()
            return "Double-press → wheel"
        case .longPress:
            choose(.volume)
            return "Long-press → Volume"
        case .press:
            return "Press → \(runner.press(mode))"
        case .turn(let direction, let speed):
            return "\(direction > 0 ? "⟳" : "⟲") \(runner.turn(mode, direction: direction, detentsPerSecond: speed))"
        }
    }

    private func performInWheel(_ gesture: KnobGesture) -> String {
        switch gesture {
        case .turn(let direction, _):
            wheel.turn(direction)
            wheelDidChange()
            return "Wheel → \(wheelModes[wheel.highlighted].title)"
        case .press:
            guard let slot = wheel.select() else { return "" }
            wheelDidChange()
            choose(wheelModes[slot])
            return "Wheel → selected \(wheelModes[slot].title)"
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
            let timer = Timer(timeInterval: settings.wheelTimeout, repeats: false) { [weak self] _ in self?.closeWheel() }
            RunLoop.main.add(timer, forMode: .common)
            timeoutTimer = timer
        }
        onWheelChange?(wheel)
    }
}
