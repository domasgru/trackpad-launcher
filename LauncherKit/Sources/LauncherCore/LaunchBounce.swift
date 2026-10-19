import Foundation

/// What the adapter learned about a launch a gesture started, pushed while its launch bounce plays.
public enum LaunchProgress: Equatable, Sendable {
    /// macOS reports the app finished launching; menu bar apps too (key-value observation).
    case finishedLaunching
    /// A window of the app is on screen, on any display; a splash screen counts.
    case windowShown
    /// macOS could not launch it, or its process ended before the bounce did.
    case wentNowhere
    /// The bounce reached a time limit: its cap, or the limit set once the app finished launching.
    case ranOut
}

/// How a launch bounce ends.
public enum LaunchBounceEnding: Equatable, Sendable {
    /// The launch animation, from wherever the icon is at that moment, even mid-jump.
    case launchAnimation
    /// A fade in place, about 0.2 s, with no launch animation.
    case quietFade
}

/// One app's launch bounce as the model sees it: how far its launch has got, as far as the ending depends on it.
/// A bounce that ended is absent from `Launcher.bounces`, so a late report finds nothing and plays nothing.
enum LaunchBounce: Equatable, Sendable {
    case startingUp
    case startedUp

    /// No bounce lasts longer than this after its gesture fired.
    static let cap = Duration.seconds(10)
    /// Once its app finished launching, how long a bounce waits for a window.
    static let grace = Duration.seconds(2)

    enum Step: Equatable, Sendable {
        case carryOn
        /// The bounce becomes `.startedUp` and now runs out within `limit` at the latest.
        case startUp(limit: Duration)
        case end(LaunchBounceEnding)
    }

    func next(after progress: LaunchProgress) -> Step {
        switch (self, progress) {
        case (_, .windowShown): .end(.launchAnimation)
        case (_, .wentNowhere): .end(.quietFade)
        case (.startingUp, .finishedLaunching): .startUp(limit: Self.grace)
        case (.startedUp, .finishedLaunching): .carryOn
        case (.startingUp, .ranOut): .end(.quietFade)
        case (.startedUp, .ranOut): .end(.launchAnimation)
        }
    }
}
