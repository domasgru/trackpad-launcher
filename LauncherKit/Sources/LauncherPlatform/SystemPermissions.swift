import ApplicationServices
import CoreGraphics
import LauncherCore
import notify

/// Permissions over AX trust, screen-capture access and tccd's one Darwin notification (delivered about 30 ms after a
/// TCC change, on the main queue). The notification carries no payload and names no app or service, so both grants are
/// re-read on each broadcast and `onChange` runs only when either changed. No polling. The only file that may name the
/// trust check, the broadcast registration or the screen-capture access calls.
@MainActor public final class SystemPermissions: Permissions {
    /// tccd's broadcast name. Internal: the adapter's test posts it through `@testable` access.
    static let changeNotification = "com.apple.tcc.access.changed"
    public var onChange: (@MainActor () -> Void)?

    /// Both reads are injectable for the adapter's own test, which flips them and posts the notification itself.
    public init(
        trusted: @escaping @Sendable () -> Bool = { AXIsProcessTrusted() },
        capturing: @escaping @Sendable () -> Bool = { CGPreflightScreenCaptureAccess() }
    ) {
        reads = [.accessibility: trusted, .screenRecording: capturing]
        lastKnown = Self.granted(by: reads)
        notify_register_dispatch(Self.changeNotification, &token, .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    isolated deinit { notify_cancel(token) }

    public func isGranted(_ permission: Permission) -> Bool {
        let granted = reads[permission]?() ?? false
        if granted { lastKnown.insert(permission) } else { lastKnown.remove(permission) }
        return granted
    }

    /// .accessibility: the trust check with the prompt key. The key is spelled out because the imported
    /// `kAXTrustedCheckOptionPrompt` is a global `var` that strict concurrency rejects; its value is this string.
    /// .screenRecording: the system's request, which shows its prompt only the first time.
    public func ask(_ permission: Permission) {
        switch permission {
        case .accessibility:
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        case .screenRecording:
            _ = CGRequestScreenCaptureAccess()
        }
    }

    private static func granted(by reads: [Permission: @Sendable () -> Bool]) -> Set<Permission> {
        Set(reads.filter { $0.value() }.keys)
    }

    private func refresh() {
        let now = Self.granted(by: reads)
        guard now != lastKnown else { return }
        lastKnown = now
        onChange?()
    }

    /// The permissions granted at the last read.
    private var lastKnown: Set<Permission>
    private var token: Int32 = 0
    private let reads: [Permission: @Sendable () -> Bool]
}
