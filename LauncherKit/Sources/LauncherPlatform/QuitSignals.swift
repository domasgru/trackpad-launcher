import AppKit
import LauncherCore

/// Tells a quit the system makes (logout, restart, shutdown) from one the user or a script makes.
@MainActor public final class QuitSignals {
    private var powerOffAnnounced = false
    private let workspace: NotificationCenter
    private var observer: NSObjectProtocol?

    public init(workspace: NotificationCenter = NSWorkspace.shared.notificationCenter) {
        self.workspace = workspace
        observer = workspace.addObserver(forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main) {
            [weak self] _ in
            MainActor.assumeIsolated { self?.powerOffAnnounced = true }
        }
    }

    isolated deinit {
        if let observer { workspace.removeObserver(observer) }
    }

    public func request(for event: NSAppleEventDescriptor?) -> QuitRequest {
        let reason = event?.attributeDescriptor(forKeyword: AEKeyword(kAEQuitReason))
            ?? event?.paramDescriptor(forKeyword: AEKeyword(kAEQuitReason))
        let sender = event?.attributeDescriptor(forKeyword: AEKeyword(keySenderPIDAttr))
            .flatMap { NSRunningApplication(processIdentifier: pid_t($0.int32Value)) }
        return Self.request(
            hasQuitReason: reason != nil, senderBundleID: sender?.bundleIdentifier, afterPowerOff: powerOffAnnounced)
    }

    static func request(hasQuitReason: Bool, senderBundleID: String?, afterPowerOff: Bool) -> QuitRequest {
        hasQuitReason || senderBundleID == "com.apple.loginwindow" || afterPowerOff ? .system : .other
    }
}
