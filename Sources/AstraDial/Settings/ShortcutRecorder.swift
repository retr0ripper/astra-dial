import AppKit
import AstraCore
import SwiftUI

/// A button that records the next key combination typed while it's active.
/// Esc cancels recording; the clear button removes the shortcut.
struct ShortcutRecorder: View {
    @Binding var shortcut: KeyShortcut?
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 4) {
            Button {
                isRecording ? stopRecording() : startRecording()
            } label: {
                Text(isRecording ? "Type shortcut…" : shortcut?.display ?? "Record Shortcut")
                    .frame(minWidth: 120)
                    .foregroundStyle(isRecording ? Color.accentColor : shortcut == nil ? .secondary : .primary)
            }
            if shortcut != nil, !isRecording {
                Button {
                    shortcut = nil
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Clear shortcut")
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == 0x35, flags.isDisjoint(with: [.command, .control, .option, .shift]) {
                stopRecording()
                return nil
            }
            guard KeyShortcut.isRecordable(keyCode: event.keyCode) else { return nil }
            var modifiers: KeyShortcut.Modifiers = []
            if flags.contains(.control) { modifiers.insert(.control) }
            if flags.contains(.option) { modifiers.insert(.option) }
            if flags.contains(.shift) { modifiers.insert(.shift) }
            if flags.contains(.command) { modifiers.insert(.command) }
            let label = KeyShortcut.label(forKeyCode: event.keyCode, characters: event.charactersIgnoringModifiers)
            shortcut = KeyShortcut(keyCode: event.keyCode, modifiers: modifiers, keyLabel: label)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
