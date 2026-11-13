import AppKit
import LauncherCore

/// Keeps a split's focused app active for a moment after the split. Some apps take the focus by themselves when they
/// are brought to front without it (Electron apps answer an open's reopen by activating; probed with Notion), and two
/// activations back to back can land in either order; either way the split's other app ends active. During the keep,
/// that app becoming active brings the focused app to front again. Any third app becoming active ends the keep, since
/// the user has moved on; so does the next keep, and `duration`. Observers and the clock exist only during a keep.
@MainActor final class FocusKeeper {
    /// Long enough for an app answering its open, short enough that a user's own switch to the other app a moment
    /// later is theirs.
    static let duration = Duration.seconds(1)

    enum Response: Equatable { case refocus, carryOn, end }

    /// Pure, so the rule is pinned on its own.
    nonisolated static func response(toActivationOf activated: String?, keeping: BundleID, against other: BundleID)
        -> Response
    {
        switch activated {
        case other.rawValue: .refocus
        case keeping.rawValue: .carryOn
        default: .end
        }
    }

    private struct Keep {
        let clock: LaunchClock
        let observer: any NSObjectProtocol
    }

    private let center: NotificationCenter
    private let duration: Duration
    private let refocus: @MainActor (AppEntry) -> Void
    private let ended: @MainActor () -> Void
    private var keep: Keep?

    /// `refocus` brings the focused app to front again. Tests post activations to a center of their own, and hear each
    /// keep end through `ended`.
    init(
        center: NotificationCenter = NSWorkspace.shared.notificationCenter, duration: Duration = FocusKeeper.duration,
        ended: @escaping @MainActor () -> Void = {}, refocus: @escaping @MainActor (AppEntry) -> Void
    ) {
        self.center = center
        self.duration = duration
        self.ended = ended
        self.refocus = refocus
    }

    func keep(_ app: AppEntry, against other: BundleID) {
        end()
        let clock = LaunchClock()
        let observer = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let activated = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?
                .bundleIdentifier
            MainActor.assumeIsolated {
                guard let self else { return }
                switch Self.response(toActivationOf: activated, keeping: app.bundleID, against: other) {
                case .refocus: self.refocus(app)
                case .carryOn: break
                case .end: self.end()
                }
            }
        }
        keep = Keep(clock: clock, observer: observer)
        clock.after(duration) { [weak self] in self?.end() }
    }

    func end() {
        guard let keep else { return }
        self.keep = nil
        keep.clock.stop()
        center.removeObserver(keep.observer)
        ended()
    }
}
