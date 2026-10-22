import CoreGraphics

enum ScrollSender {
    /// Scrolls whatever is under the pointer. Positive scrolls content down (like a wheel moved toward you).
    static func scroll(pixels: Int32) {
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                                  wheelCount: 1, wheel1: -pixels, wheel2: 0, wheel3: 0) else { return }
        event.post(tap: .cghidEventTap)
    }
}
