import Foundation

/// One app's windows as one read found them.
public struct AppWindows: Equatable, Sendable {
    /// On the current Space, front to back. Panels, palettes, sheets and other helpers are left out.
    public let visible: [AppWindow]
    /// Minimised, in the order the app lists them.
    public let minimised: [AppWindow]

    public init(visible: [AppWindow], minimised: [AppWindow]) {
        self.visible = visible
        self.minimised = minimised
    }
}

/// What one read of one app's windows came to.
public enum WindowRead: Equatable, Sendable {
    /// Every call into the app answered within the read's deadline.
    case windows(AppWindows)
    /// No answer within the deadline, a call that could not complete partway (what was read so far is dropped), an
    /// immediate refusal, no Accessibility, or the app no longer running.
    case unanswered
    /// Trackpad Launcher itself, never read: its one window is the settings window.
    case ownProcess
}

/// One launch of a running app: equal for the same process, different after the app quits and opens again. Opaque:
/// the adapter makes it from the process id and the kernel's start time for that process; Core only compares it.
public struct AppLaunch: Hashable, Sendable {
    private let token: String

    package init(_ token: String) { self.token = token }
}

/// One read of the frontmost app's windows.
public enum FrontmostWindows: Equatable, Sendable {
    /// There is no active app.
    case noApp
    case app(AppEntry, AppLaunch, WindowRead)
}

extension WindowRead {
    /// How many windows a window swipe into the app lists: `WindowPick`'s count, ten at most; one for Trackpad
    /// Launcher's settings window; nil when the app did not answer.
    public var windowCount: Int? {
        switch self {
        case .windows(let windows): WindowPick(windows).count
        case .ownProcess: 1
        case .unanswered: nil
        }
    }
}

/// The windows a window swipe into the app lists, picked from one answered read: the window in front, the other
/// visible windows front to back, then the minimised ones in the app's order, `windowSwitcherMaxRows` at most. A
/// full-screen front window is picked alone; other full-screen windows never.
struct WindowPick: Equatable, Sendable {
    let front: AppWindow?
    let others: [AppWindow]
    let minimised: [AppWindow]

    init(_ windows: AppWindows) {
        let limit = GestureRules.windowSwitcherMaxRows
        front = windows.visible.first
        if front?.isFullScreen == true {
            others = []
            minimised = []
        } else {
            others = Array(windows.visible.dropFirst().filter { !$0.isFullScreen }.prefix(limit - 1))
            minimised = Array(windows.minimised.prefix(limit - (front == nil ? 0 : 1) - others.count))
        }
    }

    var count: Int { (front == nil ? 0 : 1) + others.count + minimised.count }
    /// The picked visible windows, front to back: what a lift on the front window restores.
    var zOrder: [WindowID] { ((front.map { [$0] } ?? []) + others).map(\.id) }
    var windows: [AppWindow] { (front.map { [$0] } ?? []) + others + minimised }
}

extension GestureRules {
    /// The most one read of one app's windows may take from the moment it is asked for.
    package static let windowReadDeadline = Duration.milliseconds(200)
}
