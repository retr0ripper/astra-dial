import AstraCore
import Foundation
import Observation

/// Sets external display brightness over DDC/CI. All displays move together.
///
/// DDC calls take tens of milliseconds, so writes run on a serial queue and coalesce: while
/// one write is in flight, further turns only update the target, and the newest target is
/// written next. Many monitors don't answer reads, so the last level set is saved and used
/// as the starting point when a read fails.
@Observable
final class BrightnessController {
    /// Brightness in percent, 0–100.
    private(set) var level: Int
    private(set) var displayCount = 0
    /// Whether the last scan could read a level back from any display.
    private(set) var canRead = false

    @ObservationIgnored private var dimmedFrom: Int?
    @ObservationIgnored private let queue = DispatchQueue(label: "com.astradial.ddc", qos: .userInitiated)
    @ObservationIgnored private var displays: [DDCDisplay] = []   // queue only
    @ObservationIgnored private let lock = NSLock()
    @ObservationIgnored private var pendingLevel: Int?           // lock
    @ObservationIgnored private var isWriting = false            // lock

    private static let levelKey = "brightnessLevel"

    init() {
        let saved = UserDefaults.standard.object(forKey: Self.levelKey) as? Int
        level = saved ?? 50
    }

    /// Finds displays and reads the current level. Call when Brightness mode becomes active.
    func scan() {
        queue.async { [weak self] in
            guard let self else { return }
            displays = DDCDisplay.all()
            let reply = displays.lazy.compactMap { $0.read(DDCPacket.brightness) }.first
            let count = displays.count
            DispatchQueue.main.async {
                self.displayCount = count
                self.canRead = reply != nil
                if let reply {
                    self.level = Int((Double(reply.current) / Double(reply.maximum) * 100).rounded())
                    self.save()
                }
            }
        }
    }

    /// Moves brightness by `delta` percent and returns the new level.
    @discardableResult
    func adjust(by delta: Int) -> Int {
        dimmedFrom = nil
        setLevel(level + delta)
        return level
    }

    /// Dims to 10%, or restores the level from before the last dim.
    @discardableResult
    func toggleDim() -> Int {
        if let previous = dimmedFrom {
            dimmedFrom = nil
            setLevel(previous)
        } else {
            dimmedFrom = level
            setLevel(min(level, 10))
        }
        return level
    }

    private func setLevel(_ newLevel: Int) {
        level = min(100, max(0, newLevel))
        save()
        lock.lock()
        pendingLevel = level
        let shouldStart = !isWriting
        isWriting = true
        lock.unlock()
        if shouldStart { queue.async { [weak self] in self?.drainWrites() } }
    }

    private func drainWrites() {
        if displays.isEmpty { displays = DDCDisplay.all() }
        while true {
            lock.lock()
            guard let target = pendingLevel else {
                isWriting = false
                lock.unlock()
                return
            }
            pendingLevel = nil
            lock.unlock()
            for display in displays {
                display.set(DDCPacket.brightness, value: UInt16(target))
            }
        }
    }

    private func save() {
        UserDefaults.standard.set(level, forKey: Self.levelKey)
    }
}
