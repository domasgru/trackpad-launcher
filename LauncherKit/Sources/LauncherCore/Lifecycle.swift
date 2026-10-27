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
    case runSilently, runWithWindow

    public init(_ opening: Opening) {
        switch opening {
        case .atLogin: self = .runSilently
        case .byHand: self = .runWithWindow
        }
    }
}

/// One process start.
public struct Launch: Equatable, Sendable {
    public var opening: Opening

    public init(opening: Opening) { self.opening = opening }
}

/// The quit being handled in `applicationShouldTerminate`, as `QuitSignals` classifies it.
public enum QuitRequest: Equatable, Sendable {
    /// Logout, restart, shutdown: the event carried a quit reason, came from loginwindow, or arrived after power-off
    /// was announced.
    case system
    /// The Dock's Quit, AppleScript, Activity Monitor's Quit, another app.
    case other
}

/// The running Trackpad Launcher processes. Real: SystemRunningCopies. Test: InMemoryRunningCopies.
@MainActor public protocol RunningCopies: AnyObject {
    /// AppKit's terminate for this process; `Lifecycle.shouldEnd` has already agreed (stage `.ending`).
    func endThisCopy()
}

/// This app's login item, as the main app's Open at Login entry. Real: SystemLoginItem. Test: InMemoryLoginItem.
@MainActor public protocol LoginItem: AnyObject {
    /// True when registered afterwards, already-registered included; false when macOS refused (the user turned it off
    /// in Login Items, an unsigned build).
    @discardableResult func register() -> Bool
}

/// Starting at login: the one owner of "Trackpad Launcher turns back on only what it turned off itself".
@MainActor public final class StartAtLogin {
    private let item: any LoginItem

    public init(item: any LoginItem) { self.item = item }

    /// The first run: turn it on. A user's earlier off stands: macOS refuses.
    public func enrol() { item.register() }
}

/// What this process does as it starts, is opened again and is asked to quit.
@MainActor @Observable
public final class Lifecycle {
    /// Every legal situation of the process, and nothing else. Written only by the intents.
    private enum Stage {
        case idle
        case resident(Launcher)
        case ending
    }

    private var stage: Stage = .idle
    @ObservationIgnored private let copies: any RunningCopies
    @ObservationIgnored private let makeResident: @MainActor () -> Launcher

    /// The gesture model once it runs; nil before.
    public var launcher: Launcher? {
        if case .resident(let launcher) = stage { launcher } else { nil }
    }

    public init(copies: any RunningCopies, makeResident: @escaping @MainActor () -> Launcher) {
        self.copies = copies
        self.makeResident = makeResident
    }

    /// Once, from applicationDidFinishLaunching. A second call does nothing.
    public func launched(_ launch: Launch) {
        guard case .idle = stage else { return }
        let launcher = makeResident()
        launcher.start()
        stage = .resident(launcher)
        if Route(launch.opening) == .runWithWindow { launcher.openedByHand() }
    }

    /// From applicationShouldHandleReopen.
    public func openedAgain(_ opening: Opening) {
        guard case .resident(let launcher) = stage, Route(opening) == .runWithWindow else { return }
        launcher.openedByHand()
    }

    /// From applicationShouldTerminate.
    public func shouldEnd(_ request: QuitRequest) -> Bool {
        switch stage {
        case .ending, .idle: return true
        case .resident(let launcher):
            // Every ordinary way to quit exists only while the settings window is open: close it, keep running. With it
            // closed, a quit is the system's or a script's: end, never hold up a logout.
            guard request == .other, launcher.isWindowOpen else { return true }
            launcher.closeWindow()
            return false
        }
    }

    /// The Quit Trackpad Launcher button.
    public func quit() {
        guard launcher != nil else { return }
        end()
    }

    /// `.ending` first: ending the process asks `shouldEnd` again, synchronously, and that answer must be yes.
    private func end() {
        stage = .ending
        copies.endThisCopy()
    }
}
