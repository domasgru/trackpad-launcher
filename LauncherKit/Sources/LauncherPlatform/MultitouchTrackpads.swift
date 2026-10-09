import Foundation
import IOKit
import LauncherCore

/// TrackpadHardware over MultitouchSupport and IOKit.
/// IOKit matched/terminated notifications are delivered on the main queue and drained there; the initial
/// matches are drained at init so they do not count as a change.
@MainActor public final class MultitouchTrackpads: TrackpadHardware {
    public var onEvent: (@MainActor (TrackpadEvent) -> Void)?

    private let framework: MultitouchSupport?
    private let notificationPort: IONotificationPortRef
    private var iterators: [io_iterator_t] = []
    private var running: Set<TrackpadID> = []

    /// On a failed `dlopen`, `connected()` is empty: the app shows "No trackpad connected".
    public init() {
        framework = MultitouchSupport()
        notificationPort = IONotificationPortCreate(kIOMainPortDefault)
        IONotificationPortSetDispatchQueue(notificationPort, .main)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for notification in [kIOFirstMatchNotification, kIOTerminatedNotification] {
            var iterator: io_iterator_t = 0
            let status = IOServiceAddMatchingNotification(
                notificationPort, notification, IOServiceMatching("AppleMultitouchDevice"),
                { refcon, iterator in
                    guard let refcon else { return }
                    let hardware = Unmanaged<MultitouchTrackpads>.fromOpaque(refcon).takeUnretainedValue()
                    MainActor.assumeIsolated {
                        MultitouchTrackpads.drain(iterator)
                        hardware.onEvent?(.trackpadsChanged)
                    }
                },
                refcon, &iterator)
            guard status == KERN_SUCCESS else { continue }
            Self.drain(iterator)
            iterators.append(iterator)
        }
    }

    isolated deinit {
        iterators.forEach { IOObjectRelease($0) }
        IONotificationPortDestroy(notificationPort)
    }

    /// Every multitouch device that is a trackpad. A device with an unreadable ID, surface or product is skipped.
    public func connected() -> [Trackpad] {
        guard let framework else { return [] }
        let devices = framework.createList().takeRetainedValue() as [AnyObject]
        return devices.compactMap { device in
            let ref = Unmanaged.passUnretained(device).toOpaque()
            var id: UInt64 = 0
            var width: Int32 = 0
            var height: Int32 = 0
            guard framework.getDeviceID(ref, &id) == 0,
                framework.getSensorSurfaceDimensions(ref, &width, &height) == 0, width > 0, height > 0,
                let product = Self.product(of: framework.getService(ref)),
                let kind = trackpadKind(product: product, isBuiltIn: framework.isBuiltIn(ref))
            else { return nil }
            return Trackpad(
                id: TrackpadID(rawValue: id), kind: kind,
                surface: SurfaceSize(widthMM: Double(width) / 100, heightMM: Double(height) / 100))
        }
    }

    /// Session bookkeeping only: no device is started and no frame is read here yet.
    public func run(_ trackpads: [Trackpad], handMode: HandMode) {
        running = Set(trackpads.map(\.id))
    }

    /// No-op for a trackpad that is not running; actuators are not opened yet.
    public func playFeedback(on trackpad: TrackpadID) {
        guard running.contains(trackpad) else { return }
    }

    private static func product(of service: io_service_t) -> String? {
        IORegistryEntryCreateCFProperty(service, "Product" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String
    }

    /// Releasing every pending service is what re-arms the notification.
    private nonisolated static func drain(_ iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            IOObjectRelease(service)
        }
    }
}
