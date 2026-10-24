import Foundation

/// Runs `body` with its own UserDefaults suite, removed afterwards.
func withDefaults<T>(_ body: (UserDefaults) throws -> T) rethrows -> T {
    let name = "AstraDialTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    return try body(defaults)
}
