import Foundation
import LauncherCore

/// The order ⌘-Tab shows its apps in, from two private LaunchServices functions resolved with `dlsym` from the
/// LaunchServices image AppKit already loaded (no link flags, no entitlements, no prompt; the app is not sandboxed).
/// Both symbols are resolved up front; a missing one fails the whole load, so a macOS that drops them reads as
/// "no order" instead of crashing.
struct LaunchServicesOrder: Sendable {
    private typealias CopyOrder = @convention(c) (UInt32) -> Unmanaged<CFArray>?
    private typealias CopyInformation = @convention(c) (Int32, CFTypeRef, CFArray?) -> Unmanaged<CFDictionary>?

    private let copyOrder: CopyOrder
    private let copyInformation: CopyInformation

    /// The default session: the apps of the logged-in user.
    private static let defaultSession: UInt32 = 0xFFFF_FFFE
    /// The current process's connection to LaunchServices.
    private static let currentConnection: Int32 = -2
    /// Only these five keys are asked for: the full dictionary costs more than twice as much per app.
    private static let keys = ["pid", "ApplicationType", "LSBundlePath", "CFBundleIdentifier", "LSDisplayName"]

    init?() {
        func symbol<T>(_ name: String, as type: T.Type) -> T? {
            // RTLD_DEFAULT
            dlsym(UnsafeMutableRawPointer(bitPattern: -2), name).map { unsafeBitCast($0, to: type) }
        }
        guard let copyOrder = symbol("_LSCopyApplicationArrayInFrontToBackOrder", as: CopyOrder.self),
            let copyInformation = symbol("_LSCopyApplicationInformation", as: CopyInformation.self)
        else { return nil }
        self.copyOrder = copyOrder
        self.copyInformation = copyInformation
    }

    /// Every foreground app other than this process, frontmost first. The array holds nothing else today; the
    /// filters guard against a future macOS.
    func apps() -> [AppEntry] {
        guard let serials = copyOrder(Self.defaultSession)?.takeRetainedValue() as? [CFTypeRef] else { return [] }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return serials.compactMap { serial in
            guard
                let information = copyInformation(Self.currentConnection, serial, Self.keys as CFArray)?
                    .takeRetainedValue() as? [String: Any],
                information["ApplicationType"] as? String == "Foreground",
                let pid = (information["pid"] as? NSNumber)?.int32Value, pid != ownPID,
                let path = information["LSBundlePath"] as? String,
                let identifier = information["CFBundleIdentifier"] as? String
            else { return nil }
            return RunningApp.entry(
                bundleIdentifier: identifier, name: information["LSDisplayName"] as? String, path: path)
        }
    }
}
