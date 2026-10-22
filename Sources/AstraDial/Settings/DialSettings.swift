import Foundation
import Observation

/// User settings, saved to UserDefaults as one JSON blob on every change.
@Observable
final class DialSettings {
    /// Every mode, in the user's wheel order. Hidden modes keep their place.
    var modeOrder: [DialMode] = DialMode.allCases { didSet { changed() } }
    var disabledModes: Set<DialMode> = [] { didSet { changed() } }
    var pressActions: [DialMode: PressAction] = [:] { didSet { changed() } }

    /// Pixels scrolled per detent before acceleration.
    var scrollSpeed: Double = 48 { didSet { changed() } }
    var spinAcceleration = true { didSet { changed() } }
    /// Brightness change per detent, in percent.
    var brightnessStep: Double = 5 { didSet { changed() } }
    var doublePressWindow: Double = 0.3 { didSet { changed() } }
    var longPressDuration: Double = 0.6 { didSet { changed() } }
    var wheelTimeout: Double = 5 { didSet { changed() } }

    /// Called after any change has been saved.
    @ObservationIgnored var onChange: (() -> Void)?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isLoading = false
    private static let key = "settings"

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

    func moveModes(from source: IndexSet, to destination: Int) {
        modeOrder.move(fromOffsets: source, toOffset: destination)
    }

    func restoreDefaults() {
        apply(Stored())
        changed()
    }

    // MARK: Persistence

    private struct Stored: Codable {
        var modeOrder: [String] = DialMode.allCases.map(\.rawValue)
        var disabledModes: [String] = []
        var pressActions: [String: String] = [:]
        var scrollSpeed: Double = 48
        var spinAcceleration = true
        var brightnessStep: Double = 5
        var doublePressWindow: Double = 0.3
        var longPressDuration: Double = 0.6
        var wheelTimeout: Double = 5
    }

    private func changed() {
        guard !isLoading else { return }
        let stored = Stored(
            modeOrder: modeOrder.map(\.rawValue),
            disabledModes: disabledModes.map(\.rawValue).sorted(),
            pressActions: Dictionary(uniqueKeysWithValues: pressActions.map { ($0.key.rawValue, $0.value.rawValue) }),
            scrollSpeed: scrollSpeed,
            spinAcceleration: spinAcceleration,
            brightnessStep: brightnessStep,
            doublePressWindow: doublePressWindow,
            longPressDuration: longPressDuration,
            wheelTimeout: wheelTimeout
        )
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
        order += DialMode.allCases.filter { !order.contains($0) }
        modeOrder = order
        disabledModes = Set(stored.disabledModes.compactMap(DialMode.init(rawValue:)))
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
    }
}
