import Foundation

/// Selection state for the mode wheel: which slot is highlighted while it's open.
/// Knows nothing about what the modes are; slots are indexes into the app's mode list.
public struct ModeWheel: Equatable, Sendable {
    public let slotCount: Int
    public private(set) var isOpen = false
    public private(set) var highlighted = 0

    public init(slotCount: Int) {
        precondition(slotCount > 0, "a wheel needs at least one slot")
        self.slotCount = slotCount
    }

    /// Opens with the current mode highlighted.
    public mutating func open(at current: Int) {
        isOpen = true
        highlighted = Self.wrap(current, slotCount)
    }

    /// Moves the highlight one slot per detent, wrapping around the ring.
    public mutating func turn(_ steps: Int) {
        guard isOpen else { return }
        highlighted = Self.wrap(highlighted + steps, slotCount)
    }

    /// Closes and returns the highlighted slot.
    public mutating func select() -> Int? {
        guard isOpen else { return nil }
        isOpen = false
        return highlighted
    }

    public mutating func cancel() {
        isOpen = false
    }

    private static func wrap(_ value: Int, _ count: Int) -> Int {
        ((value % count) + count) % count
    }
}
