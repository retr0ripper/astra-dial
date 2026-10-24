import AppKit
import AstraCore
import Foundation
import IOKit
import Observation
import ServiceManagement

struct KnobLogLine: Identifiable {
    let id = UUID()
    let date = Date()
    let text: String
}

/// App state: permissions, pairing, and the knob pipeline
/// (HIDMonitor → KnobDecoder → GestureRecognizer → DialEngine, with MediaKeyTap taking
/// the knob's volume events away from macOS when the mode needs them).
@Observable
final class AppModel {
    // Permissions
    private(set) var inputMonitoring: InputMonitoringAccess = .unknown
    private(set) var accessibilityTrusted = false
    private(set) var monitorError: String?

    // Pairing
    private(set) var pairedDevices: [PairedDevice] = []
    private(set) var isPairing = false
    private(set) var connectedDeviceIDs: Set<DeviceID> = []

    // Knob control
    private(set) var mode: DialMode = .volume
    private(set) var isTakeoverActive = false
    var takeoverEnabled = UserDefaults.standard.object(forKey: AppModel.takeoverKey) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(takeoverEnabled, forKey: Self.takeoverKey)
            if !takeoverEnabled { engine.reset() }
            refreshTakeover()
        }
    }

    // Live knob readout
    private(set) var position = 0
    private(set) var isPressed = false
    private(set) var log: [KnobLogLine] = []

    private(set) var launchAtLogin = false

    private let monitor = HIDMonitor()
    private var decoder = KnobDecoder()
    private var recognizer = GestureRecognizer()
    let settings: DialSettings
    let updates = UpdateChecker()
    private let runner: ModeRunner
    private let engine: DialEngine
    private let settingsWindow = SettingsWindowController()
    private let mediaKeyTap = MediaKeyTap()
    private let hud = WheelHUD()
    private var gestureTimer: Timer?
    private var permissionTimer: Timer?
    /// Whether `updates` is set to check daily, so unrelated settings changes don't re-check.
    private var updatesAutomatic: Bool?

    struct PairedDevice: Codable, Hashable, Identifiable {
        let id: DeviceID
        let name: String
        let transport: String
    }

    private static let pairedKey = "pairedDevices"
    private static let takeoverKey = "takeoverEnabled"

    var brightness: BrightnessController { runner.brightness }

    init() {
        settings = DialSettings()
        runner = ModeRunner(settings: settings)
        engine = DialEngine(settings: settings, runner: runner)
        loadPairedDevices()
        refreshPermissions()
        refreshLaunchAtLogin()

        monitor.onEvent = { [weak self] in self?.handle($0) }
        monitor.onDevicesChanged = { [weak self] in self?.refreshConnected() }
        engine.onModeChange = { [weak self] in self?.mode = $0 }
        engine.onWheelChange = { [weak self] wheel in
            guard let self else { return }
            hud.update(wheel: wheel, modes: engine.wheelModes, activeMode: engine.mode)
        }
        engine.onModeChosen = { [weak self] in self?.hud.showToast($0) }
        engine.onAutoMode = { [weak self] mode, appName in
            guard let self else { return }
            hud.showToast(mode)
            append("\(appName) → \(settings.title(for: mode)) mode (profile)")
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self, isTakeoverActive,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier else { return }
            engine.appDidActivate(bundleID: bundleID, name: app.localizedName ?? bundleID)
        }
        runner.onLevel = { [weak self] mode, level in self?.hud.showToast(mode, level: level) }
        settings.onChange = { [weak self] in self?.applySettings() }
        applySettings()
        mediaKeyTap.shouldClaim = { [weak self] key in
            guard let self, isTakeoverActive, !isPairing else { return false }
            // The press is always ours, so double- and long-press never toggle mute.
            // Volume mode re-posts mute itself on a single press.
            return key.isKnobKey && (key == .mute || engine.claimsTurns)
        }

        startMonitor()
        refreshTakeover()
        if pairedDevices.isEmpty { isPairing = true }

        // Permissions change in System Settings with no callback, so poll cheaply.
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.permissionTick()
        }
    }

    var isConnected: Bool { pairedDevices.contains { connectedDeviceIDs.contains($0.id) } }

    var menuBarSymbol: String {
        if inputMonitoring != .granted { return "dial.low" }
        if isTakeoverActive, isConnected { return mode.symbol }
        return isConnected ? "dial.high" : "dial.medium"
    }

    var statusText: String {
        if inputMonitoring != .granted { return "Needs Input Monitoring" }
        if isPairing { return "Turn the knob to pair" }
        if pairedDevices.isEmpty { return "No keyboard paired" }
        if !isConnected { return "Keyboard not connected" }
        if !takeoverEnabled { return "Knob connected · controls volume only" }
        if !isTakeoverActive { return "Knob connected · needs Accessibility for modes" }
        return "\(settings.title(for: mode)) mode · double-press for the wheel"
    }

    // MARK: Actions

    /// What a press does in the active mode, following Settings.
    var pressHint: String { runner.pressHint(mode) }

    /// What a turn does in the active mode.
    var turnHint: String { runner.turnHint(mode) }

    func openSettings() {
        settingsWindow.show(model: self)
    }

    func selectMode(_ newMode: DialMode) {
        guard isTakeoverActive else { return }
        engine.userChose(newMode)
        append("Switched to \(settings.title(for: newMode)) mode")
    }

    func startPairing() {
        isPairing = true
        append("Pairing: turn the knob on the keyboard you want to use")
    }

    func cancelPairing() {
        isPairing = false
    }

    func forgetDevices() {
        pairedDevices = []
        savePairedDevices()
        decoder.devices = []
        engine.reset()
        isPairing = true
        refreshTakeover()
        append("Forgot paired keyboards")
    }

    func requestInputMonitoring() {
        if inputMonitoring == .unknown {
            InputMonitoringAccess.request()
        } else {
            openPrivacyPane("Privacy_ListenEvent")
        }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            openPrivacyPane("Privacy_Accessibility")
        }
    }

    var canLaunchAtLogin: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard canLaunchAtLogin else { return }
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            append("Launch at login failed: \(error.localizedDescription)")
        }
        refreshLaunchAtLogin()
    }

    // MARK: Input

    private func handle(_ event: HIDEvent) {
        if isPairing, KnobDecoder.isPairingCandidate(event) {
            pair(with: event)
            return
        }

        guard !pairedDevices.isEmpty, let signal = decoder.decode(event) else { return }

        if event.usagePage == HIDUsage.consumerPage, let key = MediaKey(hidUsage: event.usage) {
            mediaKeyTap.recordKnob(key, isDown: event.value != 0)
        }

        switch signal {
        case .turn(let step): position += step
        case .pressDown: isPressed = true
        case .pressUp: isPressed = false
        }

        perform(recognizer.handle(signal, at: ProcessInfo.processInfo.systemUptime))
        scheduleGestureTick()
    }

    private func perform(_ gestures: [KnobGesture]) {
        for gesture in gestures {
            if isTakeoverActive {
                append(engine.perform(gesture))
            } else {
                append("\(gesture.logName) (modes off: knob controls volume)")
            }
        }
    }

    /// Fires the recognizer's timed gestures (single press, long press) with no further input.
    private func scheduleGestureTick() {
        gestureTimer?.invalidate()
        gestureTimer = nil
        guard let deadline = recognizer.nextDeadline else { return }
        let delay = max(0, deadline - ProcessInfo.processInfo.systemUptime)
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            perform(recognizer.tick(at: ProcessInfo.processInfo.systemUptime))
            scheduleGestureTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        gestureTimer = timer
    }

    private func pair(with event: HIDEvent) {
        let device = PairedDevice(id: event.device, name: event.productName, transport: event.transport)
        if !pairedDevices.contains(where: { $0.id == device.id }) {
            pairedDevices.append(device)
            savePairedDevices()
        }
        decoder.devices = Set(pairedDevices.map(\.id))
        isPairing = false
        refreshConnected()
        refreshTakeover()
        append("Paired \(device.name) \(device.id) over \(device.transport.isEmpty ? "unknown transport" : device.transport)")
    }

    private func startMonitor() {
        let result = monitor.start()
        if result == kIOReturnSuccess {
            monitorError = nil
            refreshConnected()
        } else if result == kIOReturnNotPermitted {
            monitorError = nil
        } else {
            monitorError = "Couldn't open HID devices (0x\(String(UInt32(bitPattern: result), radix: 16)))"
        }
    }

    /// Runs the event tap only when it can do something: modes on, a keyboard paired,
    /// and Accessibility granted (tap creation fails without it).
    private func refreshTakeover() {
        let wanted = takeoverEnabled && !pairedDevices.isEmpty && accessibilityTrusted
        if wanted, !mediaKeyTap.isRunning {
            if !mediaKeyTap.start() { append("Couldn't start the media-key tap. Check Accessibility.") }
        } else if !wanted, mediaKeyTap.isRunning {
            mediaKeyTap.stop()
        }
        isTakeoverActive = mediaKeyTap.isRunning
        if !isTakeoverActive {
            engine.reset()
        }
    }

    private func applySettings() {
        hud.state.titles = Dictionary(uniqueKeysWithValues: DialMode.allCases.map { ($0, settings.title(for: $0)) })
        if settings.checkForUpdates != updatesAutomatic {
            updatesAutomatic = settings.checkForUpdates
            updates.setAutomatic(settings.checkForUpdates)
        }
        recognizer.doublePressWindow = settings.doublePressWindow
        recognizer.longPressDuration = settings.longPressDuration
        engine.settingsDidChange()
    }

    private func permissionTick() {
        let before = (inputMonitoring, accessibilityTrusted)
        refreshPermissions()
        if before.0 != .granted, inputMonitoring == .granted { startMonitor() }
        if before.1 != accessibilityTrusted || mediaKeyTap.isRunning != isTakeoverActive { refreshTakeover() }
    }

    private func refreshPermissions() {
        inputMonitoring = InputMonitoringAccess.current
        accessibilityTrusted = AXIsProcessTrusted()
    }

    private func refreshConnected() {
        connectedDeviceIDs = Set(monitor.devices.map(\.id))
    }

    private func refreshLaunchAtLogin() {
        launchAtLogin = canLaunchAtLogin && SMAppService.mainApp.status == .enabled
    }

    private func append(_ text: String) {
        log.append(KnobLogLine(text: text))
        if log.count > 50 { log.removeFirst(log.count - 50) }
    }

    private func openPrivacyPane(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Persistence

    private func loadPairedDevices() {
        guard let data = UserDefaults.standard.data(forKey: Self.pairedKey),
              let devices = try? JSONDecoder().decode([PairedDevice].self, from: data) else { return }
        pairedDevices = devices
        decoder.devices = Set(devices.map(\.id))
    }

    private func savePairedDevices() {
        if let data = try? JSONEncoder().encode(pairedDevices) {
            UserDefaults.standard.set(data, forKey: Self.pairedKey)
        }
    }
}

private extension KnobGesture {
    var logName: String {
        switch self {
        case .turn(let direction, _): direction > 0 ? "Turn ⟳" : "Turn ⟲"
        case .press: "Press"
        case .doublePress: "Double-press"
        case .longPress: "Long-press"
        }
    }
}
