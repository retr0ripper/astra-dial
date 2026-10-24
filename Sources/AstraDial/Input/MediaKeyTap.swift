import AppKit
import AstraCore
import CoreGraphics
import os

private let log = Logger(subsystem: "com.astradial.AstraDial", category: "MediaKeyTap")

/// Intercepts volume and mute media-key events at the HID event tap and drops the ones that
/// came from the paired knob, when the active mode wants them. Other keyboards' volume keys
/// pass through (held up to 25 ms while MediaKeyMatcher waits for a knob value). Needs
/// Accessibility for an active tap.
final class MediaKeyTap {
    /// Asked for each volume/mute event; return true to take knob events for that key from macOS.
    var shouldClaim: (MediaKey) -> Bool = { _ in false }

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var matcher = MediaKeyMatcher()
    private var held: [Int: CGEvent] = [:]
    private var nextID = 0
    private var expiryTimer: Timer?
    private var hasClaimed = false

    var isRunning: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    /// Returns false when the tap can't be created, which means Accessibility isn't granted.
    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        let mask = CGEventMask(1) << CGEventMask(NSEvent.EventType.systemDefined.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                return Unmanaged<MediaKeyTap>.fromOpaque(context).takeUnretainedValue().handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            log.error("couldn't create the event tap")
            return false
        }
        log.info("event tap created")

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        runLoopSource = source
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
        releaseAllHeld()
    }

    /// Called for every volume/mute HID value from the paired keyboard.
    func recordKnob(_ key: MediaKey, isDown: Bool) {
        for id in matcher.recordKnob(.init(key, isDown: isDown), at: Self.now()) {
            held[id] = nil
        }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard event.getIntegerValueField(.eventSourceUserData) != MediaKeyPoster.tag,
              let (press, isRepeat) = Self.mediaKeyPress(from: event),
              shouldClaim(press.key) else {
            return Unmanaged.passUnretained(event)
        }

        // Auto-repeats have no HID value to match; see MediaKeyMatcher.tapRepeat.
        if isRepeat {
            let decision = matcher.tapRepeat(press.key, at: Self.now())
            log.debug("repeat key=\(press.key.rawValue) down=\(press.isDown) → \(String(describing: decision))")
            return decision == .knob ? nil : Unmanaged.passUnretained(event)
        }

        nextID += 1
        let decision = matcher.tapEvent(id: nextID, press, at: Self.now())
        log.debug("event key=\(press.key.rawValue) down=\(press.isDown) → \(String(describing: decision))")
        switch decision {
        case .knob:
            if !hasClaimed {
                hasClaimed = true
                log.info("took the first knob event from macOS")
            }
            return nil
        case .pending:
            if let copy = event.copy() { held[nextID] = copy }
            scheduleExpiry()
            return nil
        case .passThrough:
            return Unmanaged.passUnretained(event)
        }
    }

    private func scheduleExpiry() {
        guard expiryTimer == nil else { return }
        let timer = Timer(timeInterval: 0.005, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            for id in matcher.expire(at: Self.now()) {
                if let event = held.removeValue(forKey: id) {
                    log.debug("released held event \(id) to the system")
                    MediaKeyPoster.repost(event)
                }
            }
            if !matcher.hasPending {
                timer.invalidate()
                expiryTimer = nil
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        expiryTimer = timer
    }

    private func releaseAllHeld() {
        expiryTimer?.invalidate()
        expiryTimer = nil
        for event in held.values { MediaKeyPoster.repost(event) }
        held = [:]
        matcher = MediaKeyMatcher()
    }

    /// Parses a media-key event. Bit 0 of data1 is set on auto-repeats.
    static func mediaKeyPress(from event: CGEvent) -> (MediaKeyMatcher.Press, isRepeat: Bool)? {
        guard event.type.rawValue == UInt32(NSEvent.EventType.systemDefined.rawValue),
              let nsEvent = NSEvent(cgEvent: event),
              nsEvent.subtype.rawValue == 8 else { return nil }
        let keyCode = (nsEvent.data1 & 0xFFFF_0000) >> 16
        let state = (nsEvent.data1 & 0xFF00) >> 8
        guard let key = MediaKey(rawValue: keyCode), state == 0xA || state == 0xB else { return nil }
        return (.init(key, isDown: state == 0xA), nsEvent.data1 & 0x1 != 0)
    }

    private static func now() -> UInt64 { clock_gettime_nsec_np(CLOCK_UPTIME_RAW) }
}
