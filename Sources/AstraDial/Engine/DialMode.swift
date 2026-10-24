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
    case custom
    case custom2
    case custom3

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
        case .custom: "Custom"
        case .custom2: "Custom 2"
        case .custom3: "Custom 3"
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
        case .custom: "keyboard"
        case .custom2: "keyboard.badge.ellipsis"
        case .custom3: "keyboard.chevron.compact.down"
        }
    }

    /// Modes that send shortcuts recorded in Settings.
    static let customModes: [DialMode] = [.custom, .custom2, .custom3]

    var isCustom: Bool { Self.customModes.contains(self) }

    /// Whether knob turns are taken from macOS in this mode. Volume lets them through so
    /// macOS changes the volume and shows its own HUD.
    var claimsTurns: Bool { self != .volume }

    /// Whether faster spins can move further. Volume's turns belong to macOS.
    var canAccelerate: Bool { self != .volume }

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
        case .custom, .custom2, .custom3: "your shortcuts"
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
        case .custom, .custom2, .custom3: "your press shortcut"
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
