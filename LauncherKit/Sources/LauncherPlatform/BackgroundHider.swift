import AppKit
import LauncherCore

/// Hides every app but one, once that app is really in front. Nothing hides earlier, because macOS reacts to a hide by
/// activating another app whenever the app in front has nothing on screen. macOS activates a hidden app before it
/// unhides it, so being active is not enough: the app must be active and no longer hidden. Probed: hiding in that gap
/// sent the front to a third app in 4 of 30 single gestures; waiting for both, 0 of 90.
///
/// There is one goal at a time. A later call replaces it, and hides everything the earlier one had not, so a hide is
/// never lost to rapid gestures. Other apps' activations do not touch the goal. `hide()` answers nothing useful and a
/// hide can fail to land, so later passes hide whatever still shows. Observers and the clock exist only during a run.
@MainActor final class BackgroundHider {
    /// How long a goal waits for its app to come to the front. After this the user has moved on, or macOS refused.
    static let arrivalLimit = Duration.seconds(3)
    /// After the first pass, each wait from the pass before.
    static let recheckWaits: [Duration] = [.milliseconds(150), .milliseconds(350)]

    /// The system, injected so tests can stage any order of activating and unhiding.
    struct Apps {
        /// The bundle identifier of the active app.
        var frontmost: @MainActor () -> String?
        /// Whether a copy of the app is running and not hidden.
        var isShowing: @MainActor (String) -> Bool
        /// Hides each running app with a Dock icon and another bundle identifier that is not hidden yet.
        var hideOthers: @MainActor (String) -> Void
    }

    private struct Run {
        let goal: String
        let clock: LaunchClock
        var observers: [any NSObjectProtocol]
        var hasArrived = false
    }

    private let apps: Apps
    private let arrivalLimit: Duration
    private let recheckWaits: [Duration]
    private var run: Run?

    init(
        apps: Apps = .live, arrivalLimit: Duration = BackgroundHider.arrivalLimit,
        recheckWaits: [Duration] = BackgroundHider.recheckWaits
    ) {
        self.apps = apps
        self.arrivalLimit = arrivalLimit
        self.recheckWaits = recheckWaits
    }

    /// Pure, so the rule is pinned on its own.
    nonisolated static func hasArrived(goal: String, frontmost: String?, isShowing: Bool) -> Bool {
        frontmost == goal && isShowing
    }

    /// Returns at once. The goal's app arriving, here or later, starts the passes.
    func hideOthers(than app: BundleID) {
        end()
        let clock = LaunchClock()
        let center = NSWorkspace.shared.notificationCenter
        let names = [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didUnhideApplicationNotification]
        let observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.look() }
            }
        }
        run = Run(goal: app.rawValue, clock: clock, observers: observers)
        clock.after(arrivalLimit) { [weak self] in
            if self?.run?.hasArrived == false { self?.end() }
        }
        // On the next main-actor turn: a gesture's own turn stays free of the hides. An app already in front arrives here.
        Task { @MainActor [weak self] in self?.look() }
    }

    private func look() {
        guard let goal = run?.goal, run?.hasArrived == false,
            Self.hasArrived(goal: goal, frontmost: apps.frontmost(), isShowing: apps.isShowing(goal))
        else { return }
        run?.hasArrived = true
        pass(goal, then: recheckWaits[...])
    }

    /// Hides what still shows, while the goal's app is in front. A user who has moved on keeps what they see.
    private func pass(_ goal: String, then waits: ArraySlice<Duration>) {
        guard apps.frontmost() == goal else { return end() }
        apps.hideOthers(goal)
        guard let wait = waits.first else { return end() }
        run?.clock.after(wait) { [weak self] in
            self?.pass(goal, then: waits.dropFirst())
        }
    }

    private func end() {
        guard let run else { return }
        self.run = nil
        run.clock.stop()
        run.observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }
}

extension BackgroundHider.Apps {
    /// Every running app with a Dock icon. A menu bar app has none, so it stays.
    static var live: Self { scoped { _ in true } }

    /// `isInScope` narrows the apps it may hide.
    static func scoped(isInScope: @escaping @MainActor (NSRunningApplication) -> Bool) -> Self {
        Self(
            frontmost: { NSWorkspace.shared.frontmostApplication?.bundleIdentifier },
            isShowing: { id in
                NSRunningApplication.runningApplications(withBundleIdentifier: id).contains {
                    !$0.isTerminated && !$0.isHidden
                }
            },
            hideOthers: { id in
                for app in NSWorkspace.shared.runningApplications
                where app.activationPolicy == .regular && !app.isTerminated && !app.isHidden
                    && app.bundleIdentifier != id && isInScope(app) {
                    hide(app)
                }
            })
    }

    /// This process hides with the app's own hide. The activation policy stays regular, so the Dock icon remains.
    @MainActor private static func hide(_ app: NSRunningApplication) {
        if app.processIdentifier == NSRunningApplication.current.processIdentifier {
            NSApp.hide(nil)
        } else {
            app.hide()
        }
    }
}
