import Foundation

/// Decides mode changes for per-app profiles.
///
/// The user's own choice outside profiled apps is the base mode. Activating an app with a
/// profile switches to its mode; activating an app without one returns to the base mode.
/// A choice made inside a profiled app is a temporary override that lasts until the next
/// app switch, so it never replaces the base mode.
public struct AutoModeSelector<Mode: Hashable & Sendable>: Sendable {
    public private(set) var baseMode: Mode
    public private(set) var isInProfiledApp = false

    public init(baseMode: Mode) {
        self.baseMode = baseMode
    }

    /// Call when an app becomes frontmost. `profileMode` is that app's profile mode, or nil.
    /// Returns the mode to switch to, or nil to stay in the current mode.
    public mutating func appActivated(profileMode: Mode?) -> Mode? {
        if let profileMode {
            isInProfiledApp = true
            return profileMode
        }
        guard isInProfiledApp else { return nil }
        isInProfiledApp = false
        return baseMode
    }

    /// Call when the user picks a mode (wheel, long-press, menu).
    public mutating func userChose(_ mode: Mode) {
        if !isInProfiledApp { baseMode = mode }
    }

    /// Call when profiles are turned off. Returns the mode to go back to, if any.
    public mutating func disable() -> Mode? {
        guard isInProfiledApp else { return nil }
        isInProfiledApp = false
        return baseMode
    }
}
