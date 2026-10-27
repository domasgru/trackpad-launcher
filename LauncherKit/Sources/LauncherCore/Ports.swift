import Foundation

public enum TrackpadEvent: Sendable {
    case gesture(GestureEvent)
    case swipe(SwipeEvent)
    case windowSwipe(SwipeEvent)
    case swap(SwapEvent)
    /// Attached, detached, or the Mac woke.
    case trackpadsChanged

    /// The one mapping from what a recognizer said to what the port carries. Both hardware adapters use it.
    public init(_ event: Recognition.Event, on trackpad: TrackpadID) {
        switch event {
        case .fired(let gesture): self = .gesture(GestureEvent(gesture: gesture, trackpad: trackpad))
        case .swipe(let phase): self = .swipe(SwipeEvent(phase: phase, trackpad: trackpad))
        case .windowSwipe(let phase): self = .windowSwipe(SwipeEvent(phase: phase, trackpad: trackpad))
        case .swap(let startsSeries): self = .swap(SwapEvent(startsSeries: startsSeries, trackpad: trackpad))
        }
    }
}

/// The two haptics: the gesture haptic when an app comes to the front, and the lighter tick per selection change.
public enum Haptic: Sendable { case gesture, lightTick }

/// The multitouch hardware.
@MainActor public protocol TrackpadHardware: AnyObject {
    /// Always called on the main actor, in the order each trackpad's frames produced the events, and never for a session
    /// that a later `run` replaced. A `.windowSwipe(.began)` asks whether its slide is a window swipe. Once the call
    /// returns, the adapter answers that start, true only if `confirmWindowSwipe(on:)` was called during it, and the
    /// trackpad's recognizer takes the answer before its next frame: confirmed, the slide blocks until both fingers
    /// lift; declined, it goes on as with the window swipe setting off.
    var onEvent: (@MainActor (TrackpadEvent) -> Void)? { get set }
    /// Trackpads connected now. Excludes multitouch devices that are not trackpads (Magic Mouse, Touch Bar).
    func connected() -> [Trackpad]
    /// Forgets every session, removes the click tap, stops every device, then starts exactly `trackpads` with a fresh
    /// recognizer each and, if `blockClicks` and `trackpads` is not empty, a fresh click tap. Idempotent.
    /// The tap needs Accessibility. If the system refuses it, nothing is filtered, presses are sampled as before,
    /// and taps behave exactly as without access. [] = nothing runs. `slides`: the slide kinds each fresh recognizer
    /// recognises; `swaps`: whether it recognises swaps. Replacing the recognizers ends any swipe in progress.
    func run(_ trackpads: [Trackpad], handMode: HandMode, blockClicks: Bool, slides: Set<SlideKind>, swaps: Bool)
    /// One pulse of that kind on that trackpad. No-op if it is gone.
    func playFeedback(_ haptic: Haptic, on trackpad: TrackpadID)
    /// Only while `onEvent` is handling a `.windowSwipe(.began)` from `trackpad`: makes that slide a window swipe.
    /// Anywhere else, including an event a test injected, it does nothing.
    func confirmWindowSwipe(on trackpad: TrackpadID)
}

/// The two trackpad preference domains.
@MainActor public protocol TrackpadPreferences: AnyObject {
    /// Called on the main actor after any table key changes in either domain.
    var onChange: (@MainActor () -> Void)? { get set }
    /// Current raw values of every table key, per kind, read fresh. Reads only; never writes a system domain.
    func current() -> [TrackpadKind: TrackpadPreferenceValues]
}

/// Effects the core decides and macOS performs.
@MainActor public protocol SystemActions: AnyObject {
    /// Bring to front: launch, or unhide / restore / reopen / activate exactly like a Dock click.
    func bringToFront(_ app: AppEntry)
    /// The apps the next launch animations and launch bounces may be for. Each call replaces the previous set. Readies
    /// whatever a later `playLaunchAnimation` or `bringToFrontBouncing` for one of them needs now, so that call does no
    /// slow work.
    func prepareLaunchAnimations(for apps: [AppEntry])
    /// For an app with a process. Returns at once. Reads the pointer, the displays and Reduce motion at the moment of the
    /// call, plays for about a third of a second and removes itself. Every call plays its own and never cancels,
    /// restarts or reuses one already playing. A launch bounce's ending plays the same animation inside the adapter.
    /// Nothing it shows activates Trackpad Launcher, becomes key or receives a click.
    func playLaunchAnimation(for app: AppEntry)

    // A gesture that launches its app shows the launch bounce.
    //
    // The model decides everything: which visual a gesture gets, which bounces are live (keyed by bundle ID) and how
    // each one ends. The SystemActions adapter shows each bounce, watches its launch, keeps its time, and reports
    // LaunchProgress through `onLaunchProgress`. A report for an app with no live bounce does nothing.
    //
    //   fire, no process:      system.bringToFrontBouncing(app, cap: 10 s)   // opens the app first, then the bounce
    //   .finishedLaunching:    system.limitLaunchBounce(of: id, to: 2 s)
    //   .windowShown:          system.endLaunchBounce(of: id, with: .launchAnimation)
    //   .wentNowhere:          system.endLaunchBounce(of: id, with: .quietFade)
    //   .ranOut:               either ending, by how far the launch got
    //
    // Time is the adapter's: `.ranOut` arrives at the cap, or at the limit set once the app finished launching,
    // whichever comes first. Tests push it like any other report.

    /// Whether macOS reports a process for the app now, still launching or finished, menu bar apps included; unlike
    /// `runningApps()`, not the ⌘-Tab list. Under 0.1 ms; reads only.
    func hasProcess(_ app: BundleID) -> Bool

    /// Bring to front for an app with no process, with its launch bounce. Opens the app exactly as `bringToFront`
    /// does, first, so the bounce never delays it; then, before returning, shows its icon bouncing just above the
    /// pointer and following it, in one row with any other bounce, newest on the right. Watches that launch and pushes
    /// `onLaunchProgress` for it until `endLaunchBounce`, `.ranOut` at `cap` at the latest. Reads the pointer, the
    /// displays, Reduce motion and the tuning at the call. Nothing it shows activates Trackpad Launcher, becomes key or
    /// receives a click. A bounce it cannot show runs out on the next main-actor turn. One bounce per app: for an app
    /// whose bounce still plays it only brings the app to front.
    func bringToFrontBouncing(_ app: AppEntry, cap: Duration)

    /// From now on the bounce runs out within `limit` at the latest; never later than its cap or an earlier limit.
    /// No-op for an app whose bounce is not playing.
    func limitLaunchBounce(of app: BundleID, to limit: Duration)

    /// Ends the bounce from wherever the icon is, stops watching its launch and pushes nothing more for it; the icon no
    /// longer follows the pointer, and the others close up over about 0.2 s. Once the last bounce has ended nothing of
    /// ours remains: no row panel, no monitor, no observer. Idempotent: a no-op for an app whose bounce is not playing.
    func endLaunchBounce(of app: BundleID, with ending: LaunchBounceEnding)

    /// On the main actor, only for an app whose bounce plays: `.finishedLaunching` at most once, then at most one of
    /// the others before `endLaunchBounce`. Nothing for a launch Trackpad Launcher did not start.
    var onLaunchProgress: (@MainActor (BundleID, LaunchProgress) -> Void)? { get set }

    /// The active app and the ⌘-Tab apps, read now from their one source of truth.
    func runningApps() -> RunningApps
    /// The frontmost app's windows, read now, beside `runningApps()`: about a millisecond, at most one messaging timeout
    /// (0.2 s) when the app does not answer. Reads only. The windows it lists are the only ones a later `raiseWindows`
    /// may name, until the next read.
    func frontmostWindows() -> FrontmostWindows
    /// Raises these windows of the latest `frontmostWindows()` read, the last first, so the first ends in front of its
    /// app with the keyboard focus and the rest behind it in this order; beside `bringToFront`, which is app-level. A
    /// raised minimised window is restored. A window that has closed is skipped; an id the latest read did not list is
    /// skipped, so nothing on another Space is ever raised. About 2 ms per raise; once the app has timed out, no
    /// further calls go to it for that read. [] does nothing.
    func raiseWindows(_ frontToBack: [WindowID])
}

/// A permission macOS grants the app.
public enum Permission: Hashable, Sendable {
    case accessibility, screenRecording
}

/// The permissions macOS grants the app. Real: SystemPermissions. Test: InMemoryPermissions.
@MainActor public protocol Permissions: AnyObject {
    /// On the main actor after either permission changed, and only then. Carries no data: re-read.
    var onChange: (@MainActor () -> Void)? { get set }
    /// Read fresh. Never prompts. Screen Recording's read costs about 4 ms, so the model reads it on pushes, never on a
    /// gesture.
    func isGranted(_ permission: Permission) -> Bool
    /// The system's prompt for it. Returns at once; the prompt belongs to another process.
    func ask(_ permission: Permission)
}

/// Reads the listed apps off the main actor and pushes the result. Real: SystemAppScanner. Test: InMemoryAppScanner.
@MainActor public protocol AppScanner: AnyObject {
    /// On the main actor with each finished scan.
    var onScan: (@MainActor (InstalledApps) -> Void)? { get set }
    /// Returns at once. Requests made while a scan runs coalesce into exactly one more scan after it.
    /// The scanner also scans by itself after an app is installed, removed or renamed, and at no other time.
    func scan()
}
