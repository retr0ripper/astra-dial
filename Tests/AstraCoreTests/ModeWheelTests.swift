import Testing
@testable import AstraCore

@Suite struct ModeWheelTests {
    @Test func opensOnCurrentSlot() {
        var wheel = ModeWheel(slotCount: 8)
        wheel.open(at: 3)
        #expect(wheel.isOpen)
        #expect(wheel.highlighted == 3)
    }

    @Test func turnsWrapBothWays() {
        var wheel = ModeWheel(slotCount: 8)
        wheel.open(at: 7)
        wheel.turn(1)
        #expect(wheel.highlighted == 0)
        wheel.turn(-1)
        wheel.turn(-1)
        #expect(wheel.highlighted == 6)
        wheel.turn(-15)
        #expect(wheel.highlighted == 7)
    }

    @Test func selectReturnsHighlightAndCloses() {
        var wheel = ModeWheel(slotCount: 8)
        wheel.open(at: 0)
        wheel.turn(2)
        #expect(wheel.select() == 2)
        #expect(!wheel.isOpen)
        #expect(wheel.select() == nil)
    }

    @Test func closedWheelIgnoresTurns() {
        var wheel = ModeWheel(slotCount: 8)
        wheel.turn(3)
        #expect(wheel.highlighted == 0)
    }

    @Test func cancelClosesWithoutSelecting() {
        var wheel = ModeWheel(slotCount: 8)
        wheel.open(at: 1)
        wheel.cancel()
        #expect(!wheel.isOpen)
        #expect(wheel.select() == nil)
    }

    @Test func openingWithOutOfRangeSlotWraps() {
        var wheel = ModeWheel(slotCount: 4)
        wheel.open(at: 5)
        #expect(wheel.highlighted == 1)
    }
}
