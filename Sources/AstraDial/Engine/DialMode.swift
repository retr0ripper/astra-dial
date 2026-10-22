/// The knob's modes. `allCases` is the default wheel order (clockwise from 12 o'clock);
/// users can reorder and hide modes in Settings.
enum DialMode: String, CaseIterable, Identifiable, Codable {
    case volume
    case brightness
    case scroll
    case zoom
    case apps
    case tabs
    case desktops
    case undo
    case scrub
    case slides

    var id: String { rawValue }

    var title: String {
        switch self {
        case .volume: "Volume"
        case .brightness: "Brightness"
        case .scroll: "Scroll"
        case .zoom: "Zoom"
        case .apps: "Apps"
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
        case .brightness: "sun.max"
        case .scroll: "arrow.up.and.down"
        case .zoom: "plus.magnifyingglass"
        case .apps: "app.dashed"
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

    /// What a turn does, for hints in the menu and Settings.
    var turnHint: String {
        switch self {
        case .volume: "volume"
        case .brightness: "external display brightness"
        case .scroll: "scroll under the pointer"
        case .zoom: "⌘= / ⌘−"
        case .apps: "⌘Tab app switcher"
        case .tabs: "⌃Tab / ⌃⇧Tab"
        case .desktops: "⌃→ / ⌃←"
        case .undo: "⇧⌘Z / ⌘Z"
        case .scrub: "→ / ←"
        case .slides: "next / previous slide"
        }
    }

    /// What the mode's own press does (PressAction.modeDefault).
    var defaultPressHint: String {
        switch self {
        case .volume: "mute"
        case .brightness: "dim / restore"
        case .scroll: "nothing"
        case .zoom: "actual size ⌘0"
        case .apps: "switch to selected app"
        case .tabs: "new tab ⌘T"
        case .desktops: "Mission Control"
        case .undo: "save ⌘S"
        case .scrub: "play/pause (space)"
        case .slides: "black screen (B)"
        }
    }
}

/// What a single press does in a mode. `modeDefault` runs the mode's own action.
enum PressAction: String, CaseIterable, Identifiable, Codable {
    case modeDefault
    case nothing
    case mute
    case playPause
    case missionControl
    case appExpose

    var id: String { rawValue }

    var title: String {
        switch self {
        case .modeDefault: "Mode default"
        case .nothing: "Nothing"
        case .mute: "Mute"
        case .playPause: "Play/Pause"
        case .missionControl: "Mission Control"
        case .appExpose: "App Exposé"
        }
    }
}
