import CoreGraphics

/// The knob's modes, in wheel order (clockwise from 12 o'clock).
enum DialMode: String, CaseIterable, Identifiable {
    case volume
    case scroll
    case zoom
    case tabs
    case desktops
    case undo
    case scrub
    case slides

    var id: String { rawValue }

    var title: String {
        switch self {
        case .volume: "Volume"
        case .scroll: "Scroll"
        case .zoom: "Zoom"
        case .tabs: "Tabs"
        case .desktops: "Desktops"
        case .undo: "Undo"
        case .scrub: "Scrub"
        case .slides: "Slides"
        }
    }

    var symbol: String {
        switch self {
        case .volume: "speaker.wave.2"
        case .scroll: "arrow.up.and.down"
        case .zoom: "plus.magnifyingglass"
        case .tabs: "square.on.square"
        case .desktops: "rectangle.split.3x1"
        case .undo: "arrow.uturn.backward"
        case .scrub: "film"
        case .slides: "play.rectangle"
        }
    }

    /// Whether knob turns are taken from macOS in this mode. Volume lets them through so
    /// macOS changes the volume and shows its own HUD.
    var claimsTurns: Bool { self != .volume }

    /// What a turn does, for the menu's hint line.
    var turnHint: String {
        switch self {
        case .volume: "volume"
        case .scroll: "scroll under the pointer"
        case .zoom: "⌘= / ⌘−"
        case .tabs: "⌃Tab / ⌃⇧Tab"
        case .desktops: "⌃→ / ⌃←"
        case .undo: "⇧⌘Z / ⌘Z"
        case .scrub: "→ / ←"
        case .slides: "next / previous slide"
        }
    }

    /// What a single press does, for the menu's hint line.
    var pressHint: String {
        switch self {
        case .volume: "mute"
        case .scroll: "nothing"
        case .zoom: "actual size ⌘0"
        case .tabs: "new tab ⌘T"
        case .desktops: "Mission Control"
        case .undo: "save ⌘S"
        case .scrub: "play/pause (space)"
        case .slides: "black screen (B)"
        }
    }

    /// Performs one detent. Returns a log description.
    func turn(_ direction: Int, detentsPerSecond: Double) -> String {
        let forward = direction > 0
        switch self {
        case .volume:
            return "volume (macOS)"
        case .scroll:
            let pixels = Int32(direction) * 48 * Self.acceleration(detentsPerSecond)
            ScrollSender.scroll(pixels: pixels)
            return "scroll \(pixels)px"
        case .zoom:
            KeySender.press(forward ? .equal : .minus, .maskCommand)
            return forward ? "zoom in" : "zoom out"
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
        }
    }

    /// Performs a single press. Returns a log description.
    func press() -> String {
        switch self {
        case .volume: MediaKeyPoster.tap(.mute)
        case .scroll: break
        case .zoom: KeySender.press(.zero, .maskCommand)
        case .tabs: KeySender.press(.t, .maskCommand)
        case .desktops: KeySender.press(.up, .maskControl)
        case .undo: KeySender.press(.s, .maskCommand)
        case .scrub: KeySender.press(.space)
        case .slides: KeySender.press(.b)
        }
        return pressHint
    }

    /// Faster spins scroll further per detent.
    static func acceleration(_ detentsPerSecond: Double) -> Int32 {
        switch detentsPerSecond {
        case ..<8: 1
        case ..<16: 2
        default: 4
        }
    }
}
