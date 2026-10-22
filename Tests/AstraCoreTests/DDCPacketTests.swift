import Testing
@testable import AstraCore

@Suite struct DDCPacketTests {
    @Test func setBrightnessPacket() {
        // 0x6E ^ 0x51 ^ 0x84 ^ 0x03 ^ 0x10 ^ 0x00 ^ 0x32 == 0x9A
        #expect(DDCPacket.set(DDCPacket.brightness, value: 50) == [0x84, 0x03, 0x10, 0x00, 0x32, 0x9A])
    }

    @Test func getBrightnessPacket() {
        // Single-byte requests seed the checksum with 0x6E only: 0x6E ^ 0x82 ^ 0x01 ^ 0x10 == 0xFD
        #expect(DDCPacket.get(DDCPacket.brightness) == [0x82, 0x01, 0x10, 0xFD])
    }

    @Test func parsesBrightnessReply() {
        // max 100, current 50; checksum 0x50 ^ bytes[0..<10] == 0xF2
        let reply: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x10, 0x00, 0x00, 0x64, 0x00, 0x32, 0xF2]
        #expect(DDCPacket.parseReply(reply, for: DDCPacket.brightness) == .init(current: 50, maximum: 100))
    }

    @Test func rejectsBadChecksum() {
        let reply: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x10, 0x00, 0x00, 0x64, 0x00, 0x32, 0x00]
        #expect(DDCPacket.parseReply(reply, for: DDCPacket.brightness) == nil)
    }

    @Test func rejectsUnsupportedCodeAndShortReplies() {
        let unsupported: [UInt8] = [0x6E, 0x88, 0x02, 0x01, 0x10, 0x00, 0x00, 0x64, 0x00, 0x32, 0xF3]
        #expect(DDCPacket.parseReply(unsupported, for: DDCPacket.brightness) == nil)
        #expect(DDCPacket.parseReply([0x6E, 0x88], for: DDCPacket.brightness) == nil)
    }

    @Test func rejectsReplyForDifferentCode() {
        let reply: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x10, 0x00, 0x00, 0x64, 0x00, 0x32, 0xF2]
        #expect(DDCPacket.parseReply(reply, for: 0x12) == nil)
    }
}
