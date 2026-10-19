## Design

### Problem

A gesture that launches its app should show that app's icon bouncing above the pointer until a window shows, then float it away; today `Launcher.fire` cannot tell a launch from an activation, nothing reports a launched app's lifecycle to the model, the model has no clock, the overlay's only contract is fire-and-forget, and nothing of ours tracks the pointer. Four constraints shape the answer. `fire` must keep its guarantees: the pulse and the first visible icon in one synchronous main-actor turn, bring to front before any icon work. The model must stay synchronous and clock-free, with every asynchronous thing behind a port and faked inline in tests; `Timer`, `asyncAfter`, `Task.sleep` and display links are banned by substring, comments included (F23), and the only precise clock we have is a Core Animation completion on a layer in an ordered-in window (F24). The lifecycle signals that exist are the `openApplication` completion (check-in, failure, early death: F9–F11), KVO on `isFinishedLaunching` / `isTerminated` for every kind of app (F12, F13), and an `AXObserver` for the first window, registrable only at about finishing launching and only with Accessibility (F16–F19); `NSRunningApplication.runningApplications(withBundleIdentifier:)` is the process read (F7), blind for the first 60–440 ms after our own launch, so R14 needs the model's own record. `AXUIElement` is confined to one file, `LauncherCore` imports only Foundation and Observation, and the tuner's `preview(_:play:)` restores the live tuning as soon as `play` returns, so a seconds-long bounce must snapshot its tuning (F25).

### Usage (caller's view)

The model asks macOS to bring the app to front and learns from the same call whether that launched it. For a launch it shows the bounce with its 10 s cap, and from then on reacts to pushed events for that app: finished launching, a window shown, failure, a limit elapsed. Each reaction is one port call or nothing. The adapter owns everything below: the process read, following the launch, the row of icons glued to the pointer, the clock, the hand-off into the launch animation.

```swift
// Launcher.fire: the decision, in the same turn as the pulse. Bring to front first, as today.
hardware.playFeedback(.gesture, on: event.trackpad)
let brought = system.bringToFront(app)                      // .activated or .launched
if settings.isLaunchAnimationOn { showIcon(brought, for: app) }
window = .closed

private func showIcon(_ brought: BringToFront, for app: AppEntry) {
    guard bounces[app.bundleID] == nil else { return }      // R14: one bounce per app, nothing else shows
    switch brought {
    case .launched:
        bounces[app.bundleID] = LaunchBounce(app: app)
        system.showLaunchBounce(for: app, limit: LaunchBounce.cap)
    case .activated:
        system.playLaunchAnimation(for: app)                // R2, exactly as today
    }
}

// Launcher: the lifecycle, one handler installed in start(). The pure state machine says what to do.
system.onLaunchBounce = { [unowned self] id, event in
    guard var bounce = bounces[id] else { return }          // a bounce that ended hears nothing (R12)
    switch bounce.receive(event) {
    case .keep: bounces[id] = bounce
    case .limit(let seconds): bounces[id] = bounce; system.limitLaunchBounce(for: bounce.app, to: seconds)
    case .end(let ending): bounces[id] = nil; system.endLaunchBounce(for: bounce.app, ending)
    }
}
```

```swift
// A model test, through World, synchronous. Time and lifecycle are pushes the fake delivers inline.
let world = World(apps: ["Figma"])
world.launcher.start()
world.launcher.setAssignment(.app(world.app("Figma")), for: .two)
world.tap(2)
#expect(world.system.launchBounces == [world.app("Figma")])
#expect(world.system.launchAnimations.isEmpty)
#expect(world.system.limits(of: "Figma") == [10])
world.system.launch(.finishedLaunching, of: world.app("Figma"))
#expect(world.system.limits(of: "Figma") == [10, 2])
world.system.launch(.limitReached, of: world.app("Figma"))
#expect(world.system.endings == [(world.app("Figma"), .floatAway)])
world.system.launch(.windowShown, of: world.app("Figma"))   // after the end: nothing
#expect(world.system.endings.count == 1)
```

```swift
// The Debug tuner's preview (R18), bypassing the model as today's preview does: Finder for 3 s, then as a window would.
tuner = AnimationTuner(
    preview: { [overlay] in overlay.play(for: finder) },
    previewBounce: { [overlay] in
        overlay.showBounce(for: finder)
        overlay.after(3, for: finder) { overlay.endBounce(for: finder, .floatAway) }
    })
```

### Shape

**Data first.** The model's new state is `bounces: [BundleID: LaunchBounce]`: one value per app whose bounce shows, keyed by the assignment identity (bundle ID, the `Switcher` precedent). `LaunchBounce` is a two-state machine (`starting` → `started` on finished launching) whose `receive(_:)` maps an event to one effect: keep, add a limit, or end with `.floatAway` or `.fade`. R9–R12 are its six transitions and nothing else; the 10 s cap and 2 s grace are its constants. The deadline push carries no label: a limit reached while `starting` can only be the cap (fade), while `started` it is the cap or the grace (float away either way), so "earliest limit wins" needs no arithmetic and the "started at 9 s" case (R12) falls out: the model adds a 2 s limit and the cap's 10 s limit is still there. `BringToFront` is the one new fact `bringToFront` returns. Framework types stay inside adapters (per boundary-discipline): the check-in crosses to the main actor as Sendable facts (pid, quit, failed), and the AX element never leaves its file.

**The port.** `SystemActions` gains three methods, one push and one return type. `bringToFront` now answers whether it launched the app: it reads the process list (1.65 ms once, warmed at adapter init; under 0.1 ms after) and attaches the completion to the `openApplication` it issues, which is the only way to learn a launch failed (F10, F11). Fusing the read into the action is deliberate: a separate `isRunning` would make the model coordinate two calls for one operation, and the adapter would not know which launch to follow. `showLaunchBounce(for:limit:)` folds the cap into the show, so a bounce without a cap is unrepresentable (per encode-lessons-in-structure). `limitLaunchBounce(for:to:)` adds an earlier limit; `endLaunchBounce(for:_:)` ends with one of two endings. `onLaunchBounce` is the first push on `SystemActions`; it stays on this port because its source is the completion of this port's own `bringToFront` and the clock of this port's own bounce, so a second port would make two adapters coordinate one `openApplication`. Behind that surface the adapter hides: the process read, following a launch (completion → KVO → AX registration with two bounded retries), the row panel and its geometry, pointer following across displays, the CA keyframes, the CA clock, the mid-jump hand-off into the launch animation, the icon cache, and cleanup to zero. Learning the port does not require learning any of it.

**Time.** The clock is Core Animation, as the house style says, placed where F24 says it works: a no-op animation on a hidden clock layer in the bounce's row panel, which is ordered in for exactly as long as any deadline is wanted. `LaunchOverlay.after(_:for:_:)` is the one primitive: it runs an action after N seconds of that app's bounce, or never if the bounce ends first (the item's layers go, the completion fires `finished == false`, a generation guard drops it; the `OverlayPanel.dismiss` precedent). The cap, the grace, the tuner's 3 s and the AX retry ticks are all `after`. Nothing is cancelled: a later limit simply never fires because the end removed the layer. The model never sees a clock; tests push `.limitReached` themselves (F23, F26). Reading of D4: the CA clock, scoped to the bounce, which exists only while something is on screen.

**The pointer.** `PointerFollow` installs an NSEvent global monitor and a local monitor for mouse moves and drags (F20: no permission, 3.5 ms median; the local one covers our own windows) while any bounce shows and removes them with the last; each event reads `NSEvent.mouseLocation` and reframes the row. Per event: `BounceRow.placed(at:among:)` (pure) picks the pointer's display, computes the row's reach, slides it inside the left and right edges and clips it at the top (R6), and the shell sets the panel's frame and the row host layer's position with actions disabled (0.1 ms, F21). Reading of D1 relied on: *input-driven* work is a push like a trackpad frame (plan 006 F27); what the rule forbids is code driven by the display refresh. Reading of D2: we read the pointer's position on pointer-move events, only while a bounce shows, to place an icon, and never record or alter them; the click tap stays untouched (T76 holds). Both readings go into `docs/architecture.md` in Phase D and D2 needs the human's sign-off.

**The motion.** `BounceMotion.jump(_:)` is one repeating `CAKeyframeAnimation` on `transform` (translate y, optional squash scale about the bottom edge), sampled at 240 Hz as the flight is: a decelerating rise to `jumpHeight`, a gravity fall, a rest, `repeatCount = .infinity`; the icon layer's anchor is its bottom centre so squash keeps the feet down. `pulse(_:)` is the Reduce motion opacity loop (R15). The hand-off (R9, R11): `BounceRowPanel.release(_:)` reads the icon's presentation transform, converts to a screen point, removes the icon (the others slide to their new rest spots over 0.2 s, R13) and returns the point; the overlay then plays a departure in its own fresh panel exactly as `play` does today, `flight.staged(at: point, among:)` for `.floatAway` (already takes a start point) or a plain opacity fade over `fadeOut` for `.fade`; under Reduce motion both are fades in place. Icons come from the existing prepared cache at 60 pt (R4; the 72 pt peak bitmap covers squash up to 0.2).

**The lifecycle.** `LaunchWatches` follows one launch per bundle: `follow(id)` marks interest (called by `showLaunchBounce`, so the setting off follows nothing); `checkedIn(_:for:)` (the completion, hopped to main) adopts the pid, installs KVO on `isFinishedLaunching`, `isTerminated`, `isActive`, and tries `LaunchWindowWatch`; `stop(id)` removes all of it (called by `endLaunchBounce`). AX registration is tried at check-in, at activation, at finishing launching, and on two ticks after finishing (50 ms, 250 ms; F16 says it succeeds within 0–10 ms of the finish) before giving up to R10's rule. `LaunchWindowWatch` lives in its own file beside `FrontmostAppWindows.swift`; the `AXUIElement` confinement gains that second file. Without Accessibility every registration fails and R9 degrades to R10 (O1). Signals after an end are dropped twice: the adapter has stopped following, and the model has no record.

**The tuner.** `LaunchTuning.bounce: BounceTuning` nests R17's ten knobs; the `knob` helper's key path type admits `\.bounce.jumpHeight`. The bounce snapshots `LaunchTuning.current` at `showBounce` (F25). Tolerant decoding: `bounce` missing → shipped (R19); `BounceTuning` has its own tolerant `init(from:)` for later knobs. A round-trip test of a tuning with every field changed catches the missing-decode-line class of bug the current decoder admits.

**What the design does not do.** No separate setting (non-goal). No bounce from swipes or swaps: they discard `bringToFront`'s result. No per-display-frame code. No observer, monitor, panel or watch after the last bounce ends. No change to `prepareLaunchAnimations`.

```swift
// MARK: LauncherCore

/// What `bringToFront` found when it was called.
public enum BringToFront: Equatable, Sendable {
    /// macOS reported a process for the app: it was unhidden, restored, reopened or activated.
    case activated
    /// macOS reported no process: the app was launched. An app launching from the Dock already has a process
    /// 60–440 ms after its open, so it reads `.activated`; for that long after it does not.
    case launched
}

/// One app's launch bounce, from its gesture until an ending: R9–R12 as a state machine. The model holds one per
/// bouncing app; the adapter shows it, follows the launch and keeps its clock.
public struct LaunchBounce: Equatable, Sendable {
    /// No bounce lasts longer than this after its gesture (R12).
    public static let cap: Double = 10
    /// A started app with no window floats away this long after it finished starting (R10).
    public static let grace: Double = 2

    /// What the adapter pushes about a bounce, through `SystemActions.onLaunchBounce`.
    public enum Event: Equatable, Sendable {
        /// The app finished starting up (every kind of app, menu bar apps included).
        case finishedLaunching
        /// A window of the app, splash screens included, is about to be or is on screen. Needs Accessibility.
        case windowShown
        /// The launch is over without an app: it could not be launched, or it quit before its bounce ended.
        case failed
        /// A limit set by `showLaunchBounce` or `limitLaunchBounce` elapsed. Which one is not said: the model knows.
        case limitReached
    }

    public enum Ending: Equatable, Sendable {
        /// The launch animation from wherever the icon is (R9, R10, R12 started).
        case floatAway
        /// Out in place within about 0.2 s, no float-up (R11).
        case fade
    }

    /// What the model does with an event.
    public enum Effect: Equatable, Sendable {
        case keep
        /// Ends no later than this many seconds from now, by the adapter's clock.
        case limit(seconds: Double)
        case end(Ending)
    }

    private enum Startup: Equatable, Sendable { case starting, started }

    public let app: AppEntry
    private var startup: Startup = .starting

    public init(app: AppEntry) { self.app = app }

    /// The six transitions. A window ends it however far the launch got; failure ends it quietly; finishing
    /// launching starts the grace; a limit while still starting can only be the cap, so it fades; a limit once
    /// started is the cap or the grace, both float away. Finishing launching twice changes nothing.
    public mutating func receive(_ event: Event) -> Effect {
        switch (event, startup) {
        case (.windowShown, _): return .end(.floatAway)
        case (.failed, _): return .end(.fade)
        case (.finishedLaunching, .starting):
            startup = .started
            return .limit(seconds: Self.grace)
        case (.finishedLaunching, .started): return .keep
        case (.limitReached, .starting): return .end(.fade)
        case (.limitReached, .started): return .end(.floatAway)
        }
    }
}

/// Effects the core decides and macOS performs, plus the one push about a launch the core asked to follow.
@MainActor public protocol SystemActions: AnyObject {
    /// Bring to front: launch, or unhide / restore / reopen / activate exactly like a Dock click. Answers which it
    /// was from the process list at the call. When it launched, the launch's check-in, failure and early death reach
    /// `onLaunchBounce` only if `showLaunchBounce` follows for that app; otherwise they are dropped.
    @discardableResult func bringToFront(_ app: AppEntry) -> BringToFront
    func registerLoginItem()
    func prepareLaunchAnimations(for apps: [AppEntry])
    /// Returns at once. Reads the pointer, the displays and Reduce motion at the moment of the call, plays for about
    /// a third of a second and removes itself. Every call plays its own animation and never cancels, restarts or
    /// reuses one already playing. Nothing it shows activates Trackpad Launcher, becomes key or receives a click.
    func playLaunchAnimation(for app: AppEntry)
    /// Returns at once. Shows the app's icon bouncing above the pointer and following it, in the row with any other
    /// bouncing icons (newest on the right), with the launch animation's icon size, and follows the launch
    /// `bringToFront` just started for that app: from now its events reach `onLaunchBounce`, and `.limitReached`
    /// comes `limit` seconds from now unless the bounce ends first. A second call for an app already bouncing
    /// changes nothing. Reads Reduce motion and the tuning at the call and keeps them for this bounce.
    func showLaunchBounce(for app: AppEntry, limit seconds: Double)
    /// Adds an earlier limit: `.limitReached` also comes `seconds` from now. Nothing for an app not bouncing.
    func limitLaunchBounce(for app: AppEntry, to seconds: Double)
    /// Ends the bounce: the icon leaves the row, the others close up over about 0.2 s, and it departs from
    /// wherever it is, mid-jump included: `.floatAway` plays the launch animation from there, `.fade` fades it
    /// there within about 0.2 s; with Reduce motion both fade in place. Stops following the launch: nothing more
    /// reaches `onLaunchBounce` for it. Once the last bounce has ended nothing of ours remains: no panel, no
    /// pointer monitor, no observer. Nothing for an app not bouncing.
    func endLaunchBounce(for app: AppEntry, _ ending: LaunchBounce.Ending)
    /// On the main actor, for an app whose bounce shows: its launch's events and its limits, in the order they
    /// happen. Never after `endLaunchBounce` for that app.
    var onLaunchBounce: (@MainActor (BundleID, LaunchBounce.Event) -> Void)? { get set }
    func runningApps() -> RunningApps
    func frontmostWindows() -> FrontmostWindows
    func raiseWindows(_ frontToBack: [WindowID])
}

/// Launcher: the additions. `bounces` is effect state like the prepared icons, rendered by the adapter, so it is
/// not observed.
extension Launcher {
    // @ObservationIgnored private var bounces: [BundleID: LaunchBounce] = [:]

    // In start(), beside the other handlers:
    //     system.onLaunchBounce = { [unowned self] id, event in launchBounce(event, for: id) }

    /// Every silent case decided here and only here: inactive, unassigned, missing. The icon decision follows bring
    /// to front, so whatever the icon costs lands on the icon, never on the app.
    private func fire(_ event: GestureEvent) { fatalError("not implemented") }
    //     guard activity.isActive, let assigned = ..., let app = catalog.locate(assigned) else { return }
    //     hardware.playFeedback(.gesture, on: event.trackpad)
    //     let brought = system.bringToFront(app)
    //     if settings.isLaunchAnimationOn { showIcon(brought, for: app) }
    //     window = .closed

    /// Which icon a gesture shows: nothing while the app's bounce still plays (R14), the bounce for a launch
    /// (R1), the launch animation otherwise (R2).
    private func showIcon(_ brought: BringToFront, for app: AppEntry) { fatalError("not implemented") }

    /// The one place a bounce's events become effects. An event for an app with no bounce is dropped: it ended.
    private func launchBounce(_ event: LaunchBounce.Event, for id: BundleID) { fatalError("not implemented") }
    //     guard var bounce = bounces[id] else { return }
    //     switch bounce.receive(event) { .keep → store; .limit → store + system.limitLaunchBounce;
    //                                    .end → remove + system.endLaunchBounce }

    // swipe(.ended) and swap(): `system.bringToFront(target)` with the result discarded (R3).
}
```

```swift
// MARK: LauncherPlatform, the real adapter

/// Sendable facts from `openApplication`'s completion, which runs off the main thread. The `NSRunningApplication`
/// itself is re-fetched by pid on the main actor.
struct LaunchCheckIn: Sendable {
    /// nil when there is no app (a failed launch).
    let pid: pid_t?
    /// The process already quit (pid -1, F11) or there was no process.
    let quit: Bool
    /// The completion carried an error (F10).
    let failed: Bool
}

@MainActor public final class WorkspaceActions: SystemActions {
    private let overlay: LaunchOverlay
    private let watches: LaunchWatches
    public var onLaunchBounce: (@MainActor (BundleID, LaunchBounce.Event) -> Void)?

    public init() {
        overlay = LaunchOverlay()
        // The watch's retry ticks ride the bounce's clock: a tick exists only while that app's bounce does.
        watches = LaunchWatches(tick: { [overlay] id, seconds, action in overlay.after(seconds, forBundle: id, action) })
        watches.onEvent = { [weak self] id, event in self?.onLaunchBounce?(id, event) }
        // TODO: warm the process read's first call (1.65 ms, F7) now, as FrontmostAppWindows warms the window list.
        fatalError("not implemented")
    }

    /// The process list decides. Launching attaches the completion, which only `LaunchWatches` reads: its only
    /// other reactions would be a log line or a dialog, as before.
    public func bringToFront(_ app: AppEntry) -> BringToFront {
        fatalError("not implemented")
        // let configuration = NSWorkspace.OpenConfiguration(); configuration.activates = true
        // guard NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID.rawValue).isEmpty else {
        //     NSWorkspace.shared.openApplication(at: app.url, configuration: configuration); return .activated }
        // NSWorkspace.shared.openApplication(at: app.url, configuration: configuration) { [watches] running, error in
        //     let checkIn = LaunchCheckIn(pid: running?.processIdentifier, quit: running?.isTerminated ?? true,
        //                                 failed: error != nil)            // only Sendable facts cross
        //     Task { @MainActor in watches.checkedIn(checkIn, for: app.bundleID) }
        // }
        // return .launched
    }

    public func showLaunchBounce(for app: AppEntry, limit seconds: Double) {
        overlay.showBounce(for: app)
        limitLaunchBounce(for: app, to: seconds)
        watches.follow(app.bundleID)
    }

    public func limitLaunchBounce(for app: AppEntry, to seconds: Double) {
        overlay.after(seconds, for: app) { [weak self] in self?.onLaunchBounce?(app.bundleID, .limitReached) }
    }

    public func endLaunchBounce(for app: AppEntry, _ ending: LaunchBounce.Ending) {
        watches.stop(app.bundleID)
        overlay.endBounce(for: app, ending)
    }

    #if DEBUG
    /// Debug builds only. The tuner's flight preview plays Finder at the pointer; its bounce preview bounces Finder
    /// for 3 s, then ends it as a window showing would.
    public func showAnimationTuner() { fatalError("not implemented") }
    #endif
}

/// Follows the launches the model is bouncing, one per bundle, and pushes what each did. Nothing exists for a
/// bundle between `stop` and the next `follow`; a check-in for a bundle not followed is dropped.
@MainActor final class LaunchWatches {
    var onEvent: (@MainActor (BundleID, LaunchBounce.Event) -> Void)?
    /// Runs the action after the seconds, or never if that bundle's bounce ends first: the bounce's clock.
    private let tick: @MainActor (BundleID, Double, @escaping @MainActor () -> Void) -> Void
    private var watches: [BundleID: LaunchWatch] = [:]

    init(tick: @escaping @MainActor (BundleID, Double, @escaping @MainActor () -> Void) -> Void) { fatalError("not implemented") }

    /// From now until `stop`, this bundle's launch is followed. Idempotent.
    func follow(_ id: BundleID) { fatalError("not implemented") }

    /// Drops the observers and the window watch. Idempotent; a later check-in is dropped.
    func stop(_ id: BundleID) { fatalError("not implemented") }

    /// The completion, on the main actor. Adopts the process once (a second `openApplication` for the same launch
    /// completes with the same pid, F8); `.failed` for an error or a process already gone.
    func checkedIn(_ checkIn: LaunchCheckIn, for id: BundleID) { fatalError("not implemented") }
    //     guard var watch = watches[id], watch.app == nil else { return }
    //     guard !checkIn.failed, !checkIn.quit, let pid = checkIn.pid,
    //           let app = NSRunningApplication(processIdentifier: pid) else { return push(id, .failed) }
    //     watch.app = app
    //     KVO (.initial, .new) on isFinishedLaunching → finished(id); isTerminated → push(.failed);
    //     isActive → tryWindows(id). Each callback: Task { @MainActor [weak self] in ... } (the KVO precedent).
    //     tryWindows(id)

    /// Finishing launching: push it, try the window watch now and on two ticks (F16: registration first succeeds
    /// within about 0–10 ms of this moment; a non-Cocoa app may be later, O7). After the last tick, R10's rule.
    private func finished(_ id: BundleID) { fatalError("not implemented") }
    //     push(id, .finishedLaunching); tryWindows(id)
    //     for seconds in [0.05, 0.25] { tick(id, seconds) { [weak self] in self?.tryWindows(id) } }

    /// Registers the AX window watch if the app answers now; a window already made (one-shot read at registration)
    /// or created later pushes `.windowShown` once.
    private func tryWindows(_ id: BundleID) { fatalError("not implemented") }
    //     guard var watch = watches[id], watch.windows == nil, let app = watch.app, !app.isTerminated else { return }
    //     guard let windows = LaunchWindowWatch(pid: app.processIdentifier,
    //                                           onWindow: { [weak self] in self?.push(id, .windowShown) }) else { return }
    //     watch.windows = windows
    //     if windows.hadWindow { push(id, .windowShown) }

    private struct LaunchWatch {
        var app: NSRunningApplication?
        var observations: [NSKeyValueObservation] = []
        var windows: LaunchWindowWatch?
    }
}

/// One launching app's windows through the Accessibility element API: an observer for window creation plus one read
/// of its windows at registration. Besides `FrontmostAppWindows.swift`, the only file that touches the element API.
/// Each call obeys the process-wide 0.2 s messaging timeout, so a hung app can hold the main actor that long (O8).
@MainActor final class LaunchWindowWatch {
    /// True when the app already had a window when the observer registered (made during launch: F16, splash
    /// included). The caller treats it as a window shown.
    let hadWindow: Bool

    /// nil when the app's AX server does not answer yet (before it finishes launching, `kAXErrorCannotComplete`) or
    /// Accessibility is missing. `onWindow` runs on the main actor for every `kAXWindowCreatedNotification`, any
    /// role or subrole: a splash counts (R9).
    init?(pid: pid_t, onWindow: @escaping @MainActor () -> Void) { fatalError("not implemented") }
    //     AXObserverCreate(pid, callback, &observer); AXObserverAddNotification(observer, app, kAXWindowCreated, refcon)
    //     refcon = Unmanaged.passUnretained(self); the @convention(c) callback hops nothing: the source is on the main
    //     run loop, so it runs on the main thread → MainActor.assumeIsolated { onWindow() }
    //     hadWindow = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute) count > 0

    /// Removes the run-loop source and the notification.
    isolated deinit { fatalError("not implemented") }
}
```

```swift
// MARK: LauncherPlatform, the overlay

extension LaunchOverlay {
    // private var row: BounceRowPanel?      // exists only while a bounce shows
    // private var pointer: PointerFollow?   // likewise

    /// The app's icon joins the row above the pointer and bounces (pulses under Reduce motion) with the tuning read
    /// now and kept. The first bounce creates the row panel and installs the pointer monitors. Idempotent per app.
    func showBounce(for app: AppEntry) { fatalError("not implemented") }
    //     guard row?.has(app.bundleID) != true else { return }
    //     let tuning = LaunchTuning.current, reduceMotion = accessibilityDisplayShouldReduceMotion || tuning.forceReduceMotion
    //     if row == nil { row = BounceRowPanel(); pointer = PointerFollow { [weak self] point in self?.row?.follow(point, displays) } }
    //     row.add(app, bitmap: { scale in bitmap(for: app, scale: scale) }, tuning: tuning.bounce, iconSide:, reduceMotion:)
    //     row.follow(NSEvent.mouseLocation, displays)

    /// The bounce's clock: `action` runs after `seconds` of this app's bounce, or never if it ends first.
    func after(_ seconds: Double, for app: AppEntry, _ action: @escaping @MainActor () -> Void) { fatalError("not implemented") }
    func after(_ seconds: Double, forBundle id: BundleID, _ action: @escaping @MainActor () -> Void) { fatalError("not implemented") }

    /// The icon leaves the row from wherever it is and departs in its own panel, as a flight played at a point does
    /// today. The row closes up; the last departure closes the row panel and removes the pointer monitors.
    func endBounce(for app: AppEntry, _ ending: LaunchBounce.Ending) { fatalError("not implemented") }
    //     guard let released = row?.release(app.bundleID) else { return }
    //     switch (ending, released.reduceMotion) {
    //     case (.floatAway, _): play(for: app, from: released.screenCentre)       // flights.next handles Reduce motion
    //     case (.fade, _): depart(app, from: released.screenCentre, fadingOver: released.tuning.fadeOut, opacity: released.opacity)
    //     }
    //     if row?.isEmpty == true { row = nil; pointer = nil }

    /// `play(for:)` becomes `play(for: app, from: NSEvent.mouseLocation)`: the staging already takes a start point.
    func play(for app: AppEntry, from point: CGPoint) { fatalError("not implemented") }
}

/// Mouse moves and drags while a bounce shows: a global monitor for other apps' windows and the desktop, a local one
/// for ours (F20). Delivers the pointer's position on the main actor. Removed on deinit, so nothing listens once
/// the row is gone. Never reads any other event and keeps nothing.
@MainActor final class PointerFollow {
    init(_ moved: @escaping @MainActor (CGPoint) -> Void) { fatalError("not implemented") }
    isolated deinit { fatalError("not implemented") }
}

/// The row panel: one borderless click-through panel (the launch panel's flags) holding a row host layer with one
/// icon layer per bounce, oldest on the left, each with its clock layer. Moves with every pointer position it is
/// given; the frame is the row's reach on the pointer's display, slid and clipped by `BounceRow`.
@MainActor final class BounceRowPanel {
    private struct Item {
        let app: AppEntry
        let icon: CALayer           // anchorPoint (0.5, 0): position is the bottom centre, squash keeps the feet down
        let clock: CALayer          // hidden, zero-size; its animations are the deadlines
        let tuning: BounceTuning    // the snapshot (F25)
        let reduceMotion: Bool
        let generation: Int         // guards stale clock completions
    }

    private var items: [Item] = []
    private var stage: BounceRowStage?
    var isEmpty: Bool { items.isEmpty }

    func has(_ id: BundleID) -> Bool { fatalError("not implemented") }

    /// Adds the icon at the right end with `BounceMotion.jump` (or `.pulse`) running, then lays the row out again.
    func add(_ app: AppEntry, bitmap: (CGFloat) -> CGImage?, tuning: BounceTuning, iconSide: CGFloat, reduceMotion: Bool) {
        fatalError("not implemented")
    }

    /// The per-event move: `BounceRow.placed(at:among:)`, then panel frame + host position with actions disabled;
    /// with `trailing` > 0 the host position animates over that long instead (the panel pads its reach for it).
    /// A display change updates each icon's `contentsScale` and bitmap.
    func follow(_ pointer: CGPoint, among displays: [LaunchDisplay]) { fatalError("not implemented") }

    /// A deadline: a 1 → 1 opacity animation of `seconds` on the item's clock layer in its own transaction; the
    /// completion runs `action` unless the item is gone or replaced (generation). Many may coexist; none is cancelled.
    func after(_ seconds: Double, for id: BundleID, _ action: @escaping @MainActor () -> Void) { fatalError("not implemented") }

    /// Removes the item and answers where its icon is right now. The others slide to their new rest spots over
    /// 0.2 s (an explicit position animation on each icon; the bounce lives on `transform`, so neither disturbs the
    /// other); the frame shrinks to the new reach from that animation's completion.
    func release(_ id: BundleID) -> Released? { fatalError("not implemented") }
    //     let presented = item.icon.presentation() ?? item.icon
    //     screenCentre = panel.frame.origin + host.position + presented.position + presented.transform applied to
    //                    (0, iconSide / 2); opacity = presented.opacity
    //     TODO: pixel-snap is the departure's job (staged(at:) does it).

    struct Released {
        let screenCentre: CGPoint
        let opacity: Float
        let tuning: BounceTuning
        let reduceMotion: Bool
    }
}

/// The row's geometry for a pointer, pure. Everything y up, global screen coordinates, as `LaunchFlight`.
struct BounceRow {
    let count: Int
    let iconSide: CGFloat
    let tuning: BounceTuning

    /// Where the row rests for a pointer at `pointer`: nil with no display. The row is centred on the pointer's x
    /// plus `horizontalOffset`, its icons `iconGap` apart, their bottoms `restingGap` above the tip (R5, R13). Its
    /// reach is the row plus the jump and the squash, padded sideways when `trailing` > 0. It slides sideways just
    /// enough to lie entirely on the pointer's display, then is cut by the display's top edge, never moved below the
    /// pointer (R6). Positions pixel-snap to the display's scale.
    func placed(at pointer: CGPoint, among displays: [LaunchDisplay]) -> BounceRowStage? { fatalError("not implemented") }
}

/// What `BounceRow.placed` decided: the panel frame and scale, and each icon's resting bottom centre in the
/// panel's coordinates, oldest first.
struct BounceRowStage: Equatable {
    let frame: CGRect
    let scale: CGFloat
    let restBottoms: [CGPoint]
}

/// The bounce's keyframes, pure, 240 samples a second like the flight's.
enum BounceMotion {
    /// One cycle on `transform`, repeated forever: up `timeUp` to `jumpHeight` slowing at the top (1 − (1 − t)²),
    /// down `timeDown` with gravity (t²), `rest` on the ground; on landing scale (1 + squash, 1 − squash) easing
    /// back during the rest. With the shipped squash of 0 the icon keeps its size and shape (R8).
    static func jump(_ tuning: BounceTuning) -> CAKeyframeAnimation { fatalError("not implemented") }
    /// Reduce motion: opacity 1 → 0.55 → 1 over one cycle, repeated forever; nothing moves (R15).
    static func pulse(_ tuning: BounceTuning) -> CAKeyframeAnimation { fatalError("not implemented") }
}

/// Every number that shapes the bounce; the shipped bounce is its defaults. Snapshotted when a bounce starts.
struct BounceTuning: Equatable, Sendable {
    /// Points the icon rises each jump: about half its side.
    var jumpHeight: Double = 30
    var timeUp: Double = 0.3
    var timeDown: Double = 0.3
    /// Seconds on the ground between jumps.
    var rest: Double = 0.1
    /// Scale lost in height and gained in width at landing, as a share. 0 = none.
    var squash: Double = 0
    /// Points between the pointer's tip and the icon's bottom edge at rest.
    var restingGap: Double = 8
    /// Points the row's centre sits right of the pointer's tip.
    var horizontalOffset: Double = 0
    /// Seconds the icon takes to catch up with the pointer. 0 = glued.
    var trailing: Double = 0
    /// Points between icons in the row.
    var iconGap: Double = 12
    /// Seconds a quiet ending takes to fade out.
    var fadeOut: Double = 0.2
}

extension LaunchTuning {
    // var bounce = BounceTuning()
    // In init(from:): bounce = try value(.bounce, s.bounce)   // key missing → shipped bounce (R19)
}

#if DEBUG
/// `BounceTuning`'s own tolerant decoder, so a knob added later keeps its shipped value in older saves.
extension BounceTuning: Codable {
    init(from decoder: any Decoder) throws { fatalError("not implemented") }
}

/// The tuner gains a "Launch bounce" section (ten `knob`s on `\.bounce.…`, a "Preview bounce (3 s)" button, a footer
/// saying changes apply to the next bounce) before the presets, and a second closure.
@MainActor final class AnimationTuner {
    init(preview: @escaping @MainActor () -> Void, previewBounce: @escaping @MainActor () -> Void) { fatalError("not implemented") }
}
#endif
```

```swift
// MARK: Tests

/// RecordingSystemActions, the in-memory adapter: scripted processes, recorded bounce calls, inline pushes.
@MainActor final class RecordingSystemActions: SystemActions {
    var onLaunchBounce: (@MainActor (BundleID, LaunchBounce.Event) -> Void)?
    /// Apps macOS reports a process for: `bringToFront` answers `.activated` for them and `.launched` otherwise.
    /// `World.makeRunning` adds its apps; `World.makeProcess` adds a menu bar app or one launching from the Dock.
    var processes: Set<BundleID> = []
    /// One entry per `showLaunchBounce`, in order.
    private(set) var launchBounces: [AppEntry] = []
    /// Every limit per app, in order: the cap first.
    private(set) var limits: [BundleID: [Double]] = [:]
    private(set) var endings: [(app: AppEntry, ending: LaunchBounce.Ending)] = []
    /// Shows without an ending yet.
    var bouncing: [AppEntry] { fatalError("not implemented") }
    /// The adapter's push, delivered inline.
    func launch(_ event: LaunchBounce.Event, of app: AppEntry) { onLaunchBounce?(app.bundleID, event) }
    func limits(of name: String) -> [Double] { fatalError("not implemented") }
}

/// SourcePolicyTests: `Confined.onlyIn` becomes a set of file names. AXUIElement → {FrontmostAppWindows.swift,
/// LaunchWindowWatch.swift}; CGWindowList unchanged; new: "mouseMoved" → {ClickTap.swift, PointerFollow.swift} and
/// "addGlobalMonitorForEvents" → {MenuBarShell.swift, PointerFollow.swift}, so every reader of pointer events is
/// named. No new banned token: nothing in the design spells Timer, asyncAfter, Task.sleep or a display link.
```

**Seams and tests.** The requirement scenarios run at the model seam: `World.tap` plus `RecordingSystemActions`, synchronous. R1–R3 and R14 read `launchBounces`, `launchAnimations`, `broughtToFront`, `feedback`, with `processes` scripting running, menu bar and Dock-launching apps; R9–R13 drive `launch(_:of:)` and assert `limits` and `endings`, and "after the end, nothing". Time is a push the test makes (`.limitReached`); Accessibility off is simply never pushing `.windowShown`; a lost or late signal is withheld or reordered. Pure platform tests in the `LaunchFlightTests` style decode `BounceMotion`'s keyframes (cycle about 0.7 s, peak about half the side within bounds, decelerating up and accelerating down, size constant at squash 0, opacity-only pulse) and check `BounceRow.placed` (rest spot R5, top clip and right-edge slide R6, two icons centred 12 pt apart newest right R13, external display scale) and `LaunchTuning` decoding (the real old preset JSON loads with the shipped bounce; a fully changed tuning round-trips). `LaunchWatches(tick:)` takes its clock, so an adapter test drives the retry ticks without waiting; `LaunchWindowWatch` and the completion path run only against throwaway bundles on a trusted Mac (the P1 technique) or manually.

**Contracts and docs that change.** `Ports.swift`: `bringToFront` answers and attaches the completion (the "ignored, log line or dialog" comment goes); `playLaunchAnimation`'s text stands but the glossary's "every fired gesture plays its own" gains the launch exception; the three bounce methods and the push as above. `docs/domain-model.md`: a *Launch bounce* entry (the text in the port docs, in glossary form), *Launch animation* amended, *Bring to front* says it reports launch or activation. `docs/architecture.md` Shape: `SystemActions` carries one push. Concurrency: "No code of ours runs per display frame; input-driven work (a trackpad frame, a pointer move while a launch bounce shows) is a push like any other" and "the one clock is Core Animation's: a deadline is an animation on a layer in a panel that exists only while something shows; its completion is the push". Privacy: Accessibility is also used "to learn when an app a gesture launched shows its first window, while its launch bounce shows"; "while a launch bounce shows the app reads the pointer's position on each pointer move to keep the icon above it, through NSEvent monitors that exist only then; it records nothing"; the element API is confined to two named files. `SourcePolicyTests`: the set-valued confinement. `LauncherTests.repeatedTapsWhileTheThumbStaysAnchoredFireEachTime` keeps passing (Arc and Figma are not processes in that World, so both bounce; the assertion moves from `launchAnimations` to `launchBounces`). Plan 004's two non-goals are reversed and said so.

### Synthesis decision

### Tradeoffs accepted

- We accept changing `bringToFront`'s contract (a return value and an attached completion) in exchange for one call per gesture that both acts and tells the model what it did, and an adapter that knows which launch to follow.
- We accept the first push on `SystemActions` in exchange for not splitting one `openApplication` across two adapters.
- We accept a Core Animation animation as the clock, tied to the bounce panel's lifetime, in exchange for no timer token, millisecond precision (F24) and deadlines that die with the bounce without cancellation code.
- We accept about 0.1 ms of our code per pointer move while a bounce shows (D1, input-driven reading) in exchange for an icon glued to the pointer; nothing runs per display frame and nothing after the last bounce.
- We accept reading pointer positions on pointer events while a bounce shows (D2) in exchange for R7, pending the human's sign-off and a Privacy line.
- We accept a second Accessibility file in exchange for one concern per file; the confinement table names both.
- We accept that without Accessibility R9 is not met and R10's 2 s rule ends the bounce (O1).
- We accept the 60–440 ms blind window after a Dock launch (F7), during which a gesture bounces an app the Dock is already launching.
- We accept two bounded retry ticks for AX registration after finishing launching (not polling: two tries, then R10's rule).
- We accept that the float-away starts with the flight's pop from the bounce's 60 pt, a small swell at hand-off.
- We accept a `trailing` experiment knob that pads the row panel's reach when non-zero; shipped trailing is 0 and pays nothing.
- We accept a nested `BounceTuning` with its own tolerant decoder, guarded by a round-trip test that catches a missing decode line.

### Alternatives considered

- **Adapter-owned endings:** one `showLaunchBounce(for:)` and the adapter knows the 2 s and 10 s rules and ends the bounce itself, pushing nothing. Smallest surface, but it moves R9–R12 out of the model, untestable through `World`, and breaks "every decision in the model". Rejected.
- **A separate read, `isRunning(_:)`, beside an unchanged `bringToFront`:** the model coordinates two calls for one operation and the adapter cannot tie the completion it needs for R11 to the bounce. Rejected.
- **A generic `Deadlines` port with a dispatch or `ContinuousClock` adapter:** general, but a hypothetical seam with one consumer, it contradicts F23's letter, and a CA adapter would need a window of its own that the bounce panel already provides. Rejected.
- **Timing by lazy checks against the next pushed event (plan 002's method):** a sleeping launch pushes nothing, so the cap never fires. Rejected.
- **A display-sized panel per display with layers moved inside:** the same per-event CPU (F21) but a display-sized backing store (about 24 MB at 2x) for the life of a bounce. Rejected for a small row panel moved per event.
- **A new `LaunchBounces` port protocol:** the bounce's events come from `bringToFront`'s completion; two ports would make two adapters coordinate one call. Rejected.

### Open questions and risks

- D2: do you accept reading the pointer's position on pointer-move events, only while a bounce shows and never recorded, as the Privacy section will say?
- D1: do you accept the architecture wording "input-driven work is a push; nothing runs per display frame" as the rule from now on?
- O1: without Accessibility a window never ends the bounce; it floats away 2 s after the app finished starting. Accept, or should the launcher window's Accessibility hint mention it?
- Is a `bringToFront` that returns `.activated` / `.launched` acceptable, or do you prefer the port to stay `Void` with a separate read despite the coordination it adds?
- Confinement: two Accessibility files (`FrontmostAppWindows.swift`, `LaunchWindowWatch.swift`) with a set-valued `Confined`, or one renamed file holding both?
- O7: two retry ticks (50 ms, 250 ms) for AX registration after finishing launching, or accept the 2 s degrade when the first try at the finish fails (F16 shows it can, by up to 10 ms)? Unprobed alternative: KVO on `ownsMenuBar` as a natural post-finish push.
- O8: a hung launching app can hold the main actor up to the 0.2 s messaging timeout at each AX call on the bounce path. Acceptable, as it is off the gesture's critical path?
- O4: does `kAXWindowCreatedNotification` fire for a window on another Space? If so that app floats away rather than waiting out R10; is that fine?
- O5: what the completion reports while the Gatekeeper dialog is pending or after a decline is unprobed; the design runs to the cap either way, as R11 accepts.
- R7 across displays and the visible lag against the hardware cursor cannot be checked on this Mac (F22); do you want the first manual check on a two-display setup before shipping?
- Debug builds play the saved tuner state (plan 014): manual checks of the shipped bounce must "Reset to shipped" first.
- Risk: whether a global NSEvent monitor keeps delivering with a full-screen app in front or under secure input is unprobed; the bounce would then stay where it was until the next delivered move.

### Next implementation step

Write `LaunchBounce` and the `SystemActions` additions in `LauncherCore`, extend `RecordingSystemActions` and `World`, and land the R1–R3, R9–R14 model tests red, before any platform code.
