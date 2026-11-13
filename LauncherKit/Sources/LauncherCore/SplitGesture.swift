import Foundation

extension Assignment {
    /// What a fire brings to front, from which apps are on disk now: both is a split; one is that app alone, as a
    /// one-app gesture; none is nothing, silent as a missing app is. One Info.plist read per app.
    func target(locate: (AssignedApp) -> AppEntry?) -> GestureTarget {
        let first = locate(first)
        guard let second else { return first.map(GestureTarget.one) ?? .nothing }
        switch (first, locate(second)) {
        case (let first?, let second?): return .split(first: first, second: second)
        case (let first?, nil): return .one(first)
        case (nil, let second?): return .one(second)
        case (nil, nil): return .nothing
        }
    }
}

enum GestureTarget: Equatable, Sendable {
    case nothing
    case one(AppEntry)
    case split(first: AppEntry, second: AppEntry)
}

/// The side an app of a split gesture takes: the first app left, the second right. Halves, sway and bounce order all
/// derive from it.
public enum SplitSide: Equatable, Sendable { case left, right }

/// One app of a split gesture, as the model decided to bring it to front.
public struct SplitApp: Equatable, Sendable {
    public let app: AppEntry
    public let entrance: Entrance

    public init(_ app: AppEntry, _ entrance: Entrance) {
        self.app = app
        self.entrance = entrance
    }

    public enum Entrance: Equatable, Sendable {
        /// Has a process. `followed`: a new watch reports its next window on screen (no bounce).
        case running(animates: Bool, followed: Bool)
        /// No process. `watch` nil: launched and not watched.
        case launching(watch: Watch?)
        /// Its launch is already watched: opened only; its one watch, bounce and side carry on.
        case alreadyLaunching
    }

    public enum Watch: Equatable, Sendable { case unseen, bouncing }
}

public struct SplitArrival: Equatable, Sendable {
    public let first: SplitApp
    public let second: SplitApp
    /// How a running second app comes to front.
    public let secondEntry: SecondEntry

    public init(first: SplitApp, second: SplitApp, secondEntry: SecondEntry) {
        self.first = first
        self.second = second
        self.secondEntry = secondEntry
    }

    public enum SecondEntry: Equatable, Sendable {
        /// Activated just before the first app: its menu bar shows for a moment, and its windows come in front of
        /// every other app's.
        case focused
        /// Never activated, so only the first app's menu bar shows: while the hide background apps setting is on,
        /// every other app hides, so nothing else covers it. Raising its window instead was probed and refused: real
        /// apps (Xcode, Electron apps) answer an Accessibility raise by activating themselves.
        case unfocused
    }
}
