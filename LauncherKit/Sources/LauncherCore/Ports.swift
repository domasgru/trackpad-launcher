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
    /// Forgets every session, removes the click tap, stops every device, then starts exactly the trackpads in
    /// `trackpads`, each with a fresh recognizer anchoring the thumb in that entry's corner and, if `blockClicks` and
    /// `trackpads` is not empty, a fresh click tap. Idempotent.
    /// The tap needs Accessibility. If the system refuses it, nothing is filtered, presses are sampled as before,
    /// and taps behave exactly as without access. [] = nothing runs. `options`: what each fresh recognizer
    /// recognises. Replacing the recognizers ends any swipe in progress.
    /// `blockTapClicks`: presses that arrive while a lift window is open are blocked; only meaningful together with
    /// `blockClicks`.
    func run(
        _ trackpads: [TrackpadRun], blockClicks: Bool, blockTapClicks: Bool, options: RecognizerOptions)
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
    /// Hides every running app with a Dock icon whose bundle identifier is not kept (every copy of a kept app stays),
    /// on every display and Space, full-screen apps included; menu bar apps stay. Trackpad App itself is included
    /// while its Dock icon shows (its settings window is open), unless it is kept. Idempotent; needs no permission;
    /// returns at once. Nothing hides until `kept.front` is active and no longer hidden, whichever comes last, and
    /// within about 3 s or not at all; a later call replaces the goal and hides whatever this one had not. Hides that do
    /// not land are sent again within about half a second, while `kept.front` stays in front; a pass that finds
    /// `kept.beside` in front hides nothing and the run goes on.
    func hideOtherApps(keeping kept: KeptApps)
    /// The apps the next launch animations and launch bounces may be for. Each call replaces the previous set. Readies
    /// whatever a later `playLaunchAnimation` or `bringToFrontWatching` for one of them needs now, so that call does no
    /// slow work.
    func prepareLaunchAnimations(for apps: [AppEntry])
    /// For an app with a process. Returns at once. Reads the pointer, the displays and Reduce motion at the moment of the
    /// call, plays for about a third of a second and removes itself. Every call plays its own and never cancels,
    /// restarts or reuses one already playing. A launch bounce's ending plays the same animation inside the adapter.
    /// Nothing it shows activates Trackpad App, becomes key or receives a click.
    func playLaunchAnimation(for app: AppEntry)

    // A gesture that launches its app watches the launch.
    //
    // The model decides everything: which visual a gesture gets, which launches are watched (keyed by bundle ID), how
    // each one ends and whether the others hide after it. The SystemActions adapter watches each launch, shows its
    // bounce when asked, keeps its time, and reports LaunchProgress through `onLaunchProgress`. A report for an app
    // whose launch is not watched does nothing.
    //
    //   fire, no process:      system.bringToFrontWatching(app, cap: 10 s, bouncing: the launch animation setting)
    //                                                                   // opens the app first, then the watch
    //   .finishedLaunching:    system.limitLaunch(of: id, to: 2 s)
    //   .windowShown:          system.endLaunch(of: id, with: .launchAnimation), then, when the gesture's hide setting
    //                          was on and the app is frontmost, system.hideOtherApps(keeping: KeptApps(front: id))
    //   .wentNowhere:          system.endLaunch(of: id, with: .quietFade)
    //   .ranOut:               either ending, by how far the launch got; never a hide
    //
    // Time is the adapter's: `.ranOut` arrives at the cap, or at the limit set once the app finished launching,
    // whichever comes first. Tests push it like any other report.

    /// A split gesture's bring to front, in one call so the order is the adapter's to keep: brings the app `focus` does
    /// not name to front, then opens the one it names, activated, before anything else, each as `bringToFront` opens
    /// an app, except that the other app is activated only when it is `.running` and `secondEntry` is `.focused`, and
    /// when `.unfocused` is only unhidden while it has a window to show. So the focused app ends active with its front
    /// window on top, and an app that finishes launching never takes the focus from it; for a moment afterwards, the
    /// other app taking the focus by itself gives it back. Then each watch asked for (`cap`; reports through
    /// `onLaunchProgress`; one watch per app), then the bounces, the first app's first, then the launch animations;
    /// each app sways toward its side, a bounce's ending included.
    func bringToFront(_ split: SplitArrival, cap: Duration)

    /// The display under the pointer now; nil with none. Reads only.
    func pointerDisplay() -> DisplayID?

    /// The half of the display's usable area the pointer is over now, by the line between a split's halves: `.left`
    /// left of it or off the display. Reads only.
    func pointerSide(on display: DisplayID) -> SplitSide

    /// Puts the app's front window in that half, if the app runs and has one, and returns at once: the work runs away
    /// from the main actor and answers nothing, ever. A full-screen window leaves full screen first; a window that
    /// cannot take the half's size keeps the closest it allows, at the half's top-left corner (`.left`) or top-right
    /// corner (`.right`). A window already there is left alone; a later call for the same app wins. Needs
    /// Accessibility: the caller checks it.
    func placeFrontWindow(of app: BundleID, in half: ScreenHalf)

    /// Whether macOS reports a process for the app now, still launching or finished, menu bar apps included; unlike
    /// `runningApps()`, not the ⌘-Tab list. Under 0.1 ms; reads only.
    func hasProcess(_ app: BundleID) -> Bool

    /// Bring to front for an app with no process, watching its launch. Opens the app exactly as `bringToFront` does,
    /// first, so the watch never delays it; then watches that launch and pushes `onLaunchProgress` for it until
    /// `endLaunch`, `.ranOut` at `cap` at the latest. When `bouncing`, also, before returning, shows its icon bouncing
    /// just above the pointer and following it, in one row with any other bounce, newest on the right; it reads the
    /// pointer, the displays, Reduce motion and the tuning at the call, and nothing it shows activates Trackpad
    /// Launcher, becomes key or receives a click. With no display to bounce on, the watch runs as usual and only the
    /// icon is missing. When not bouncing, nothing shows. One watch per app: for an app whose launch is watched it only
    /// brings the app to front.
    func bringToFrontWatching(_ app: AppEntry, cap: Duration, bouncing: Bool)

    /// From now on the launch's watch runs out within `limit` at the latest; never later than its cap or an earlier
    /// limit. No-op for an app whose launch is not watched.
    func limitLaunch(of app: BundleID, to limit: Duration)

    /// Stops watching the launch and its clock and pushes nothing more for it. When its bounce shows, ends it from
    /// wherever the icon is with `ending`: the icon no longer follows the pointer, and the others close up over about
    /// 0.2 s; otherwise ignores `ending`. Once the last watch has ended nothing of ours remains: no row panel, no
    /// monitor, no observer. Idempotent: a no-op for an app whose launch is not watched.
    func endLaunch(of app: BundleID, with ending: LaunchBounceEnding)

    /// On the main actor, only for an app whose launch is watched: `.finishedLaunching` at most once, then at most one
    /// of the others before `endLaunch`. Nothing for a launch Trackpad App did not start.
    var onLaunchProgress: (@MainActor (BundleID, LaunchProgress) -> Void)? { get set }

    /// The active app and the ⌘-Tab apps, read now from their one source of truth.
    func runningApps() -> RunningApps
    /// The frontmost app's windows, read now on the main actor and held to `deadline` in all: each call into the app
    /// waits at most what is left, and a read that ends past it is `.unanswered`. Never reads Trackpad App
    /// (`.ownProcess`). The windows it lists are the only ones a later `raiseWindows` may name, until the next read.
    func frontmostWindows(within deadline: Duration) -> FrontmostWindows
    /// Reads each app's windows away from the main actor, each on its own, all held to `deadline` from this call, and
    /// returns. `answer` runs on the main actor exactly once per slot of `apps`, inside this call or later, in no set
    /// order: `.unanswered` for an app that did not answer in time, stopped answering partway or no longer runs;
    /// `.ownProcess` for Trackpad App. A slow or hung app delays no other. Nothing these reads list is ever raised.
    /// The caller checks Accessibility.
    func readWindows(
        of apps: [AppEntry], within deadline: Duration,
        answer: @escaping @Sendable @MainActor (_ slot: Int, _ read: WindowRead) -> Void)
    /// Raises these windows of the latest `frontmostWindows()` read, the last first, so the first ends in front of its
    /// app with the keyboard focus and the rest behind it in this order; beside `bringToFront`, which is app-level. A
    /// raised minimised window is restored. A window that has closed is skipped; an id the latest read did not list is
    /// skipped, so nothing on another Space is ever raised. About 2 ms per raise; once the app has timed out, no
    /// further calls go to it for that read. [] does nothing.
    func raiseWindows(_ frontToBack: [WindowID])
    /// Which of `windows` the window server still holds, on any Space, minimised or not: about 0.2 ms. Window numbers
    /// are never reused, so one missing here has closed (or its app quit).
    func openWindows(among windows: Set<WindowID>) -> Set<WindowID>
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

/// The running Trackpad App processes. Real: SystemRunningCopies. Test: InMemoryRunningCopies.
@MainActor public protocol RunningCopies: AnyObject {
    /// Every other running Trackpad App, Debug or release, read now.
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

/// Putting this copy into /Applications. Real: ApplicationsInstaller. Test: InMemoryInstaller.
@MainActor public protocol Installer: AnyObject {
    /// Copies this copy into /Applications, replacing any Trackpad App there whatever its version. Nothing there
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

/// Whether a network path exists. Real: SystemConnection. Test: InMemoryConnection.
@MainActor public protocol Connection: AnyObject {
    var onChange: (@MainActor (Bool) -> Void)? { get set }
    /// Pushes the present reading, then every change, until `stop`. Nothing runs before or after.
    func watch()
    func stop()
}

/// Sparkle, and the restart that follows it. No Sparkle type or feed value crosses this port; a version crosses only as
/// `AppVersion`. Real: SparkleEngine. Test: InMemoryUpdateEngine.
@MainActor public protocol UpdateEngine: AnyObject {
    var onEvent: (@MainActor (UpdateEngineEvent) -> Void)? { get set }
    /// An update cycle read the list and found `version`, the newest newer version; nothing has downloaded. True: the
    /// download begins. False: nothing downloads and nothing is remembered (Sparkle's *dismiss*, never its *skip*);
    /// `.cycleEnded` follows, whose outcome the model ignores. Asked at most once per update cycle, inside Sparkle's
    /// callback, answered at once. Never asked for a probe, nor for an update Sparkle is already installing (a crash's
    /// leftover, which the engine skips itself). Unset: false.
    var shouldDownload: (@MainActor (AppVersion) -> Bool)? { get set }
    /// Reads the list and downloads nothing. Answers once, `.cycleEnded`. Never asked while a cycle runs.
    func probe()
    /// Reads the list, asks `shouldDownload`, downloads, refuses an ungenuine archive before any installer exists, asks
    /// for an administrator when this user cannot replace the bundle, prepares it and pushes `.held`; the update
    /// installs at this process's end. `.cycleEnded` follows only when `.held` is never reached, the offer is declined
    /// or the held update is discarded. Never asked while a cycle runs.
    func update()
    /// Stops the held update: the installer is cancelled, then Sparkle's cycle ends `.failed`.
    func discardHeldUpdate()
    /// Arms the job that opens whichever copy /Applications holds once this process has ended: silently, or with its
    /// settings window. The caller ends the process in the same turn. False: nothing is armed.
    func armRestart(opensWindow: Bool) -> Bool
}
