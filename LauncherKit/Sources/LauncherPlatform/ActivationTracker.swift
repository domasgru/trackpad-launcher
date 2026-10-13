import AppKit

/// The regular apps activated since it was created, most recent first. Seeded with the app then in front, which no
/// later notification would report.
@MainActor final class ActivationTracker {
    private(set) var recency: [Int32] = []
    private var observer: NSObjectProtocol?

    init() {
        if let front = NSWorkspace.shared.frontmostApplication { note(front) }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }
            MainActor.assumeIsolated { self?.note(app) }
        }
    }

    isolated deinit {
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    private func note(_ app: NSRunningApplication) {
        guard app.activationPolicy == .regular, app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else { return }
        recency.removeAll { $0 == app.processIdentifier }
        recency.insert(app.processIdentifier, at: 0)
    }
}
