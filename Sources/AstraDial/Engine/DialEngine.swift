import AstraCore
import Foundation

/// The knob's modes. Milestones 3–4 ship Volume and Scroll to exercise the pipeline;
/// the wheel HUD and the remaining modes come in milestone 5.
enum DialMode: String, CaseIterable, Identifiable {
    case volume
    case scroll

    var id: String { rawValue }

    var title: String {
        switch self {
        case .volume: "Volume"
        case .scroll: "Scroll"
        }
    }

    var symbol: String {
        switch self {
        case .volume: "speaker.wave.2"
        case .scroll: "arrow.up.and.down"
        }
    }

    /// Whether knob turns are taken from macOS in this mode. Volume lets them through so
    /// macOS changes the volume and shows its own HUD.
    var claimsTurns: Bool { self != .volume }
}

/// Runs knob gestures against the active mode.
final class DialEngine {
    private(set) var mode: DialMode = .volume
    var onModeChange: ((DialMode) -> Void)?

    func setMode(_ newMode: DialMode) {
        guard newMode != mode else { return }
        mode = newMode
        onModeChange?(newMode)
    }

    /// Performs the gesture and returns a short description for the log.
    @discardableResult
    func perform(_ gesture: KnobGesture) -> String {
        switch gesture {
        case .doublePress:
            let modes = DialMode.allCases
            let next = modes[(modes.firstIndex(of: mode)! + 1) % modes.count]
            setMode(next)
            return "Double-press → \(next.title) mode"

        case .longPress:
            setMode(.volume)
            return "Long-press → Volume mode"

        case .press:
            switch mode {
            case .volume:
                MediaKeyPoster.tap(.mute)
                return "Press → mute"
            case .scroll:
                return "Press → (no action yet)"
            }

        case .turn(let direction, let speed):
            switch mode {
            case .volume:
                return "Turn \(direction > 0 ? "⟳" : "⟲") → volume (macOS)"
            case .scroll:
                let pixels = Int32(direction) * 48 * Self.acceleration(speed)
                ScrollSender.scroll(pixels: pixels)
                return "Turn \(direction > 0 ? "⟳" : "⟲") → scroll \(pixels)px"
            }
        }
    }

    /// Faster spins move further per detent.
    static func acceleration(_ detentsPerSecond: Double) -> Int32 {
        switch detentsPerSecond {
        case ..<8: 1
        case ..<16: 2
        default: 4
        }
    }
}
