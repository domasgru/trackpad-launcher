import ApplicationServices
import LauncherCore
import notify

/// AccessibilityPermission over AX trust and tccd's Darwin notification (delivered about 30 ms after a TCC change, on
/// the main queue). The notification names no app and no service, so trust is re-read on every broadcast and
/// `onChange` runs only when the value changed. No polling.
@MainActor public final class SystemAccessibilityPermission: AccessibilityPermission {
    /// Public so the adapter's test can `notify_post` the same name.
    public static let changeNotification = "com.apple.tcc.access.changed"
    public var onChange: (@MainActor () -> Void)?

    /// `trusted` is injectable for the adapter's own test, which flips it and posts the notification itself.
    public init(trusted: @escaping @Sendable () -> Bool = { AXIsProcessTrusted() }) {
        self.trusted = trusted
        lastKnown = trusted()
        notify_register_dispatch(Self.changeNotification, &token, .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    isolated deinit { notify_cancel(token) }

    public func isGranted() -> Bool {
        lastKnown = trusted()
        return lastKnown
    }

    /// The key is spelled out because the imported `kAXTrustedCheckOptionPrompt` is a global `var` that strict
    /// concurrency rejects; its value is this string.
    public func prompt() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    private func refresh() {
        let now = trusted()
        guard now != lastKnown else { return }
        lastKnown = now
        onChange?()
    }

    private var lastKnown: Bool
    private var token: Int32 = 0
    private let trusted: @Sendable () -> Bool
}
