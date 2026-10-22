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

/// App state for the menu bar shell. This milestone only observes the knob;
/// it doesn't block volume or run modes yet.
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

    // Live knob readout
    private(set) var position = 0
    private(set) var isPressed = false
    private(set) var pressCount = 0
    private(set) var log: [KnobLogLine] = []

    private(set) var launchAtLogin = false

    private let monitor = HIDMonitor()
    private var decoder = KnobDecoder()
    private var permissionTimer: Timer?

    struct PairedDevice: Codable, Hashable, Identifiable {
        let id: DeviceID
        let name: String
        let transport: String
    }

    private static let pairedKey = "pairedDevices"

    init() {
        loadPairedDevices()
        refreshPermissions()
        refreshLaunchAtLogin()
        monitor.onEvent = { [weak self] in self?.handle($0) }
        monitor.onDevicesChanged = { [weak self] in self?.refreshConnected() }
        startMonitor()
        if pairedDevices.isEmpty { isPairing = true }

        // Permissions change in System Settings with no callback, so poll cheaply.
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.permissionTick()
        }
    }

    var isConnected: Bool { pairedDevices.contains { connectedDeviceIDs.contains($0.id) } }

    var menuBarSymbol: String {
        if inputMonitoring != .granted { return "dial.low" }
        return isConnected ? "dial.high" : "dial.medium"
    }

    var statusText: String {
        if inputMonitoring != .granted { return "Needs Input Monitoring" }
        if isPairing { return "Turn the knob to pair" }
        if pairedDevices.isEmpty { return "No keyboard paired" }
        return isConnected ? "Knob connected" : "Keyboard not connected"
    }

    // MARK: Actions

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
        isPairing = true
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
        switch signal {
        case .turn(let step):
            position += step
            append("\(step > 0 ? "Turn ⟳" : "Turn ⟲")  \(event.usageName)")
        case .pressDown:
            isPressed = true
            pressCount += 1
            append("Press ↓  \(event.usageName)")
        case .pressUp:
            isPressed = false
            append("Press ↑")
        }
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

    private func permissionTick() {
        let before = inputMonitoring
        refreshPermissions()
        if before != .granted, inputMonitoring == .granted { startMonitor() }
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
