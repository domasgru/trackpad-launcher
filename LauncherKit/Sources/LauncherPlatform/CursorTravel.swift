import Foundation
import IOKit
import LauncherCore

/// Where the switcher's swipe travel gets the cursor's acceleration from: the trackpad driver's curves and the user's
/// tracking speed. Read here so no IOKit or preferences type reaches the core.
enum CursorTravel {
    /// The global preference System Settings > Trackpad > Tracking speed writes, 0...3. Absent until first moved.
    private static let trackingSpeedKey = "com.apple.trackpad.scaling"

    /// The user's tracking speed, read fresh; the system default when never set. Nothing pushes a change to this key
    /// (key-value observing splits its dotted name), so it is read at the start of each swipe instead: a read on a user
    /// event, not a poll.
    static func trackingSpeed() -> Double {
        let value = CFPreferencesCopyAppValue(trackingSpeedKey as CFString, kCFPreferencesAnyApplication)
        return (value as? NSNumber)?.doubleValue ?? PointerCurve.defaultTrackingSpeed
    }

    /// The device's `HIDAccelCurves`, published on its HID event driver below the multitouch device; the built-in
    /// trackpad's curves when it publishes none.
    static func curves(of service: io_service_t) -> [PointerCurve.Point] {
        let found = IORegistryEntrySearchCFProperty(
            service, kIOServicePlane, "HIDAccelCurves" as CFString, kCFAllocatorDefault,
            IOOptionBits(kIORegistryIterateRecursively))
        guard let array = found as? [[String: NSNumber]], !array.isEmpty else { return PointerCurve.builtInCurves }
        return array.map { curve in
            func fixed(_ key: String) -> Double { (curve[key]?.doubleValue ?? 0) / 65536 }
            return PointerCurve.Point(
                index: fixed("HIDAccelIndex"), gainLinear: fixed("HIDAccelGainLinear"),
                gainParabolic: fixed("HIDAccelGainParabolic"), gainCubic: fixed("HIDAccelGainCubic"),
                gainQuartic: fixed("HIDAccelGainQuartic"), tangentSpeedLinear: fixed("HIDAccelTangentSpeedLinear"),
                tangentSpeedParabolicRoot: fixed("HIDAccelTangentSpeedParabolicRoot"))
        }
    }

    /// The travel a swipe starting now uses on a device with `curves`.
    static func travel(curves: [PointerCurve.Point]) -> SwipeTravel {
        let tuning = LaunchTuning.current
        guard tuning.swipeFollowsCursor else { return .linear }
        let speed = tuning.swipeTrackingSpeed >= 0 ? tuning.swipeTrackingSpeed : trackingSpeed()
        guard let curve = PointerCurve(curves, trackingSpeed: speed) else { return .linear }
        return .cursor(curve, pointsPerIcon: tuning.swipePointsPerIcon)
    }
}
