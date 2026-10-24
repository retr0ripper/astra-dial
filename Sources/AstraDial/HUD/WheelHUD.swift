import AppKit
import AstraCore
import Observation
import SwiftUI

@Observable
final class HUDState {
    var modes: [DialMode] = DialMode.allCases
    var isWheelOpen = false
    var activeMode: DialMode = .volume
    /// Unwrapped highlight position, so the highlight animates the short way across 12 o'clock.
    var cursor = 0
    var toast: Toast?
    /// Mode names, including the user's names for Custom modes.
    var titles: [DialMode: String] = [:]

    func title(for mode: DialMode) -> String { titles[mode] ?? mode.title }

    struct Toast: Equatable {
        let mode: DialMode
        /// A level in percent to show as a bar, or nil for a plain mode confirmation.
        let level: Int?
    }

    var highlighted: Int { ((cursor % modes.count) + modes.count) % modes.count }
}

/// A click-through, non-activating panel centred on the screen with the pointer. It shows
/// the mode wheel while it's open and a short confirmation when a mode is chosen, and never
/// takes focus from the app the knob is controlling.
final class WheelHUD {
    let state = HUDState()
    private let panel: NSPanel
    private var hideWork: DispatchWorkItem?
    private var toastWork: DispatchWorkItem?

    static let size = CGSize(width: 340, height: 340)

    init() {
        panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: HUDView(state: state))
    }

    func update(wheel: ModeWheel, modes: [DialMode], activeMode: DialMode) {
        state.activeMode = activeMode
        if wheel.isOpen {
            if !state.isWheelOpen {
                state.modes = modes
                state.cursor = wheel.highlighted
                state.toast = nil
                show()
            } else {
                // Step the unwrapped cursor by the shortest distance to the new slot.
                let count = state.modes.count
                var delta = wheel.highlighted - state.highlighted
                if delta > count / 2 { delta -= count } else if delta < -count / 2 { delta += count }
                state.cursor += delta
            }
            state.isWheelOpen = true
        } else if state.isWheelOpen {
            state.isWheelOpen = false
            hideSoon()
        }
    }

    func showToast(_ mode: DialMode, level: Int? = nil) {
        guard !state.isWheelOpen else { return }
        if level == nil { state.activeMode = mode }
        state.toast = HUDState.Toast(mode: mode, level: level)
        show()
        toastWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            state.toast = nil
            hideSoon()
        }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: work)
    }

    private func show() {
        hideWork?.cancel()
        if !panel.isVisible {
            let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
            if let frame = screen?.visibleFrame {
                panel.setFrameOrigin(CGPoint(x: frame.midX - Self.size.width / 2, y: frame.midY - Self.size.height / 2))
            }
        }
        panel.orderFrontRegardless()
    }

    /// Orders the panel out once the closing animation has played and nothing else is showing.
    private func hideSoon() {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !state.isWheelOpen, state.toast == nil else { return }
            panel.orderOut(nil)
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
}
