import Foundation
import IOKit

// DDC/CI goes through IOAVService, a private API, so the App Store build leaves it out and
// gets the stub at the end of this file instead.
#if !APP_STORE

// Private IOKit calls for I²C over DisplayPort/HDMI on Apple Silicon (DCP). They're exported
// by IOKit.framework and used by MonitorControl and m1ddc; there's no public equivalent.
@_silgen_name("IOAVServiceCreateWithService")
private func IOAVServiceCreateWithService(_ allocator: CFAllocator?, _ service: io_service_t) -> Unmanaged<CFTypeRef>?

@_silgen_name("IOAVServiceReadI2C")
private func IOAVServiceReadI2C(_ service: CFTypeRef, _ chipAddress: UInt32, _ offset: UInt32,
                                _ buffer: UnsafeMutableRawPointer, _ size: UInt32) -> IOReturn

@_silgen_name("IOAVServiceWriteI2C")
private func IOAVServiceWriteI2C(_ service: CFTypeRef, _ chipAddress: UInt32, _ dataAddress: UInt32,
                                 _ buffer: UnsafeMutableRawPointer, _ size: UInt32) -> IOReturn

/// An external monitor reachable over DDC/CI. Calls block for tens of milliseconds;
/// keep them off the main thread.
public final class DDCDisplay: @unchecked Sendable {
    public let name: String
    private let service: CFTypeRef

    private init(name: String, service: CFTypeRef) {
        self.name = name
        self.service = service
    }

    /// External displays with an AV service. Not every one answers DDC; check `read`.
    public static func all() -> [DDCDisplay] {
        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceNameMatching("DCPAVServiceProxy"), &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var displays: [DDCDisplay] = []
        var index = 1
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            let location = IORegistryEntryCreateCFProperty(entry, "Location" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? String
            guard location == "External",
                  let service = IOAVServiceCreateWithService(kCFAllocatorDefault, entry)?.takeRetainedValue() else { continue }
            displays.append(DDCDisplay(name: "External display \(index)", service: service))
            index += 1
        }
        return displays
    }

    /// Reads a VCP value, retrying a few times because monitors often miss the first request.
    public func read(_ code: UInt8, attempts: Int = 3) -> DDCPacket.Reply? {
        for _ in 0..<attempts {
            var request = DDCPacket.get(code)
            guard write(&request) else { usleep(20_000); continue }
            usleep(15_000)
            var reply = [UInt8](repeating: 0, count: DDCPacket.replyLength)
            let result = reply.withUnsafeMutableBytes {
                IOAVServiceReadI2C(service, DDCPacket.i2cAddress, DDCPacket.dataAddress, $0.baseAddress!, UInt32($0.count))
            }
            if result == kIOReturnSuccess, let parsed = DDCPacket.parseReply(reply, for: code) { return parsed }
            usleep(20_000)
        }
        return nil
    }

    /// One unparsed request/reply exchange, for diagnosing monitors that don't answer.
    public func readRaw(_ code: UInt8) -> (write: IOReturn, read: IOReturn, bytes: [UInt8]) {
        var request = DDCPacket.get(code)
        let writeResult = request.withUnsafeMutableBytes {
            IOAVServiceWriteI2C(service, DDCPacket.i2cAddress, DDCPacket.dataAddress, $0.baseAddress!, UInt32($0.count))
        }
        usleep(15_000)
        var reply = [UInt8](repeating: 0, count: DDCPacket.replyLength)
        let readResult = reply.withUnsafeMutableBytes {
            IOAVServiceReadI2C(service, DDCPacket.i2cAddress, DDCPacket.dataAddress, $0.baseAddress!, UInt32($0.count))
        }
        return (writeResult, readResult, reply)
    }

    /// Sets a VCP value. Returns false if the write failed.
    @discardableResult
    public func set(_ code: UInt8, value: UInt16) -> Bool {
        var request = DDCPacket.set(code, value: value)
        // Writes are sent twice: some monitors drop single writes, and repeating is harmless.
        let first = write(&request)
        usleep(10_000)
        let second = write(&request)
        return first || second
    }

    private func write(_ bytes: inout [UInt8]) -> Bool {
        bytes.withUnsafeMutableBytes {
            IOAVServiceWriteI2C(service, DDCPacket.i2cAddress, DDCPacket.dataAddress, $0.baseAddress!, UInt32($0.count))
        } == kIOReturnSuccess
    }
}

#else

/// The App Store build's stand-in: no displays, so Brightness mode has nothing to drive.
public final class DDCDisplay: @unchecked Sendable {
    public let name = ""

    public static func all() -> [DDCDisplay] { [] }
    public func read(_ code: UInt8, attempts: Int = 3) -> DDCPacket.Reply? { nil }
    public func readRaw(_ code: UInt8) -> (write: IOReturn, read: IOReturn, bytes: [UInt8]) { (kIOReturnUnsupported, kIOReturnUnsupported, []) }
    public func set(_ code: UInt8, value: UInt16) -> Bool { false }
}
#endif
