import Foundation

/// A window stack: the app's icon and one copy behind it per further window, 2 to 4 icons in all.
public struct WindowStack: Equatable, Sendable {
    public static let maxIcons = 4

    public let icons: Int

    /// nil below two windows; `icons` is the count capped at `maxIcons`.
    public init?(windows: Int) {
        guard windows >= 2 else { return nil }
        icons = min(windows, Self.maxIcons)
    }

    public var copies: Int { icons - 1 }
}

/// One slot's stack as the swipe knows it: `.pending` until its app answers, then fixed for the swipe.
public enum SlotStack: Equatable, Sendable {
    case pending
    /// Zero or one window, Trackpad App itself, or no answer within the deadline.
    case alone
    case stack(WindowStack)

    /// `.windows` counts through `windowCount`, so a stack and the window switcher never disagree; `.unanswered` and
    /// `.ownProcess` are `.alone`.
    public init(_ read: WindowRead) {
        if let windows = read.windowCount, let stack = WindowStack(windows: windows) {
            self = .stack(stack)
        } else {
            self = .alone
        }
    }
}
