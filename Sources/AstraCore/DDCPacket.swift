import Foundation

/// DDC/CI packets for reading and setting monitor controls (VCP codes) over I²C.
/// Layout and checksums follow the VESA DDC/CI spec as used by MonitorControl and m1ddc:
/// the host writes to address 0x37 with sub-address 0x51, and the checksum XORs the
/// destination (0x6E), the source (0x51, except for single-byte requests) and every byte.
public enum DDCPacket {
    public static let i2cAddress: UInt32 = 0x37
    public static let dataAddress: UInt32 = 0x51

    /// VCP 0x10: luminance (brightness).
    public static let brightness: UInt8 = 0x10

    /// "Set VCP feature" request.
    public static func set(_ code: UInt8, value: UInt16) -> [UInt8] {
        packet([code, UInt8(value >> 8), UInt8(value & 0xFF)])
    }

    /// "Get VCP feature" request. Send it, wait ~10 ms, then read `replyLength` bytes.
    public static func get(_ code: UInt8) -> [UInt8] {
        packet([code])
    }

    public static let replyLength = 11

    public struct Reply: Equatable, Sendable {
        public let current: UInt16
        public let maximum: UInt16
    }

    /// Parses a "Get VCP feature" reply. Returns nil for malformed replies, unsupported codes,
    /// or a bad checksum.
    public static func parseReply(_ bytes: [UInt8], for code: UInt8) -> Reply? {
        // [source 0x6E][0x88 length][0x02 opcode][result][code][type][max hi][max lo][cur hi][cur lo][checksum]
        guard bytes.count >= replyLength,
              bytes[2] == 0x02,          // VCP feature reply
              bytes[3] == 0x00,          // result: no error
              bytes[4] == code else { return nil }
        let checksum = bytes[0..<10].reduce(UInt8(0x50), ^)
        guard checksum == bytes[10] else { return nil }
        let maximum = UInt16(bytes[6]) << 8 | UInt16(bytes[7])
        let current = UInt16(bytes[8]) << 8 | UInt16(bytes[9])
        guard maximum > 0 else { return nil }
        return Reply(current: current, maximum: maximum)
    }

    private static func packet(_ payload: [UInt8]) -> [UInt8] {
        var bytes = [UInt8(0x80 | (payload.count + 1)), UInt8(payload.count)] + payload
        let seed: UInt8 = payload.count == 1 ? 0x6E : 0x6E ^ 0x51
        bytes.append(bytes.reduce(seed, ^))
        return bytes
    }
}
