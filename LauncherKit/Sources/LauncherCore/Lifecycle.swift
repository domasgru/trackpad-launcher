import Foundation
import Observation

/// How macOS started this process, or opened it again. Parsed from the open or reopen Apple event by `ThisCopy`.
public enum Opening: Equatable, Sendable {
    /// As a login item: the open event carries the login-item marker. Silent: no window, dialog or prompt.
    case atLogin
    /// Finder, Spotlight, Launchpad, the Dock, Xcode: every opening that is not at login.
    case byHand
}

/// What one opening of this process leads to: the whole table, pure.
public enum Route: Equatable, Sendable {
    case runSilently, runWithWindow, askToMove, end

    /// `olderCopyRuns` matters only at login: two login starts converge on the older copy. By hand, a copy outside
    /// /Applications that is a release build asks to be moved; every other copy runs where it is.
    public init(_ opening: Opening, placement: Placement, olderCopyRuns: Bool) {
        switch (opening, placement, olderCopyRuns) {
        case (.atLogin, _, true): self = .end
        case (.atLogin, _, false): self = .runSilently
        case (.byHand, .elsewhere, _): self = .askToMove
        case (.byHand, .installed, _), (.byHand, .development, _): self = .runWithWindow
        }
    }
}

/// One process start.
public struct Launch: Equatable, Sendable {
    public var opening: Opening
    /// Only on the copy a move just installed: the disk image the mover ran from, ejected once the mover has exited.
    public var diskImageToEject: DiskImage?

    public init(opening: Opening, diskImageToEject: DiskImage? = nil) {
        self.opening = opening
        self.diskImageToEject = diskImageToEject
    }
}

/// The quit being handled in `applicationShouldTerminate`, as `QuitSignals` classifies it.
public enum QuitRequest: Equatable, Sendable {
    /// Logout, restart, shutdown: the event carried a quit reason, came from loginwindow, or arrived after power-off
    /// was announced.
    case system
    /// The Dock's Quit, AppleScript, Activity Monitor's Quit, another app.
    case other
}

public struct CopyID: Hashable, Sendable {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }
}

/// Another running Trackpad Launcher process: any build, any place, the menu bar version included.
public struct RunningCopy: Hashable, Sendable {
    public let id: CopyID
    /// Launched before this process, by the adapter's one total order (launch date, a missing date counting as latest,
    /// then pid). At login, this process defers to such a copy.
    public let startedEarlier: Bool

    public init(id: CopyID, startedEarlier: Bool) {
        self.id = id
        self.startedEarlier = startedEarlier
    }
}

/// The running Trackpad Launcher processes. Real: SystemRunningCopies. Test: InMemoryRunningCopies.
@MainActor public protocol RunningCopies: AnyObject {
    /// Every other process with this bundle identifier, read now.
    func others() -> [RunningCopy]
    /// Stops each at once without asking: a copy can neither refuse, nor ask its user, nor hang the stop. Calls
    /// `exited` once, on the main actor, when every listed copy has exited; synchronously when none still runs. The
    /// signal is the processes' own termination, never a wait or a poll.
    func stop(_ copies: [RunningCopy], then exited: @escaping @MainActor () -> Void)
    /// AppKit's terminate for this process; `Lifecycle.shouldEnd` has already agreed (stage `.ending`).
    func endThisCopy()
}

/// This app's login item, as the main app's Open at Login entry. Real: SystemLoginItem. Test: InMemoryLoginItem.
@MainActor public protocol LoginItem: AnyObject {
    /// The next login starts it. Every other status (never registered, the user's off) is off.
    var isOn: Bool { get }
    /// True when registered afterwards, already-registered included; false when macOS refused (the user turned it off
    /// in Login Items, an unsigned build).
    @discardableResult func register() -> Bool
    /// This process keeps running. A no-op when not registered.
    func unregister()
}

/// Starting at login: the one owner of "Trackpad Launcher turns back on only what it turned off itself". Its one fact
/// is its own key in the app's defaults domain, beside the `settings` record and never inside it, so a move and the
/// running copy never write the same record. A development build outside /Applications leaves starting at login
/// alone: every intent is a no-op for it. It only ever asks whether the item is on now, so how macOS reports a user's
/// own off cannot mislead it.
@MainActor public final class StartAtLogin {
    private let item: any LoginItem
    private let defaults: UserDefaults
    private let placement: Placement
    private let key = "startAtLoginTurnedOffByQuit"

    public init(item: any LoginItem, defaults: UserDefaults, placement: Placement) {
        self.item = item
        self.defaults = defaults
        self.placement = placement
    }

    /// The first run: turn it on and forget any stale fact. A user's earlier off stands: macOS refuses.
    public func enrol() {
        guard placement != .development else { return }
        item.register()
        forget()
    }

    /// Quit, or a move: if it is on now, remember that Trackpad Launcher turned it off, then turn it off. Remembering
    /// comes first, so a crash before the unregister leaves it on and remembered, and resuming converges.
    public func suspend() {
        guard placement != .development, item.isOn else { return }
        defaults.set(true, forKey: key)
        item.unregister()
    }

    /// Opened by hand: turn it back on only if Trackpad Launcher turned it off. The fact stays until macOS accepts;
    /// registering comes first, so a crash before forgetting registers again, harmlessly.
    public func resume() {
        guard placement != .development, defaults.bool(forKey: key) else { return }
        if item.register() { forget() }
    }

    private func forget() { defaults.removeObject(forKey: key) }
}

/// The dialog a copy opened by hand outside /Applications shows before anything else.
public enum MoveDialog: Equatable, Sendable {
    /// "Trackpad Launcher needs to be in the Applications folder": Move to Applications (default), Quit.
    case asking
    /// The move failed before /Applications changed: the reason, and Quit.
    case failed(reason: String)
}

public enum MoveAnswer: Sendable { case move, quit }

public enum InstallOutcome: Equatable, Sendable {
    case installed, cancelled, failed(reason: String)
}

/// Putting this copy into /Applications. Real: ApplicationsInstaller. Test: InMemoryInstaller.
@MainActor public protocol Installer: AnyObject {
    /// Copies this copy into /Applications, replacing any Trackpad Launcher there whatever its version. Nothing there
    /// changes unless the outcome is `.installed`, and never a mix of two copies. Unprivileged, the replace is one
    /// atomic step. `done` runs once, on the main actor. The copy can block; a test holds `done`.
    func install(then done: @escaping @MainActor (InstallOutcome) -> Void)
    /// Removes the copy the user opened (its original place when translocated), unless it is on a disk image or is the
    /// installed copy itself. A failure (a read-only share) leaves it there.
    func removeOriginal()
    /// Opens the installed copy as by hand.
    func openInstalledCopy()
    /// Ejects it; returns at once. A file on it in use leaves it mounted.
    func eject(_ diskImage: DiskImage)
}

/// What this process does as it starts, is opened again and is asked to quit.
@MainActor @Observable
public final class Lifecycle {
    /// Every legal situation of the process, and nothing else. Written only by the intents.
    private enum Stage {
        case idle
        /// Other copies are stopping; nothing of ours senses yet.
        case replacingOthers(opensWindow: Bool, eject: DiskImage?)
        case resident(Launcher)
        /// The move dialog is up; a resident keeps its gestures.
        case askingToMove(resident: Launcher?)
        /// After Move, until the process ends.
        case moving(resident: Launcher?)
        case moveFailed(reason: String, resident: Launcher?)
        case ending
    }

    private var stage: Stage = .idle
    @ObservationIgnored private let placement: Placement
    @ObservationIgnored private let copies: any RunningCopies
    @ObservationIgnored private let installer: any Installer
    @ObservationIgnored private let startAtLogin: StartAtLogin
    @ObservationIgnored private let makeResident: @MainActor () -> Launcher

    /// The gesture model once it runs, including while a resident shows the dialog, moves or shows the failure; nil for
    /// a copy that only asks or is still stopping others.
    public var launcher: Launcher? {
        switch stage {
        case .resident(let launcher): launcher
        case .askingToMove(let resident), .moving(let resident), .moveFailed(_, let resident): resident
        case .idle, .replacingOthers, .ending: nil
        }
    }

    /// What the move dialog presenter renders; nil when none shows.
    public var moveDialog: MoveDialog? {
        switch stage {
        case .askingToMove: .asking
        case .moveFailed(let reason, _): .failed(reason: reason)
        default: nil
        }
    }

    public init(
        placement: Placement, copies: any RunningCopies, installer: any Installer, startAtLogin: StartAtLogin,
        makeResident: @escaping @MainActor () -> Launcher
    ) {
        self.placement = placement
        self.installer = installer
        self.copies = copies
        self.startAtLogin = startAtLogin
        self.makeResident = makeResident
    }

    /// Once, from applicationDidFinishLaunching. A second call does nothing.
    public func launched(_ launch: Launch) {
        guard case .idle = stage else { return }
        let others = copies.others()
        let route = Route(launch.opening, placement: placement, olderCopyRuns: others.contains(where: \.startedEarlier))
        switch route {
        case .end: end()
        case .askToMove: stage = .askingToMove(resident: nil)
        case .runSilently: replace(others, opensWindow: false, eject: launch.diskImageToEject)
        case .runWithWindow: replace(others, opensWindow: true, eject: launch.diskImageToEject)
        }
    }

    /// From applicationShouldHandleReopen.
    public func openedAgain(_ opening: Opening) {
        switch (stage, Route(opening, placement: placement, olderCopyRuns: false)) {
        case (.replacingOthers(_, let eject), .runWithWindow): stage = .replacingOthers(opensWindow: true, eject: eject)
        case (.resident(let launcher), .runWithWindow): launcher.openedByHand()
        case (.resident(let launcher), .askToMove): stage = .askingToMove(resident: launcher)
        default: break
        }
    }

    /// From applicationShouldTerminate.
    public func shouldEnd(_ request: QuitRequest) -> Bool {
        switch stage {
        case .ending, .idle, .replacingOthers, .askingToMove, .moveFailed: return true
        case .moving: return request == .system
        case .resident(let launcher):
            // Every ordinary way to quit exists only while the settings window is open: close it, keep running. With it
            // closed, a quit is the system's or a script's: end, never hold up a logout.
            guard request == .other, launcher.isWindowOpen else { return true }
            launcher.closeWindow()
            return false
        }
    }

    /// The move dialog's buttons.
    public func answer(_ answer: MoveAnswer) {
        switch (stage, answer) {
        case (.askingToMove(let resident), .move):
            stage = .moving(resident: resident)
            installer.install { [unowned self] in installed($0) }
        case (.askingToMove, .quit), (.moveFailed, _): end()
        default: break
        }
    }

    /// The Quit Trackpad Launcher button: it also turns starting at login off, when that is on.
    public func quit() {
        guard case .resident = stage else { return }
        startAtLogin.suspend()
        end()
    }

    /// `.ending` first: ending the process asks `shouldEnd` again, synchronously, and that answer must be yes.
    private func end() {
        stage = .ending
        copies.endThisCopy()
    }

    /// The stage first: `stop` may call back before it returns.
    private func replace(_ others: [RunningCopy], opensWindow: Bool, eject: DiskImage?) {
        stage = .replacingOthers(opensWindow: opensWindow, eject: eject)
        copies.stop(others) { [unowned self] in othersExited() }
    }

    private func othersExited() {
        guard case .replacingOthers(let opensWindow, let eject) = stage else { return }
        let launcher = makeResident()
        launcher.start()
        stage = .resident(launcher)
        if opensWindow { launcher.openedByHand() }
        // The mover has exited, so its volume is free.
        if let eject { installer.eject(eject) }
    }

    /// The order converges after a crash at any point: the swap inside `install` is the first change anywhere, the login
    /// item is handed over before the original can go, and every other copy stops before the installed one opens, so
    /// that open always starts a fresh process.
    private func installed(_ outcome: InstallOutcome) {
        guard case .moving(let resident) = stage else { return }
        switch outcome {
        case .cancelled: end()
        case .failed(let reason): stage = .moveFailed(reason: reason, resident: resident)
        case .installed:
            startAtLogin.suspend()
            installer.removeOriginal()
            copies.stop(copies.others()) { [unowned self] in
                installer.openInstalledCopy()
                end()
            }
        }
    }
}
