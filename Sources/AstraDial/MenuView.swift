import AstraCore
import SwiftUI

struct MenuView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            permissions
            Divider()
            knob
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 320)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: model.menuBarSymbol)
                .font(.title2)
                .foregroundStyle(model.isConnected ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Astra Dial").font(.headline)
                Text(model.statusText).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 8) {
            PermissionRow(
                title: "Input Monitoring",
                detail: "Read the knob",
                granted: model.inputMonitoring == .granted,
                action: model.requestInputMonitoring
            )
            PermissionRow(
                title: "Accessibility",
                detail: "Take the knob from macOS and send scrolls (needed for modes)",
                granted: model.accessibilityTrusted,
                action: model.requestAccessibility
            )
            if let error = model.monitorError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private var knob: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Knob").font(.subheadline.weight(.semibold))
                Spacer()
                if model.isPairing {
                    Button("Cancel", action: model.cancelPairing).controlSize(.small)
                } else {
                    Button("Pair…", action: model.startPairing).controlSize(.small)
                }
            }

            if model.isPairing {
                Label("Turn the knob on your keyboard", systemImage: "dial.medium")
                    .font(.callout)
                    .foregroundStyle(Color.accentColor)
            }

            ForEach(model.pairedDevices) { device in
                HStack {
                    Circle()
                        .fill(model.connectedDeviceIDs.contains(device.id) ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 7, height: 7)
                    Text(device.name).lineLimit(1)
                    Spacer()
                    Text("\(device.transport.isEmpty ? "?" : device.transport) · \(device.id.description)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            }

            if !model.pairedDevices.isEmpty {
                Toggle("Use knob for modes", isOn: $model.takeoverEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .font(.callout)

                Picker("Mode", selection: Binding(get: { model.mode }, set: { model.selectMode($0) })) {
                    ForEach(model.settings.enabledModes) { mode in
                        Label(mode.title, systemImage: mode.symbol).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!model.isTakeoverActive)

                Text("Turn: \(model.mode.turnHint) · Press: \(model.pressHint)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    Readout(label: "Mode", value: model.mode.title)
                    Readout(label: "Position", value: "\(model.position)")
                    Readout(label: "Button", value: model.isPressed ? "Down" : "Up")
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(model.log) { line in
                            Text(line.text)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(line.id)
                        }
                    }
                }
                .frame(height: 110)
                .onChange(of: model.log.last?.id) { _, id in
                    if let id { proxy.scrollTo(id, anchor: .bottom) }
                }
            }

            Text("Double-press: mode wheel · Long-press: back to Volume")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var footer: some View {
        HStack {
            Toggle("Launch at login", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.checkbox)
            .disabled(!model.canLaunchAtLogin)
            .help(model.canLaunchAtLogin ? "" : "Available in the bundled app (make app)")
            Spacer()
            if !model.pairedDevices.isEmpty {
                Button("Forget", action: model.forgetDevices).controlSize(.small)
            }
            Button("Settings…", action: model.openSettings)
                .controlSize(.small)
                .keyboardShortcut(",")
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .controlSize(.small)
                .keyboardShortcut("q")
        }
        .font(.callout)
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(granted ? .green : .orange)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.callout)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !granted {
                Button("Grant…", action: action).controlSize(.small)
            }
        }
    }
}

private struct Readout: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.body.monospacedDigit().weight(.medium))
        }
    }
}
