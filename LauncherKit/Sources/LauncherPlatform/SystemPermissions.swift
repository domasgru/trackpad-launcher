import ApplicationServices
import LauncherCore
import notify

/// Permissions over AX trust and tccd's Darwin notification (delivered about 30 ms after a TCC change, on the main
/// queue). The notification names no app and no service, so every grant is re-read on each broadcast and `onChange`
/// runs only when one changed. No polling. The one module that registers for the broadcast.
@MainActor public final class SystemPermissions: Permissions {
    /// tccd's broadcast name. Internal: the adapter's test posts it through `@testable` access.
    static let changeNotification = "com.apple.tcc.access.changed"
    public var onChange: (@MainActor () -> Void)?

    /// `trusted` is injectable for the adapter's own test, which flips it and posts the notification itself.
    public init(trusted: @escaping @Sendable () -> Bool = { AXIsProcessTrusted() }) {
        self.trusted = trusted
        lastKnown = Self.read(trusted)
        notify_register_dispatch(Self.changeNotification, &token, .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    isolated deinit { notify_cancel(token) }

    public func isGranted(_ permission: Permission) -> Bool {
        lastKnown = Self.read(trusted)
        return lastKnown.contains(permission)
    }

    /// .accessibility: the trust check with the prompt key. The key is spelled out because the imported
    /// `kAXTrustedCheckOptionPrompt` is a global `var` that strict concurrency rejects; its value is this string.
    public func ask(_ permission: Permission) {
        switch permission {
        case .accessibility:
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        }
    }

    private static func read(_ trusted: @Sendable () -> Bool) -> Set<Permission> {
        trusted() ? [.accessibility] : []
    }

    private func refresh() {
        let now = Self.read(trusted)
        guard now != lastKnown else { return }
        lastKnown = now
        onChange?()
    }

    /// The permissions granted at the last read.
    private var lastKnown: Set<Permission>
    private var token: Int32 = 0
    private let trusted: @Sendable () -> Bool
}
