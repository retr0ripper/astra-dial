import AppKit
import SwiftUI

/// Opens a single Settings window. A plain NSWindow rather than a SwiftUI `Settings` or
/// `Window` scene, which a menu-bar-only (LSUIElement) app can't reliably bring to the front.
final class SettingsWindowController {
    private var window: NSWindow?

    func show(model: AppModel) {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
            window.title = "Astra Dial Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    let model: AppModel
    @Bindable var settings: DialSettings
    let brightness: BrightnessController

    init(model: AppModel) {
        self.model = model
        settings = model.settings
        brightness = model.brightness
    }

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(settings.modeOrder) { mode in
                        ModeRow(mode: mode, settings: settings)
                    }
                    .onMove(perform: settings.moveModes)
                }
                .frame(height: CGFloat(settings.modeOrder.count) * 36)
                .scrollDisabled(true)
            } header: {
                Text("Modes")
            } footer: {
                Text("Drag to reorder the wheel. Turned-off modes are left off the wheel. Volume always stays on: long-press returns to it.")
            }

            Section("Feel") {
                LabeledSlider(title: "Scroll speed", value: $settings.scrollSpeed, range: 16...120, step: 8) {
                    "\(Int($0)) px per click"
                }
                Toggle("Spin faster to move further", isOn: $settings.spinAcceleration)
                LabeledSlider(title: "Brightness step", value: $settings.brightnessStep, range: 1...20, step: 1) {
                    "\(Int($0))% per click"
                }
                LabeledSlider(title: "Double-press window", value: $settings.doublePressWindow, range: 0.2...0.5, step: 0.05) {
                    "\(Int(($0 * 1000).rounded())) ms"
                }
                LabeledSlider(title: "Long-press after", value: $settings.longPressDuration, range: 0.4...1.2, step: 0.1) {
                    "\(Int(($0 * 1000).rounded())) ms"
                }
                LabeledSlider(title: "Close wheel after", value: $settings.wheelTimeout, range: 2...10, step: 1) {
                    "\(Int($0)) s idle"
                }
            }

            Section {
                HStack {
                    Text(displaySummary)
                    Spacer()
                    Button("Rescan") { brightness.scan() }
                }
            } header: {
                Text("Displays")
            } footer: {
                Text("Brightness mode sets external monitors over DDC/CI. Turn on DDC/CI in each monitor's own menu if it doesn't respond.")
            }

            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
                .disabled(!model.canLaunchAtLogin)
                HStack {
                    Spacer()
                    Button("Restore Defaults") { settings.restoreDefaults() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 540)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { brightness.scan() }
    }

    private var displaySummary: String {
        switch brightness.displayCount {
        case 0: "No external displays found"
        case let count:
            "\(count) external display\(count == 1 ? "" : "s") · " +
                (brightness.canRead ? "responding, at \(brightness.level)%" : "not answering reads, using last level \(brightness.level)%")
        }
    }
}

private struct ModeRow: View {
    let mode: DialMode
    @Bindable var settings: DialSettings

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
            Toggle("", isOn: enabled)
                .labelsHidden()
                .disabled(mode == .volume)
            Image(systemName: mode.symbol)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 0) {
                Text(mode.title)
                Text(mode.turnHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Press", selection: pressAction) {
                ForEach(PressAction.allCases) { action in
                    Text(action == .modeDefault ? "Default: \(mode.defaultPressHint)" : action.title).tag(action)
                }
            }
            .frame(width: 210)
        }
        .opacity(enabled.wrappedValue ? 1 : 0.5)
    }

    private var enabled: Binding<Bool> {
        Binding(
            get: { !settings.disabledModes.contains(mode) },
            set: { isOn in
                if isOn { settings.disabledModes.remove(mode) } else { settings.disabledModes.insert(mode) }
            }
        )
    }

    private var pressAction: Binding<PressAction> {
        Binding(
            get: { settings.pressAction(for: mode) },
            set: { settings.pressActions[mode] = $0 == .modeDefault ? nil : $0 }
        )
    }
}

private struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let label: (Double) -> String

    var body: some View {
        HStack {
            Text(title)
            Slider(value: $value, in: range, step: step)
            Text(label(value))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .trailing)
        }
    }
}
