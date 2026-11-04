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

    /// Every foreground app, frontmost first: this process too, exactly while its Dock icon shows.
    func apps() -> [AppEntry] {
        guard let serials = copyOrder(Self.defaultSession)?.takeRetainedValue() as? [CFTypeRef] else { return [] }
        return Self.entries(
            serials.compactMap {
                copyInformation(Self.currentConnection, $0, Self.keys as CFArray)?.takeRetainedValue()
                    as? [String: Any]
            })
    }

    /// The parse of LaunchServices' answers, in their order: an entry for every `Foreground` app with a bundle path and
    /// identifier, whatever its pid.
    static func entries(_ informations: [[String: Any]]) -> [AppEntry] {
        informations.compactMap { information in
            guard information["ApplicationType"] as? String == "Foreground",
                let path = information["LSBundlePath"] as? String,
                let identifier = information["CFBundleIdentifier"] as? String
            else { return nil }
            return RunningApp.entry(
                bundleIdentifier: identifier, name: information["LSDisplayName"] as? String, path: path)
        }
    }
}
