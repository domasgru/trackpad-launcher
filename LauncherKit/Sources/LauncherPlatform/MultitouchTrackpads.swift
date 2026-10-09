import AppKit
import IOKit
import LauncherCore

/// TrackpadHardware over MultitouchSupport and IOKit.
/// Frames arrive on MultitouchSupport's thread and are recognised there; only fired gestures hop to main.
/// IOKit matched/terminated notifications are delivered on the main queue and drained there; the initial
/// matches are drained at init so they do not count as a change. Waking the Mac is reported as a change too,
/// because devices stop delivering frames across sleep and `run` restarts them.
@MainActor public final class MultitouchTrackpads: TrackpadHardware {
    public var onEvent: (@MainActor (TrackpadEvent) -> Void)?

    private let framework: MultitouchSupport?
    private let notificationPort: IONotificationPortRef
    private var iterators: [io_iterator_t] = []
    private var startedDevices: [AnyObject] = []
    private var clickTap: ClickTap?
    private var actuators: [TrackpadID: CFTypeRef] = [:]
    private var wakeObserver: (any NSObjectProtocol)?

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
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onEvent?(.trackpadsChanged) }
        }
    }

    isolated deinit {
        wakeObserver.map { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        iterators.forEach { IOObjectRelease($0) }
        IONotificationPortDestroy(notificationPort)
    }

    /// Every multitouch device that is a trackpad.
    public func connected() -> [Trackpad] {
        listTrackpads().map(\.trackpad)
    }

    /// Forgets every session, stops every device, then starts exactly `trackpads` with a fresh recognizer each.
    /// A click tap exists afterwards iff `blockClicks`, the system allows it and a trackpad is running.
    public func run(_ trackpads: [Trackpad], handMode: HandMode, blockClicks: Bool) {
        guard let framework else { return }
        sessions.withLock { $0 = [:] }
        // A withheld press's release may now reach apps: a harmless stray mouse-up.
        clickTap?.remove()
        clickTap = nil
        for device in startedDevices {
            let ref = Unmanaged.passUnretained(device).toOpaque()
            framework.unregisterContactFrameCallback(ref, contactFrameCallback)
            _ = framework.stop(ref)
        }
        actuators.values.forEach { _ = framework.actuatorClose($0) }
        actuators = [:]
        startedDevices = []

        let wanted = Set(trackpads.map(\.id))
        let devices = listTrackpads().filter { wanted.contains($0.trackpad.id) }
        if blockClicks && !devices.isEmpty { clickTap = ClickTap.install() }
        for (device, trackpad) in devices {
            let ref = Unmanaged.passUnretained(device).toOpaque()
            let session = DeviceSession(
                trackpad: trackpad.id,
                recognizer: GestureRecognizer(handMode: handMode, surface: trackpad.surface),
                clickTap: clickTap,
                deliver: { [weak self] event in
                    Task { @MainActor in self?.onEvent?(.gesture(event)) }
                })
            if let actuator = framework.actuatorCreateFromDeviceID(trackpad.id.rawValue)?.takeRetainedValue(),
                framework.actuatorOpen(actuator) == 0
            {
                actuators[trackpad.id] = actuator
            }
            sessions.withLock { $0[UInt(bitPattern: ref)] = session }
            framework.registerContactFrameCallback(ref, contactFrameCallback)
            _ = framework.start(ref, 0)
            startedDevices.append(device)
        }
    }

    /// No-op for a trackpad that is not running or whose actuator would not open.
    public func playFeedback(on trackpad: TrackpadID) {
        guard let framework, let actuator = actuators[trackpad] else { return }
        _ = framework.actuatorActuate(actuator, Self.feedbackActuation, 0, 0, 0)
    }

    /// Chosen by feel: 3 weak, 4 medium, 6 strong.
    static let feedbackActuation: Int32 = 6

    /// Devices stay retained here for as long as their callbacks are registered, so the refs used as
    /// registry keys remain valid.
    private func listTrackpads() -> [(device: AnyObject, trackpad: Trackpad)] {
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
            return (
                device,
                Trackpad(
                    id: TrackpadID(rawValue: id), kind: kind,
                    surface: SurfaceSize(widthMM: Double(width) / 100, heightMM: Double(height) / 100))
            )
        }
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
