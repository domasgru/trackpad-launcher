import Foundation

/// What the adapter learned about a launch a gesture started, pushed while the launch is watched.
public enum LaunchProgress: Equatable, Sendable {
    /// macOS reports the app finished launching; menu bar apps too (key-value observation).
    case finishedLaunching
    /// A window of the app is on screen, on any display; a splash screen counts.
    case windowShown
    /// macOS could not launch it, or its process ended before the launch's watch did.
    case wentNowhere
    /// The launch's watch reached a time limit: its cap, or the limit set once the app finished launching.
    case ranOut
}

/// How a launch bounce ends.
public enum LaunchBounceEnding: Equatable, Sendable {
    /// The launch animation, from wherever the icon is at that moment, even mid-jump.
    case launchAnimation
    /// A fade in place, about 0.2 s, with no launch animation.
    case quietFade
}

/// One app's watched launch as the model sees it: how far the launch has got, as far as its ending depends on it, and
/// whether the other apps hide when its window shows. Whether a bounce shows is the adapter's: the table and the limit
/// are the same either way. A launch that ended is absent from `Launcher.launches`, so a late report finds nothing.
struct WatchedLaunch: Equatable, Sendable {
    var stage: Stage
    /// What hides when its first window shows, as the latest gesture for this app left it; nil: nothing.
    var hidesOnWindow: KeptApps?

    enum Stage: Equatable, Sendable {
        case startingUp
        case startedUp

        enum Step: Equatable, Sendable {
            case carryOn
            /// The launch becomes `.startedUp` and now runs out within `limit` at the latest.
            case startUp(limit: Duration)
            case end(LaunchBounceEnding)
        }

        func next(after progress: LaunchProgress) -> Step {
            switch (self, progress) {
            case (_, .windowShown): .end(.launchAnimation)
            case (_, .wentNowhere): .end(.quietFade)
            case (.startingUp, .finishedLaunching): .startUp(limit: WatchedLaunch.grace)
            case (.startedUp, .finishedLaunching): .carryOn
            case (.startingUp, .ranOut): .end(.quietFade)
            case (.startedUp, .ranOut): .end(.launchAnimation)
            }
        }
    }

    /// No watch lasts longer than this after its gesture fired.
    static let cap = Duration.seconds(10)
    /// Once its app finished launching, how long a watch waits for a window.
    static let grace = Duration.seconds(2)
}
