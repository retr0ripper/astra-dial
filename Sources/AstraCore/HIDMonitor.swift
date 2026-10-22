import Foundation
import IOKit
import IOKit.hid

public struct HIDDeviceInfo: Hashable, Sendable {
    public let id: DeviceID
    public let productName: String
    public let manufacturer: String
    public let transport: String
    public let primaryUsagePage: Int
    public let primaryUsage: Int
}

/// Watches keyboards and consumer-control devices through IOHIDManager and reports
/// every input value. Callbacks run on the main run loop.
public final class HIDMonitor {
    public var onEvent: ((HIDEvent) -> Void)?
    public var onDevicesChanged: (() -> Void)?

    private let manager: IOHIDManager
    private var isOpen = false
    private var deduplicator = EventDeduplicator()

    public init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [[String: Int]] = [
            [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard],
            [kIOHIDDeviceUsagePageKey: kHIDPage_Consumer, kIOHIDDeviceUsageKey: kHIDUsage_Csmr_ConsumerControl],
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)
    }

    deinit { stop() }

    /// Opens the manager. Returns `kIOReturnNotPermitted` when Input Monitoring hasn't been granted.
    @discardableResult
    public func start() -> IOReturn {
        guard !isOpen else { return kIOReturnSuccess }
        let context = Unmanaged.passUnretained(self).toOpaque()

        IOHIDManagerRegisterInputValueCallback(manager, { context, _, _, value in
            guard let context else { return }
            Unmanaged<HIDMonitor>.fromOpaque(context).takeUnretainedValue().handle(value)
        }, context)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, _ in
            guard let context else { return }
            Unmanaged<HIDMonitor>.fromOpaque(context).takeUnretainedValue().onDevicesChanged?()
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, _ in
            guard let context else { return }
            Unmanaged<HIDMonitor>.fromOpaque(context).takeUnretainedValue().onDevicesChanged?()
        }, context)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if result == kIOReturnSuccess {
            isOpen = true
        } else {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        }
        return result
    }

    public func stop() {
        guard isOpen else { return }
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        isOpen = false
    }

    public var devices: [HIDDeviceInfo] {
        guard let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return [] }
        return set.map(Self.info(for:)).sorted { $0.productName < $1.productName }
    }

    private func handle(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let page = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        // Skip the report-level and out-of-range array elements IOKit also delivers.
        guard usage != 0, usage < 0xFFFF else { return }

        let info = Self.info(for: IOHIDElementGetDevice(element))
        let event = HIDEvent(
            device: info.id,
            productName: info.productName,
            transport: info.transport,
            usagePage: page,
            usage: usage,
            value: IOHIDValueGetIntegerValue(value),
            timestamp: IOHIDValueGetTimeStamp(value)
        )
        guard deduplicator.accept(event) else { return }
        onEvent?(event)
    }

    private static func info(for device: IOHIDDevice) -> HIDDeviceInfo {
        func int(_ key: String) -> Int { (IOHIDDeviceGetProperty(device, key as CFString) as? Int) ?? 0 }
        func string(_ key: String) -> String { (IOHIDDeviceGetProperty(device, key as CFString) as? String) ?? "" }
        return HIDDeviceInfo(
            id: DeviceID(vendorID: int(kIOHIDVendorIDKey), productID: int(kIOHIDProductIDKey)),
            productName: string(kIOHIDProductKey).isEmpty ? "Unknown device" : string(kIOHIDProductKey),
            manufacturer: string(kIOHIDManufacturerKey),
            transport: string(kIOHIDTransportKey),
            primaryUsagePage: int(kIOHIDPrimaryUsagePageKey),
            primaryUsage: int(kIOHIDPrimaryUsageKey)
        )
    }
}

public enum InputMonitoringAccess {
    case granted, denied, unknown

    public static var current: InputMonitoringAccess {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted: return .granted
        case kIOHIDAccessTypeDenied: return .denied
        default: return .unknown
        }
    }

    /// Shows the system prompt the first time; afterwards the user has to use System Settings.
    @discardableResult
    public static func request() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }
}
