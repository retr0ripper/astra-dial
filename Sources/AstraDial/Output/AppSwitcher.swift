import CoreGraphics
import Foundation

/// Drives the ⌘Tab app switcher: the first detent holds ⌘ down, every detent presses Tab
/// (⇧Tab backwards), and `commit` releases ⌘ to switch. It also commits by itself after
/// `idleCommit` seconds without a turn, so ⌘ is never left held.
final class AppSwitcher {
    var idleCommit: TimeInterval = 1.2
    private(set) var isActive = false
    private var commitTimer: Timer?
    private let commandKey: CGKeyCode = 0x37

    deinit { commit() }

    func step(_ direction: Int) {
        if !isActive {
            postCommand(isDown: true)
            isActive = true
        }
        KeySender.press(.tab, direction > 0 ? .maskCommand : [.maskCommand, .maskShift])
        restartTimer()
    }

    func commit() {
        commitTimer?.invalidate()
        commitTimer = nil
        guard isActive else { return }
        isActive = false
        postCommand(isDown: false)
    }

    private func restartTimer() {
        commitTimer?.invalidate()
        let timer = Timer(timeInterval: idleCommit, repeats: false) { [weak self] _ in self?.commit() }
        RunLoop.main.add(timer, forMode: .common)
        commitTimer = timer
    }

    private func postCommand(isDown: Bool) {
        guard let event = CGEvent(keyboardEventSource: CGEventSource(stateID: .hidSystemState),
                                  virtualKey: commandKey, keyDown: isDown) else { return }
        event.type = .flagsChanged
        event.flags = isDown ? .maskCommand : []
        event.post(tap: .cghidEventTap)
    }
}
