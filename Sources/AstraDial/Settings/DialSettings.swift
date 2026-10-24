import AstraCore
import Foundation
import Observation

/// A mode chosen automatically while an app is frontmost.
struct AppProfile: Codable, Hashable, Identifiable {
    let bundleID: String
    let name: String
    var mode: DialMode

    var id: String { bundleID }
}

/// User settings, saved to UserDefaults as one JSON blob on every change.
@Observable
final class DialSettings {
    /// Every mode, in the user's wheel order. Hidden modes keep their place.
    var modeOrder: [DialMode] = DialMode.allCases { didSet { changed() } }
    var disabledModes: Set<DialMode> = DialSettings.offByDefault { didSet { changed() } }
    var pressActions: [DialMode: PressAction] = [:] { didSet { changed() } }

    /// Pixels scrolled per detent before acceleration.
    var scrollSpeed: Double = 48 { didSet { changed() } }
    var spinAcceleration = true { didSet { changed() } }
    /// Brightness change per detent, in percent.
    var brightnessStep: Double = 5 { didSet { changed() } }
    var doublePressWindow: Double = 0.3 { didSet { changed() } }
    var longPressDuration: Double = 0.6 { didSet { changed() } }
    var wheelTimeout: Double = 5 { didSet { changed() } }

    /// Switch modes automatically when a profiled app comes to the front.
    var autoProfiles = true { didSet { changed() } }
    var appProfiles: [AppProfile] = [] { didSet { changed() } }

    /// Custom mode's shortcuts: clockwise, counter-clockwise, and its default press.
    var customForward: KeyShortcut? { didSet { changed() } }
    var customBack: KeyShortcut? { didSet { changed() } }
    var customPress: KeyShortcut? { didSet { changed() } }

    /// Look for a newer release on GitHub once a day.
    var checkForUpdates = true { didSet { changed() } }

    /// Called after any change has been saved.
    @ObservationIgnored var onChange: (() -> Void)?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isLoading = false
    private static let key = "settings"
    /// Custom does nothing until its shortcuts are recorded, so it starts off the wheel.
    static let offByDefault: Set<DialMode> = [.custom]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    /// The wheel's modes. Volume is always included: long-press falls back to it.
    var enabledModes: [DialMode] {
        modeOrder.filter { $0 == .volume || !disabledModes.contains($0) }
    }

    func pressAction(for mode: DialMode) -> PressAction {
        pressActions[mode] ?? .modeDefault
    }

    /// The profile mode for an app, if it has one and that mode is on the wheel.
    func profileMode(forBundleID bundleID: String) -> DialMode? {
        guard autoProfiles, let profile = appProfiles.first(where: { $0.bundleID == bundleID }),
              enabledModes.contains(profile.mode) else { return nil }
        return profile.mode
    }

    func addProfile(bundleID: String, name: String, mode: DialMode) {
        guard !appProfiles.contains(where: { $0.bundleID == bundleID }) else { return }
        appProfiles.append(AppProfile(bundleID: bundleID, name: name, mode: mode))
    }

    func removeProfile(_ profile: AppProfile) {
        appProfiles.removeAll { $0.bundleID == profile.bundleID }
    }

    func moveModes(from source: IndexSet, to destination: Int) {
        modeOrder.move(fromOffsets: source, toOffset: destination)
    }

    func restoreDefaults() {
        apply(Stored())
        changed()
    }

    // MARK: Persistence

    /// Every field falls back to its default when missing, so settings saved by an older
    /// build still load after new fields are added.
    private struct Stored: Codable {
        var modeOrder: [String] = DialMode.allCases.map(\.rawValue)
        var disabledModes: [String] = DialSettings.offByDefault.map(\.rawValue)
        var pressActions: [String: String] = [:]
        var scrollSpeed: Double = 48
        var spinAcceleration = true
        var brightnessStep: Double = 5
        var doublePressWindow: Double = 0.3
        var longPressDuration: Double = 0.6
        var wheelTimeout: Double = 5
        var autoProfiles = true
        var appProfiles: [AppProfile] = []
        var customForward: KeyShortcut?
        var customBack: KeyShortcut?
        var customPress: KeyShortcut?
        var checkForUpdates = true

        init() {}

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = Stored()
            modeOrder = try c.decodeIfPresent([String].self, forKey: .modeOrder) ?? d.modeOrder
            disabledModes = try c.decodeIfPresent([String].self, forKey: .disabledModes) ?? d.disabledModes
            pressActions = try c.decodeIfPresent([String: String].self, forKey: .pressActions) ?? d.pressActions
            scrollSpeed = try c.decodeIfPresent(Double.self, forKey: .scrollSpeed) ?? d.scrollSpeed
            spinAcceleration = try c.decodeIfPresent(Bool.self, forKey: .spinAcceleration) ?? d.spinAcceleration
            brightnessStep = try c.decodeIfPresent(Double.self, forKey: .brightnessStep) ?? d.brightnessStep
            doublePressWindow = try c.decodeIfPresent(Double.self, forKey: .doublePressWindow) ?? d.doublePressWindow
            longPressDuration = try c.decodeIfPresent(Double.self, forKey: .longPressDuration) ?? d.longPressDuration
            wheelTimeout = try c.decodeIfPresent(Double.self, forKey: .wheelTimeout) ?? d.wheelTimeout
            autoProfiles = try c.decodeIfPresent(Bool.self, forKey: .autoProfiles) ?? d.autoProfiles
            // A profile naming a mode this build doesn't know is dropped rather than failing the load.
            appProfiles = (try? c.decodeIfPresent([FailableProfile].self, forKey: .appProfiles))?
                .compactMap(\.profile) ?? d.appProfiles
            customForward = try? c.decodeIfPresent(KeyShortcut.self, forKey: .customForward)
            customBack = try? c.decodeIfPresent(KeyShortcut.self, forKey: .customBack)
            customPress = try? c.decodeIfPresent(KeyShortcut.self, forKey: .customPress)
            checkForUpdates = try c.decodeIfPresent(Bool.self, forKey: .checkForUpdates) ?? d.checkForUpdates
        }
    }

    private struct FailableProfile: Decodable {
        let profile: AppProfile?
        init(from decoder: Decoder) throws { profile = try? AppProfile(from: decoder) }
    }

    private func changed() {
        guard !isLoading else { return }
        var stored = Stored()
        stored.modeOrder = modeOrder.map(\.rawValue)
        stored.disabledModes = disabledModes.map(\.rawValue).sorted()
        stored.pressActions = Dictionary(uniqueKeysWithValues: pressActions.map { ($0.key.rawValue, $0.value.rawValue) })
        stored.scrollSpeed = scrollSpeed
        stored.spinAcceleration = spinAcceleration
        stored.brightnessStep = brightnessStep
        stored.doublePressWindow = doublePressWindow
        stored.longPressDuration = longPressDuration
        stored.wheelTimeout = wheelTimeout
        stored.autoProfiles = autoProfiles
        stored.appProfiles = appProfiles
        stored.customForward = customForward
        stored.customBack = customBack
        stored.customPress = customPress
        stored.checkForUpdates = checkForUpdates
        if let data = try? JSONEncoder().encode(stored) { defaults.set(data, forKey: Self.key) }
        onChange?()
    }

    private func load() {
        guard let data = defaults.data(forKey: Self.key),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else { return }
        apply(stored)
    }

    private func apply(_ stored: Stored) {
        isLoading = true
        defer { isLoading = false }
        // Unknown modes are dropped; modes added in later versions go at the end.
        var order = stored.modeOrder.compactMap(DialMode.init(rawValue:))
        let added = DialMode.allCases.filter { !order.contains($0) }
        order += added
        modeOrder = order
        disabledModes = Set(stored.disabledModes.compactMap(DialMode.init(rawValue:)))
            .union(DialSettings.offByDefault.intersection(added))
        pressActions = Dictionary(uniqueKeysWithValues: stored.pressActions.compactMap { key, value in
            guard let mode = DialMode(rawValue: key), let action = PressAction(rawValue: value) else { return nil }
            return (mode, action)
        })
        scrollSpeed = stored.scrollSpeed
        spinAcceleration = stored.spinAcceleration
        brightnessStep = stored.brightnessStep
        doublePressWindow = stored.doublePressWindow
        longPressDuration = stored.longPressDuration
        wheelTimeout = stored.wheelTimeout
        autoProfiles = stored.autoProfiles
        appProfiles = stored.appProfiles
        customForward = stored.customForward
        customBack = stored.customBack
        customPress = stored.customPress
        checkForUpdates = stored.checkForUpdates
    }
}
