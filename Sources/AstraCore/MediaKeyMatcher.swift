import Foundation

/// The macOS media-key codes (NX_KEYTYPE_*) the knob's HID usages turn into.
public enum MediaKey: Int, Sendable {
    case soundUp = 0
    case soundDown = 1
    case mute = 7
    case play = 16

    /// The keys the knob sends. Only these are ever matched or claimed.
    public var isKnobKey: Bool { self != .play }

    public init?(hidUsage usage: UInt32) {
        switch usage {
        case HIDUsage.volumeIncrement: self = .soundUp
        case HIDUsage.volumeDecrement: self = .soundDown
        case HIDUsage.mute: self = .mute
        default: return nil
        }
    }
}

/// Decides which media-key events reaching the event tap came from the paired knob.
///
/// The event tap sees volume/mute events with no source device, while IOHIDManager sees the
/// knob's HID values with their device. Each knob value is matched to the tap event for the
/// same key and direction. Either side can arrive first: a tap event with no knob value yet
/// is held as pending, and released back to the system if no knob value turns up in time
/// (so another keyboard's volume keys still work, about 25 ms late).
///
/// Auto-repeat events are different: macOS generates them while a key is held, with no HID
/// value behind them, so they can't be matched one-to-one. A repeat counts as the knob's
/// while the knob is physically holding that key down, or within `repeatGrace` of its
/// release (a repeat already in flight), and passes through otherwise.
public struct MediaKeyMatcher: Sendable {
    public struct Press: Hashable, Sendable {
        public let key: MediaKey
        public let isDown: Bool
        public init(_ key: MediaKey, isDown: Bool) {
            self.key = key
            self.isDown = isDown
        }
    }

    public enum Decision: Equatable, Sendable {
        /// Came from the knob: drop it.
        case knob
        /// Unknown yet: hold it, and release it if `expire(at:)` returns its id.
        case pending
        /// Not the knob's: let it through untouched.
        case passThrough
    }

    /// How long a knob value waits for its tap event.
    public var knobWindow: UInt64 = 60_000_000
    /// How long a tap event waits for its knob value before it's released.
    public var pendingWindow: UInt64 = 25_000_000
    /// How long after the knob releases a key its in-flight repeats are still the knob's.
    public var repeatGrace: UInt64 = 150_000_000

    private var knobPresses: [(press: Press, at: UInt64)] = []
    private var pending: [(id: Int, press: Press, at: UInt64)] = []
    private var heldKnobKeys: Set<MediaKey> = []
    private var knobReleasedAt: [MediaKey: UInt64] = [:]

    public init() {}

    /// Records a knob value. Returns ids of pending tap events it accounts for; drop them.
    public mutating func recordKnob(_ press: Press, at time: UInt64) -> [Int] {
        prune(at: time)
        if press.isDown {
            heldKnobKeys.insert(press.key)
        } else {
            heldKnobKeys.remove(press.key)
            knobReleasedAt[press.key] = time
        }
        if let index = pending.firstIndex(where: { $0.press == press }) {
            return [pending.remove(at: index).id]
        }
        knobPresses.append((press, time))
        return []
    }

    public mutating func tapEvent(id: Int, _ press: Press, at time: UInt64) -> Decision {
        prune(at: time)
        if let index = knobPresses.firstIndex(where: { $0.press == press }) {
            knobPresses.remove(at: index)
            return .knob
        }
        pending.append((id, press, time))
        return .pending
    }

    /// An auto-repeat event from the tap: the knob's while the knob holds that key down,
    /// or just after it let go.
    public func tapRepeat(_ key: MediaKey, at time: UInt64) -> Decision {
        if heldKnobKeys.contains(key) { return .knob }
        if let released = knobReleasedAt[key], time &- released <= repeatGrace { return .knob }
        return .passThrough
    }

    /// Returns ids of pending tap events that waited too long; release them to the system.
    public mutating func expire(at time: UInt64) -> [Int] {
        let expired = pending.filter { time &- $0.at >= pendingWindow }.map(\.id)
        pending.removeAll { time &- $0.at >= pendingWindow }
        return expired
    }

    public var hasPending: Bool { !pending.isEmpty }

    private mutating func prune(at time: UInt64) {
        knobPresses.removeAll { time &- $0.at > knobWindow }
    }
}
