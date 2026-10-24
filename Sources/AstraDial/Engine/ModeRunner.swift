import AstraCore
import Foundation

/// Performs what each mode does on a turn or press, using the user's settings.
final class ModeRunner {
    let settings: DialSettings
    let brightness = BrightnessController()
    let appSwitcher = AppSwitcher()

    /// A mode changed a level the HUD should show (brightness, in percent).
    var onLevel: ((DialMode, Int) -> Void)?

    init(settings: DialSettings) {
        self.settings = settings
    }

    func activate(_ mode: DialMode) {
        if mode == .brightness { brightness.scan() }
    }

    /// Finishes anything a mode left in progress, before switching away or opening the wheel.
    func deactivate(_ mode: DialMode) {
        if mode == .apps { appSwitcher.commit() }
    }

    /// Performs one detent. Returns a log description.
    func turn(_ mode: DialMode, direction: Int, detentsPerSecond: Double) -> String {
        let forward = direction > 0
        let boost = settings.spinAcceleration ? Self.acceleration(detentsPerSecond) : 1
        switch mode {
        case .volume:
            return "volume (macOS)"
        case .brightness:
            let level = brightness.adjust(by: direction * Int(settings.brightnessStep) * boost)
            onLevel?(.brightness, level)
            return "brightness \(level)%"
        case .scroll:
            let pixels = Int32(Double(direction) * settings.scrollSpeed) * Int32(boost)
            ScrollSender.scroll(pixels: pixels)
            return "scroll \(pixels)px"
        case .zoom:
            KeySender.press(forward ? .equal : .minus, .maskCommand)
            return forward ? "zoom in" : "zoom out"
        case .apps:
            appSwitcher.step(direction)
            return forward ? "next app" : "previous app"
        case .tabs:
            KeySender.press(.tab, forward ? .maskControl : [.maskControl, .maskShift])
            return forward ? "next tab" : "previous tab"
        case .desktops:
            KeySender.press(forward ? .right : .left, .maskControl)
            return forward ? "next desktop" : "previous desktop"
        case .undo:
            KeySender.press(.z, forward ? [.maskCommand, .maskShift] : .maskCommand)
            return forward ? "redo" : "undo"
        case .scrub:
            KeySender.press(forward ? .right : .left)
            return forward ? "forward" : "back"
        case .slides:
            KeySender.press(forward ? .right : .left)
            return forward ? "next slide" : "previous slide"
        case .custom:
            guard let shortcut = forward ? settings.customForward : settings.customBack else {
                return "no shortcut set"
            }
            KeySender.press(shortcut)
            return shortcut.display
        }
    }

    /// Performs a single press. Returns a log description.
    func press(_ mode: DialMode) -> String {
        switch settings.pressAction(for: mode) {
        case .modeDefault: return pressDefault(mode)
        case .nothing: return "nothing"
        case .mute: MediaKeyPoster.tap(.mute); return "mute"
        case .playPause: MediaKeyPoster.tap(.play); return "play/pause"
        case .missionControl: KeySender.press(.up, .maskControl); return "Mission Control"
        case .appExpose: KeySender.press(.down, .maskControl); return "App Exposé"
        }
    }

    /// The press hint shown for a mode, following its press setting.
    func pressHint(_ mode: DialMode) -> String {
        let action = settings.pressAction(for: mode)
        guard action == .modeDefault else { return action.title.lowercased() }
        if mode == .custom { return settings.customPress?.display ?? "nothing set" }
        return mode.defaultPressHint
    }

    /// The turn hint shown for a mode; Custom shows its recorded shortcuts.
    func turnHint(_ mode: DialMode) -> String {
        guard mode == .custom else { return mode.turnHint }
        if settings.customForward == nil, settings.customBack == nil { return "no shortcuts set" }
        return "\(settings.customForward?.display ?? "–") / \(settings.customBack?.display ?? "–")"
    }

    private func pressDefault(_ mode: DialMode) -> String {
        switch mode {
        case .volume: MediaKeyPoster.tap(.mute)
        case .brightness: onLevel?(.brightness, brightness.toggleDim())
        case .scroll: break
        case .zoom: KeySender.press(.zero, .maskCommand)
        case .apps: appSwitcher.commit()
        case .tabs: KeySender.press(.t, .maskCommand)
        case .desktops: KeySender.press(.up, .maskControl)
        case .undo: KeySender.press(.s, .maskCommand)
        case .scrub: KeySender.press(.space)
        case .slides: KeySender.press(.b)
        case .custom:
            guard let shortcut = settings.customPress else { return "no shortcut set" }
            KeySender.press(shortcut)
            return shortcut.display
        }
        return mode.defaultPressHint
    }

    /// Faster spins move further per detent.
    static func acceleration(_ detentsPerSecond: Double) -> Int {
        switch detentsPerSecond {
        case ..<8: 1
        case ..<16: 2
        default: 4
        }
    }
}
