import AppKit
import SwiftUI
import UniformTypeIdentifiers

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

            Section {
                Toggle("Switch modes automatically per app", isOn: $settings.autoProfiles)
                ForEach(settings.appProfiles) { profile in
                    ProfileRow(profile: profile, settings: settings)
                }
                .disabled(!settings.autoProfiles)
                AddProfileMenu(settings: settings)
                    .disabled(!settings.autoProfiles)
            } header: {
                Text("App modes")
            } footer: {
                Text("Switching to one of these apps selects its mode; leaving returns to the mode you were using. A mode you pick inside the app lasts until you switch apps.")
            }

            Section {
                LabeledContent("Turn clockwise") { ShortcutRecorder(shortcut: $settings.customForward) }
                LabeledContent("Turn counter-clockwise") { ShortcutRecorder(shortcut: $settings.customBack) }
                LabeledContent("Press") { ShortcutRecorder(shortcut: $settings.customPress) }
            } header: {
                Text("Custom mode")
            } footer: {
                Text("Any shortcut, sent to the frontmost app once per click. Press uses this shortcut when its press action is Mode default. Esc cancels recording.")
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
                UpdateRow(updates: model.updates, automatic: $settings.checkForUpdates)
                HStack {
                    Spacer()
                    Button("Restore Defaults") { settings.restoreDefaults() }
                }
            }
        }
        .formStyle(.grouped)
        // The form scrolls inside a fixed height so the window fits a 1080p screen.
        .frame(width: 560, height: 720)
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

private struct UpdateRow: View {
    let updates: UpdateChecker
    @Binding var automatic: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Toggle("Check for updates daily", isOn: $automatic)
                Spacer()
                if let release = updates.available {
                    Button("Get \(release.version.description)…", action: updates.openReleasePage)
                }
                Button("Check Now", action: updates.check)
                    .disabled(updates.isChecking || updates.current == nil)
            }
            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var status: String {
        guard let current = updates.current else { return "Update checks need the bundled app (make app)" }
        if updates.isChecking { return "Checking…" }
        if let error = updates.lastError { return error }
        if let release = updates.available { return "Version \(release.version) is available (you have \(current))" }
        if updates.lastChecked != nil { return "Astra Dial \(current) is up to date" }
        return "Version \(current)"
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

private struct ProfileRow: View {
    let profile: AppProfile
    @Bindable var settings: DialSettings

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: AppInfo.icon(forBundleID: profile.bundleID))
                .resizable()
                .frame(width: 20, height: 20)
            Text(profile.name)
            Spacer()
            Picker("Mode", selection: mode) {
                ForEach(DialMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.symbol).tag(mode)
                }
            }
            .labelsHidden()
            .frame(width: 150)
            Button {
                settings.removeProfile(profile)
            } label: {
                Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Remove \(profile.name)")
        }
        .opacity(settings.enabledModes.contains(profile.mode) ? 1 : 0.5)
        .help(settings.enabledModes.contains(profile.mode) ? "" : "\(profile.mode.title) is turned off in Modes, so this profile is skipped")
    }

    private var mode: Binding<DialMode> {
        Binding(
            get: { profile.mode },
            set: { newMode in
                if let index = settings.appProfiles.firstIndex(where: { $0.bundleID == profile.bundleID }) {
                    settings.appProfiles[index].mode = newMode
                }
            }
        )
    }
}

private struct AddProfileMenu: View {
    @Bindable var settings: DialSettings

    var body: some View {
        Menu("Add App") {
            let apps = AppInfo.runningApps().filter { app in
                !settings.appProfiles.contains { $0.bundleID == app.bundleID }
            }
            Section("Running") {
                ForEach(apps, id: \.bundleID) { app in
                    Button {
                        settings.addProfile(bundleID: app.bundleID, name: app.name, mode: AppInfo.suggestedMode(forBundleID: app.bundleID))
                    } label: {
                        Text(app.name)
                    }
                }
            }
            Divider()
            Button("Choose from Applications…", action: chooseApp)
        }
        .fixedSize()
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url,
              let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else { return }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        settings.addProfile(bundleID: bundleID, name: name, mode: AppInfo.suggestedMode(forBundleID: bundleID))
    }
}

private enum AppInfo {
    struct App {
        let bundleID: String
        let name: String
    }

    /// Regular apps that are running now, excluding Astra Dial, sorted by name.
    static func runningApps() -> [App] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .compactMap { app in
                guard let bundleID = app.bundleIdentifier else { return nil }
                return App(bundleID: bundleID, name: app.localizedName ?? bundleID)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func icon(forBundleID bundleID: String) -> NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
    }

    /// A starting mode for well-known apps; anything else starts on Scroll.
    static func suggestedMode(forBundleID bundleID: String) -> DialMode {
        switch bundleID {
        case "com.apple.iWork.Keynote", "com.microsoft.Powerpoint": .slides
        case "com.apple.FinalCut", "com.colliderli.iina", "com.apple.QuickTimePlayerX",
             "org.videolan.vlc", "com.blackmagic-design.DaVinciResolve": .scrub
        case "com.figma.Desktop", "com.bohemiancoding.sketch3", "com.apple.Preview": .zoom
        case "com.apple.Safari", "com.google.Chrome", "company.thebrowser.Browser",
             "org.mozilla.firefox", "com.microsoft.edgemac": .tabs
        default: .scroll
        }
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
