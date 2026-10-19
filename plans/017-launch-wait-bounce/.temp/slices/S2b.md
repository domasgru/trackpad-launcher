# S2b: A cold launch bounces above the pointer and ends on its launch, its failure or its time

(Slice S2 of the plan is built in two dispatches. S2a, already in the working tree, built the pure parts. This one wires them into the model, the `SystemActions` port, the real adapter, the launch watch and the bounce overlay. S2a and S2b are committed together as S2.)

## Goal

A gesture for an assigned app with no process bounces the app's icon above the pointer, with the haptic, instead of floating it up, and the app launches. Several cold launches bounce in one row, newest on the right. Each bounce ends with the launch animation 2 s after its app finished launching. It fades in place instead when the launch fails, the app quits, or 10 s pass while the app is still starting, and the other icons slide to their new places. A repeated gesture keeps the one bounce. Running apps keep the launch animation. Under Reduce motion the icon pulses.

Not in this slice: windows do not end a bounce yet (S3 adds the window look to `LaunchWatch`); the icon does not follow the pointer yet (S4 adds the pointer monitors; here the row stays where the pointer was when the row last changed); the tuner does not know the bounce yet (S5).

## Requirements

- **R1.** The launch bounce MUST play when a gesture fires for an assigned, present target app that is not running, while the launch animation setting is on. Not running means macOS reports no process for the app when the gesture fires. An app already launching from the Dock or Finder therefore counts as running and gets the launch animation (R2). The bounce MUST appear no later than the haptic feedback. It MUST replace the launch animation for that gesture: no launch animation plays when the gesture fires. Scenario: 2-finger gesture assigned to Figma, Figma not running → Figma's icon appears above the pointer and starts bouncing at once, with the gesture haptic, no icon floats up, and Figma launches.
- **R2.** A gesture whose target app is already running MUST play the launch animation exactly as today, with no launch bounce, unless that app's launch bounce is still playing (R14). This holds whether or not the app has a window. Scenarios: running app (Arc) → floats up; running app with no window (Mail) → launch animation; app launching from the Dock a second ago (Figma) → launch animation, no bounce.
- **R3.** A swipe, a window swipe and a swap MUST never play the launch bounce. Nothing else plays it either: an unassigned gesture, a missing assignment, gestures inactive, or the launch animation setting off. Scenario: setting off, Figma not running → no icon at any point, the haptic plays, Figma launches. Scenario: assigned app moved to the Trash → no icon.
- **R4.** The bouncing icon MUST be the target app's own icon, the one Finder shows for it, 60 × 60 points as shipped, with no blur or pixelation at any point of the bounce.
- **R5, R6.** (Row geometry; S2a's `BounceRow` computes it.) At rest the icon is centred on the pointer's tip, bottom 8 pt above it; near the top edge it is cut off by the display's edge, never below the pointer or onto another display; near the left/right edge it slides just enough to stay on the pointer's display.
- **R8.** Dock-like bounce, about half the icon's height, about 0.7 s per bounce, repeated until it ends (S2a's `BounceMotion`).
- **R10.** When the app has finished starting up and no window of it has shown within 2 seconds after that, the bounce MUST end with the launch animation, or earlier at the 10-second cap (R12). This covers menu bar apps, apps that open no window, and apps whose window opens on another Space.
- **R11.** The bounce MUST end without the launch animation when the app fails to launch, quits before a window shows, or is still starting up at the 10-second cap (R12). The icon MUST then fade out in place within about 0.2 seconds. Scenarios: macOS refuses to open it → bounces until macOS reports the failure, then fades where it is; app crashes during startup → bounces until it quits, then fades; app takes 15 s → at 10 s the icon fades, and the app's window still shows when ready.
- **R12.** No icon MUST bounce longer than about 10 seconds after its gesture fired. At the cap, if the app has finished starting up, the icon MUST play the launch animation. If the app is still starting up, the icon MUST fade out quietly (R11). A window that shows after the bounce has ended MUST play nothing. Scenario: menu bar app finishes starting up 9 s after the gesture → at 10 s the icon floats away.
- **R13.** Each gesture that launches a different app MUST get its own bouncing icon. Bouncing icons MUST sit in one row centred above the pointer, newest on the right, 12 points apart. When one ends, the others MUST slide to their new places over about 0.2 seconds. Each ends on its own app's events.
- **R14.** A gesture for an app whose launch bounce is still playing MUST NOT start a second bounce or restart the first. The gesture haptic MUST play, and the gesture's usual bring-to-front action MUST happen; for a launching app it asks macOS to open the app again, which changes nothing visible. No launch animation plays for that repeated gesture. Scenario: menu bar app has started up and is still bouncing; its gesture again → no icon floats up, the one icon keeps bouncing.
- **R15.** With Reduce motion on, the icon MUST stay at its resting spot and pulse its opacity instead of bouncing. Every ending MUST fade it out in place, as the launch animation does under Reduce motion.
- **R16.** The bouncing icon MUST never take focus or receive clicks. Clicks, scrolling and every gesture, swipe, window swipe and swap MUST work exactly as when no icon shows. The launcher window MUST close on the gesture as today.
- **R17.** Each knob shapes the bounce (S2a); each bounce snapshots `LaunchTuning.current` when it starts, so changes apply to the next bounce.

## Design

### Usage, the caller's view (put this as the README comment on the vocabulary file or `SystemActions`)

```swift
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
```

### `LauncherCore` · `SystemActions` (in `Ports.swift`)

Existing members unchanged except their docs. Remove `WorkspaceActions.bringToFront`'s comment "The completion is ignored: its only reactions would be a log line or a dialog" (its reason no longer holds). Add exactly these contracts:

```swift
    /// The apps the next launch animations and launch bounces may be for. (Text widened; behaviour as today.)
    func prepareLaunchAnimations(for apps: [AppEntry])
    /// As today, for an app with a process. Every call plays its own and never cancels, restarts or reuses one already
    /// playing. A launch bounce's ending plays the same animation inside the adapter.
    func playLaunchAnimation(for app: AppEntry)

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
```

(The "following it" clause is S4's; write the contract as given, since S4 follows within this branch.)

### `LauncherCore` · `Launcher` changes

```swift
// stored: @ObservationIgnored private var bounces: [BundleID: LaunchBounce] = [:]
//   The launches whose bounce plays. Written only by `fire` and `progress(_:of:)`: the one record of which
//   bounces are live (R14); the adapter's row follows its commands.

private enum Visual { case launchBounce, launchAnimation, none }

/// R1–R3, R14. Reads `hasProcess` only when it decides something.
private func visual(for app: AppEntry) -> Visual {
    // guard settings.isLaunchAnimationOn else { return .none }                    R3: setting off
    // if bounces[app.bundleID] != nil { return .none }                            R14: keep the one bounce
    // return system.hasProcess(app.bundleID) ? .launchAnimation : .launchBounce    R1, R2
}

private func fire(_ event: GestureEvent) {
    guard activity.isActive, let assigned = settings.assignments[event.gesture], let app = catalog.locate(assigned)
    else { return }
    hardware.playFeedback(.gesture, on: event.trackpad)
    switch visual(for: app) {                           // reads "has a process?" only when it decides something
    case .launchBounce:
        bounces[app.bundleID] = .startingUp
        system.bringToFrontBouncing(app, cap: LaunchBounce.cap)   // opens the app first, inside the call
    case .launchAnimation:
        system.bringToFront(app)
        // After bring to front, so whatever the animation costs lands on the icon, never on the app.
        system.playLaunchAnimation(for: app)
    case .none:                                         // the setting is off, or R14: this app's bounce still plays
        system.bringToFront(app)
    }
    window = .closed
}

// in start():
system.onLaunchProgress = { [unowned self] app, progress in self.progress(progress, of: app) }

private func progress(_ progress: LaunchProgress, of app: BundleID) {
    guard let bounce = bounces[app] else { return }     // the bounce ended: a late window plays nothing (R12)
    switch bounce.next(after: progress) {
    case .carryOn: break
    case .startUp(let limit):
        bounces[app] = .startedUp
        system.limitLaunchBounce(of: app, to: limit)
    case .end(let ending):
        bounces[app] = nil
        system.endLaunchBounce(of: app, with: ending)
    }
}
```

- The pulse is issued before the process read, so `fire`'s effect order is exactly today's. Swipes, window swipes and swaps never reach `fire` (R3 by construction). `window = .closed` on every path (R16).
- Update the `Launcher` class doc comment ("`fire` is the only path that pulses, launches, plays the launch animation…") to include the launch bounce.
- The key is the bundle ID, the identity assignments already use. Nothing iterates `bounces`.

### `LauncherPlatform` · `WorkspaceActions` changes

```swift
@MainActor public final class WorkspaceActions: SystemActions {
    private let overlay: LaunchOverlay
    private let bounces: BounceOverlay
    /// One per bounce playing, from `bringToFrontBouncing` to `endLaunchBounce`.
    private var launches: [BundleID: Launch] = [:]
    public var onLaunchProgress: (@MainActor (BundleID, LaunchProgress) -> Void)?

    private struct Launch {
        let watch: LaunchWatch
        var gate = LaunchReportGate()
    }

    public convenience init() { self.init(screen: ScreenRead.now) }

    /// Tests inject the pointer-and-displays read (for example, one with no display).
    init(screen: @escaping @MainActor () -> ScreenRead) {
        overlay = LaunchOverlay()
        bounces = BounceOverlay(flights: overlay, screen: screen)
        // one runningApplications(withBundleIdentifier:) now: the first in a process costs 1.65 ms, later ones < 0.1 ms.
    }

    /// Every report for a bounce, from its watch or its deadlines, passes the bounce's gate first.
    private func report(_ progress: LaunchProgress, of app: BundleID) {
        // guard var launch = launches[app], launch.gate.admits(progress) else { return }
        // launches[app] = launch; onLaunchProgress?(app, progress)
    }

    public func bringToFront(_ app: AppEntry) { open(app) }

    public func hasProcess(_ app: BundleID) -> Bool {
        // !NSRunningApplication.runningApplications(withBundleIdentifier: app.rawValue).allSatisfy(\.isTerminated)
    }

    public func bringToFrontBouncing(_ app: AppEntry, cap: Duration) {
        // let id = app.bundleID
        // guard launches[id] == nil else { return bringToFront(app) }
        // let report: @MainActor (LaunchProgress) -> Void = { [weak self] in self?.report($0, of: id) }
        // let watch = LaunchWatch(report: report); launches[id] = Launch(watch: watch)
        // open(app, then: watch.opened)                        // the app first: nothing below can delay it
        // bounces.start(app, cap: cap) { report(.ranOut) }
    }

    public func limitLaunchBounce(of app: BundleID, to limit: Duration) { bounces.limit(app, to: limit) }

    public func endLaunchBounce(of app: BundleID, with ending: LaunchBounceEnding) {
        launches.removeValue(forKey: app)?.watch.stop()
        bounces.end(app, with: ending)
    }

    /// One call reproduces a Dock click: launches, unhides, restores, reopens and activates. `opened`, when given, hears
    /// macOS's answer from any thread: the launched pid, or nil when it could not launch the app or the process
    /// ended before checking in (pid −1).
    private func open(_ app: AppEntry, then opened: (@Sendable (pid_t?) -> Void)? = nil)
    // NSWorkspace.shared.openApplication(at:configuration: activates = true, completionHandler:) — the completion maps
    // (runningApp, error) to: nil on an error, nil on a terminated app or pid -1, else the pid. Only the pid crosses.
}
```

- **No alerts on the user's screen from tests.** Opening a bundle macOS refuses (T35's bundle without an executable) shows a system alert "You can't open the application … because it may be damaged or incomplete" unless `NSWorkspace.OpenConfiguration.promptsUserIfNeeded` is false. The app keeps today's behaviour (the default, prompting), but the internal initialiser takes the choice so tests can turn it off: `init(screen: @escaping @MainActor () -> ScreenRead, promptsUser: Bool = true)`, used by `open(_:then:)`. Every test that constructs `WorkspaceActions`, or opens a probe itself, passes `promptsUser: false` / sets `promptsUserIfNeeded = false` (as `ProbeBundlesTests.aBundleWithoutItsExecutableIsRefused` now does). After the suite, no alert window may be left (check `CoreServicesUIAgent` has no window, e.g. via the window list).
- `bringToFrontBouncing` calls `open(_:then:)` **before** `bounces.start`: "bring to front before any animation work" is a contract the model cannot break.
- `bringToFrontBouncing` for an app whose bounce is live only brings it to front (one bounce per app). `endLaunchBounce` is idempotent.
- The Debug tuner's `showAnimationTuner()` stays as today in this slice (S5 adds the bounce preview).

### `LauncherPlatform` · `LaunchWatch` (new file `LaunchWatch.swift`) — this slice: without the window look

```swift
/// Watches one launch a gesture started, from macOS's answer to `openApplication` until `stop()`: the process's
/// finishing and ending by key-value observation, which macOS pushes for every kind of app. Reports each fact at most
/// once, nothing after `stop()`, and holds nothing once stopped.
@MainActor final class LaunchWatch {
    private let report: @MainActor (LaunchProgress) -> Void
    private var process: NSRunningApplication?
    private var observations: [NSKeyValueObservation] = []
    private var hasFinished = false
    private var isStopped = false

    init(report: @escaping @MainActor (LaunchProgress) -> Void) { self.report = report }

    /// macOS's answer, from any thread. Hops to the main actor with only the pid.
    nonisolated func opened(_ pid: pid_t?) {
        Task { @MainActor [weak self] in self?.adopt(pid) }
    }

    /// Invalidates the observations. Idempotent.
    func stop()

    private func adopt(_ pid: pid_t?) {
        // guard !isStopped
        // guard let pid, let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated
        //     else { return wentNowhere() }
        // observe \.isTerminated        [.initial, .new]: true -> Task { @MainActor } -> wentNowhere()
        // observe \.isFinishedLaunching [.initial, .new]: true -> Task { @MainActor } -> finished(pid)
    }

    private func finished(_ pid: pid_t) {
        // guard !isStopped, !hasFinished; hasFinished = true
        // report(.finishedLaunching)
        // (S3 adds, after `guard !isStopped`: the one look at the windows.)
    }

    private func wentNowhere() {
        // guard !isStopped; report(.wentNowhere)
    }
}
```

- `.initial` covers a completion that arrives after the app finished (a second open's answer arrives at finishing).
- Each KVO handler hops to the main actor, following the `SystemTrackpadPreferences` precedent (read it).
- Each report is the watch's last act, and a guard checks `isStopped` after it, so a report that ends the bounce re-entrantly is safe. `stop()` invalidates the KVO. Once no bounce is live, nothing observes anything.
- `wentNowhere` should report at most once even if both a nil answer and `isTerminated` arrive (the gate also guarantees it at the port; the watch should not rely on that).
- Facts this rests on (probed on this Mac; see `plans/017-launch-wait-bounce/.temp/architect/grounding/index.md` F7–F13 and `how-lifecycle.md`): the completion runs off the main thread when the app checks in (118–1838 ms after the call); a bundle that cannot launch answers with an error; a process that exits before checking in answers with a terminated app, pid −1; `isFinishedLaunching` / `isTerminated` KVO pushes for every app, menu bar apps included, while workspace notifications do not for menu bar apps.

### `LauncherPlatform` · `BounceOverlay` (new file `BounceOverlay.swift`) — this slice: without pointer monitors

```swift
/// Shows launch bounces. Every bouncing icon sits in one row above the pointer, in one display-sized click-through
/// panel on the pointer's display. Core Animation plays the bounce. Each bounce carries its own deadlines (1→1 opacity
/// animations on its clock layer), which pass on the render server's clock and die with the bounce. An ending lifts
/// the icon out of the row into its own panel. Once the row is empty and the last ending's completion has run, nothing
/// of ours runs.
@MainActor final class BounceOverlay {
    private let flights: LaunchOverlay
    /// The pointer and the displays, read at each start. `ScreenRead.now` in the app.
    private let screen: @MainActor () -> ScreenRead
    /// Oldest first: the row's order, newest on the right (R13).
    private var row: [Bouncing] = []
    /// The row's panel and the display it covers; nil while the row is empty.
    private var stage: (panel: NSPanel, host: CALayer, display: LaunchDisplay)?
    /// Quiet-fade panels, kept until their fade's completion (AppKit keeps closed panels in its window list).
    private var fading: Set<NSPanel> = []

    private struct Bouncing {
        let app: AppEntry
        /// `LaunchTuning.current` when it started: the tuner restores its override right after a preview.
        let tuning: LaunchTuning
        let reduceMotion: Bool
        /// Positioned at the icon's rest; follows the pointer (S4).
        let slot: CALayer
        /// Anchor at its bottom centre; plays `BounceMotion` forever.
        let icon: CALayer
        /// Zero-size; carries the deadlines.
        let clock: CALayer
        var deadlines: [Deadline]
        /// Called once, by the first deadline to pass; nil after.
        var ranOut: (@MainActor () -> Void)?
    }

    init(flights: LaunchOverlay, screen: @escaping @MainActor () -> ScreenRead)

    func start(_ app: AppEntry, cap: Duration, ranOut: @escaping @MainActor () -> Void) {
        // guard !row.contains { $0.app.bundleID == app.bundleID } else { return }
        // snapshot tuning, Reduce motion (system || tuning.forceReduceMotion); let read = screen()
        // guard let layout = BounceRow(count: row.count + 1, pointer: read.pointer, among: read.displays,
        //                              side: iconSide, tuning: tuning.bounce),
        //       let stage = stage(on: layout.display)       // LaunchOverlay.makePanel(frame: display.frame), ordered in
        //     else { Task { @MainActor in ranOut() }; return }  // nothing to show: runs out next turn
        // one CATransaction, actions disabled: slot at layout.rests.last; icon (side, bitmap from flights.bitmap,
        //     contentsScale = display scale, trilinear) + BounceMotion(...).animations(); clock + deadline(cap) ->
        //     runOut(app); slide the others to layout.rests.dropLast() (BounceRow.slide)
        // row.append(...)
    }

    func limit(_ app: BundleID, to limit: Duration) {
        // add a deadline of `limit` to that bounce's clock; the cap stays, so a later limit never extends it
    }

    func end(_ app: BundleID, with ending: LaunchBounceEnding) {
        // guard let index = row.firstIndex(where: app) else { return }            // idempotent
        // let bouncing = row.remove(at: index); bouncing.deadlines.forEach { $0.isCancelled = true }
        // let frame = the icon's presentation frame in global coordinates (presentation layer → slot → host → panel)
        // one outer CATransaction:
        //     .launchAnimation: flights.play(for: bouncing.app, from: frame.centre, among: screen().displays)
        //                                                                            // R9; Reduce motion fades in place
        //     .quietFade: own panel at frame ∩ display, a layer frozen at the presentation transform and opacity,
        //                 BounceMotion.quietFade(from:), closed from its completion   // R11
        //     bouncing.slot.removeFromSuperlayer(); slide the rest to their new rests  // R13
        // if row.isEmpty { close the row panel }
    }

    #if DEBUG
    /// R18: bounces `app` at the pointer for `duration`, then ends it as a window showing would.
    func preview(_ app: AppEntry, for duration: Duration) {
        start(app, cap: duration) { [weak self] in self?.end(app.bundleID, with: .launchAnimation) }
    }
    #endif

    private func runOut(_ app: BundleID) {
        // guard let i, let ranOut = row[i].ranOut; row[i].ranOut = nil; ranOut()
    }

    /// A deadline on the render server's clock. A cancelled one reports nothing. A stop the system causes
    /// (`finished == false`, not cancelled) reports as passed, so no bounce can outlive its cap. Internal, so a test can
    /// drive its stop rule directly.
    @MainActor final class Deadline: NSObject, CAAnimationDelegate {
        var isCancelled = false
        let passed: @MainActor () -> Void
        init(passed: @escaping @MainActor () -> Void) { self.passed = passed }
        nonisolated func animationDidStop(_ animation: CAAnimation, finished: Bool) {
            MainActor.assumeIsolated { if !isCancelled { passed() } }
        }
    }
}
```

Rules for this file:

- **The row panel** is one panel the size of the pointer's display, made with `LaunchOverlay.makePanel(frame:)` (click-through, non-activating, `.screenSaver` level, on every Space), ordered in with `orderFrontRegardless()`. Because the panel is the display, R6's cut at the top edge comes free and nothing spills onto a display above. Layer positions inside it are global coordinates minus the display's origin. Close it (and drop `stage`) when the row empties. If a new start finds the row on another display than the new layout's, re-frame the panel to the new display (S4 generalises this to moves).
- **Layers**: slot (positioned at the icon's rest, in panel coordinates) → icon (bounds `side × side`, `anchorPoint` (0.5, 0) so the transform is about its bottom centre, position at the slot's origin, `contents = flights.bitmap(for: app, scale: display.scale)`, `contentsScale` = display scale, `minificationFilter = .trilinear`, `allowsEdgeAntialiasing`) and clock (zero-size sublayer of the slot). The icon side is `LaunchTuning.iconSide` from the snapshot (60 shipped; the bitmap is the prepared 72 pt one, so it is never upscaled, R4). Under Reduce motion (system `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || tuning.forceReduceMotion`), `BounceMotion` gives the pulse.
- **Geometry**: the row's geometry uses the newest bounce's tuning snapshot (`row.last.tuning.bounce` after the append, i.e. the starting bounce's); each icon's motion uses its own snapshot.
- **Re-flow**: when the row changes (start or end), each icon that moves gets its slot's model position set to its new rest and an additive `BounceRow.slide(from: oldRest, to: newRest, over: tuning.bounce.slide)`.
- **Deadlines**: a deadline is a `CABasicAnimation(keyPath: "opacity")` from 1 to 1 over the duration on the bounce's clock layer, delegate a `Deadline`, added inside a committed transaction while the layer is in the ordered-in panel. `start` arms the cap; `limit` adds another. Whichever passes first calls `runOut(app)`, which calls the bounce's `ranOut` closure once and clears it. The cap stays armed, so a later limit can never extend a bounce. Measured: about 1 ms late while the panel is composited, up to about 60 ms late when the row is cut off entirely at the top edge, about 90 ms late under `swift test`.
- **Ending a bounce** sets `isCancelled` on its deadlines **before** it removes the layer, so their stops report nothing. (Removing an animated layer fires the delegate with `finished == false` at the next commit.) A stop the system causes, with `finished == false` and no cancel, counts as passed.
- **Endings lift the icon out of the row**: `.launchAnimation` → `LaunchOverlay.play(for:from:among:)` at the icon's presentation centre (so it starts mid-jump if that is where the icon is; the flight begins with its usual swell from 60 pt toward 72 pt; under Reduce motion the flight is its own fade in place); `.quietFade` → a small panel (`makePanel`) at the icon's presentation frame cut to the display, holding a layer frozen at the presentation transform and opacity, fading with `BounceMotion.quietFade(from:)` over `fadeOut`, closed and removed from `fading` in the transaction's completion. Both endings build their new panel inside the same outer `CATransaction` that removes the slot, so the swap commits as one.
- **No display** (`BounceRow` init returns nil, or no panel): the bounce runs out on the next main-actor turn (`Task { @MainActor in ranOut() }`) rather than staying silent, so no model record can be stranded (a stranded record would make R14 swallow every later gesture for that app). Do not append it to the row.
- **R16**: the panel ignores mouse events; never key, never activates the app.
- Duration → seconds: use `Duration.components` (seconds + attoseconds / 1e18), or a small shared helper.
- Facts this rests on: `plans/017-launch-wait-bounce/.temp/architect/checks/p5-offscreen-clock.md` (deadlines survive a panel cut off at the top edge), `.../grounding/probes/p3-ca-clock.swift`, and `.../grounding/how-overlay.md`.

### Tests · `RecordingSystemActions` (in `Tests/LauncherCoreTests/InMemoryAdapters.swift`) and `World`

```swift
extension RecordingSystemActions {
    // stored: var processes: Set<BundleID> = []
    //   Processes ⌘-Tab does not show: menu bar apps, apps still starting from the Dock.
    // stored: private(set) var bounces: [Bounce] = []
    //   The bounces playing, in start order: the row, newest last. Every bringToFrontBouncing call appends, a repeated
    //   one too, so a second start shows; the fake does not copy the adapter's one-bounce-per-app guard.
    // stored: private(set) var bounceEndings: [BounceEnd] = []
    //   Every endLaunchBounce call, in order, so a double end shows.
    // stored: var onLaunchProgress: (@MainActor (BundleID, LaunchProgress) -> Void)?
    // stored: var onBringToFrontBouncing: (() -> Void)?
    //   Runs inside bringToFrontBouncing, like onPlayLaunchAnimation, so a test can see the other effects then.

    struct Bounce: Equatable {
        let app: AppEntry
        let cap: Duration
        /// Every limit the model set, in order. Recorded, not applied: which deadline passes first is the adapter's.
        var limits: [Duration] = []
    }

    struct BounceEnd: Equatable {
        let app: BundleID
        let ending: LaunchBounceEnding
    }

    /// Derived, never synced: a ⌘-Tab app and the frontmost app have a process too.
    func hasProcess(_ app: BundleID) -> Bool {
        // processes.contains(app) || frontmost?.bundleID == app || running.contains { $0.bundleID == app }
    }

    /// Records the bring to front, then the bounce, in that order.
    func bringToFrontBouncing(_ app: AppEntry, cap: Duration)
    /// Appends to that bounce's `limits`.
    func limitLaunchBounce(of app: BundleID, to limit: Duration)
    /// Records every call; removes a playing bounce.
    func endLaunchBounce(of app: BundleID, with ending: LaunchBounceEnding)
    /// The launch reports `progress` inline, as the real adapter pushes it on the main actor. A test withholds a report
    /// by not calling this, delivers one late by calling it after the end, and passes time with `.ranOut`.
    func report(_ progress: LaunchProgress, for app: BundleID) { onLaunchProgress?(app, progress) }
}
// World: report(_:for name:), startProcess(_ name:).
```

(These go in the class body where Swift requires stored properties.)

Existing tests change in two ways:
- The six positive `launchAnimations` expectations (`LauncherTests.swift` near lines 22, 52, 56, 62, 86 and `FiveFingerTests.swift` near line 19; find every `launchAnimations ==` with a non-empty value) gain a running app (e.g. the target in `world.system.running` or `startProcess`), which makes them R2 tests. Without that they would now bounce.
- The R3 negatives (unassigned gesture, missing assignment, inactive gestures, swipe, window swipe, swap, setting off) gain `bounces.isEmpty`.

### Tests · platform side

One serialized suite in `LauncherPlatformTests` (suggested name `LaunchBounceAdapterTests`, so `swift test --skip LaunchBounceAdapterTests` can leave it out), driving the real `WorkspaceActions` through the port's members, as `SystemTrackpadPreferencesTests.swift` and `SystemAppScannerTests.swift` drive their adapters: each push is awaited with a bound, never polled.

- **Launched apps are real**: S1's probe bundles (scripted startup from Info.plist, fresh bundle ID each, cleaned up even on failure).
- **A recording driver** set as `onLaunchProgress` logs `(time, app, progress)`. It ends the bounce re-entrantly (calls `endLaunchBounce`) on the terminal report a row names, as `Launcher.progress` does, and otherwise leaves it. It holds no policy.
- **Time is the render server's** and cannot be advanced. Rows pass short `cap` and `limit` values (hundreds of milliseconds) and bound each wait.
- **The screen read is injected** through `WorkspaceActions(screen:)`. A row sets the pointer in its `ScreenRead` (so the user's pointer never moves) and takes the displays from `NSScreen`. Where a row needs it, the read reports no display. Reduce motion is forced through `LaunchTuning`'s Debug `tunerOverride` (`forceReduceMotion`) where a row needs the icon at rest when it ends; restore it after the row.
- **Independent reads**: our own windows from the window list (owner pid = this test process, layer 1000, bounds), the probe's state from `NSRunningApplication`.
- The suite moves focus to probe apps and shows icons on screen. Expect about a minute.
- Feasibility already checked on this Mac under `swift test` with no `NSApplication`: a panel orders in; a committed animation's delegate fires (`finished == true`, ~90 ms late); the main run loop runs; `NSScreen` and `NSEvent.mouseLocation` answer; the window list shows our panel at layer 1000 until it closes.

## Rules that apply

- `docs/architecture.md`, Shape: "One `@MainActor @Observable` model owns every decision. Platform adapters sense and act behind small ports … Policy lives in pure functions and value types." The ending policy lives only in `LaunchBounce.next(after:)` and `Launcher.progress`; the adapter never ends a bounce by itself (it reports `.ranOut` and waits for `endLaunchBounce`). The one exception is the Debug preview, which has no model behind it.
- `docs/architecture.md`, Shape: "`LauncherCore` … imports Foundation and Observation only". "Framework and wire types never cross a port: … `NSRunningApplication`, `NSImage` stay inside adapters." `pid_t`, `NSRunningApplication`, `AXError`, `CALayer` stay in `LauncherPlatform`; durations cross as `Duration`.
- `docs/architecture.md`, Shape: "Every port has exactly two adapters: the real one in `LauncherPlatform` and an in-memory one in the tests … things that deliver asynchronously … sit behind a port so the model's tests stay synchronous." The push stays on `SystemActions`, no new port.
- `docs/architecture.md`, Concurrency: "No timers, no polling, no background loops: every input is a push (… and, only while a launch bounce shows, its launch's progress (`openApplication`'s answer, KVO on the launched process, an Accessibility window observer) and pointer moves). This is what keeps idle CPU at zero. Time passes only on Core Animation's clock: a deadline, such as a launch bounce's cap or its wait after the app finished launching, is an animation on a layer of the effect it belongs to, its completion is the push, and it cannot outlive that effect." The source scan bans the substrings `Timer`, `asyncAfter`, `Task.sleep`, `makeTimerSource`, `displayLink`, `DisplayLink` anywhere under `LauncherKit/Sources`, comments included; also `perform: {` and `nonisolated(unsafe)`.
- `docs/architecture.md`, Concurrency: "the model, the ports and the public surface of every real adapter are `@MainActor`." "Animation is Core Animation keyframes, which the render server plays. Whatever an animation leaves behind is cleaned up from its completion callback. No code of ours runs per display frame."
- `docs/architecture.md`, Concurrency: "The launch overlay, and the launch bounce, which shares its icons, likewise draw an icon at gesture time only when the off-main pass has not drawn one yet." Use `LaunchOverlay.bitmap(for:scale:)`, never a second cache.
- `docs/architecture.md`, Privacy: "No network code of any kind, no logging of any kind (`print`, `NSLog`, `os_log`, `Logger`), no files written other than settings in `UserDefaults`."
- `docs/domain-model.md`, **Launch bounce**: "The target app's icon bouncing just above the pointer while an app a gesture launched starts up, in place of the launch animation. It plays when a gesture fires for an assigned, present target app that is not running, while the launch animation setting is on. *Not running* means macOS reports no process for the app when the gesture fires: an app still starting up from the Dock or Finder, or a running menu bar app, has one and gets the launch animation. … A bounce ends with the launch animation, played from wherever the icon is, when a window of the app first shows (a splash screen counts), or 2 seconds after the app finished starting up with no window. It fades out in place within about 0.2 seconds instead when the launch fails, when the app quits, or when the app is still starting up 10 seconds after the gesture. No bounce lasts longer than 10 seconds, and a window that shows after a bounce ended plays nothing. … A gesture for an app whose bounce still plays keeps that one bounce: the haptic plays and the app is brought to front, and nothing else shows. With the system's Reduce motion setting on, the icon pulses its opacity at its resting spot instead of jumping, and every ending fades it out in place. It never takes focus or receives clicks. Only gestures play it: a swipe, a window swipe and a swap never do."
- `docs/domain-model.md`, **Launch animation**: "…when a gesture fires for an assigned, present target app that is running … for an app that is not running the launch bounce shows instead, and ends with the launch animation played from wherever its icon is … every gesture for a running app plays its own."
- `docs/domain-model.md`, **Launch animation setting**: "It covers both the launch animation and the launch bounce. While it is off, a gesture shows nothing at the pointer … A change applies to the next gesture, so a bounce already playing runs its course."
- `docs/domain-model.md`, **Bring to front**: "launch it if it is not running; otherwise unhide, restore minimised windows or open a new window as needed, and make it the active app. A gesture that launches its app shows the launch bounce while the app starts up."

## Tests

Model side (World over `RecordingSystemActions`; synchronous; the test owns the clock by pushing `.ranOut`):

| ID | Requirements | Seam | Given / When / Then | Source of truth |
|----|--------------|------|---------------------|-----------------|
| T1 | R1, R16 | World | Given Figma on the 2-finger gesture with no process, and the launcher window open. When `tap(2)`. Then `bounces == [Figma, cap 10 s, limits []]`, `broughtToFront == [Figma]`, `launchAnimations == []`, feedback `== [macBook14]`, and the window is closed. The `onBringToFrontBouncing` hook sees the feedback already recorded, so the pulse comes first, in the same turn. | R1 scenario; R16; today's effect order |
| T2 | R2 | World | Given the target has a process in each of four ways: in the ⌘-Tab list (Arc), frontmost only, a menu bar app (`startProcess`, never in ⌘-Tab), and an app launching from the Dock (`startProcess`). `FakeWindows` holds no window. When its gesture fires. Then `launchAnimations == [app]`, `bounces == []` and `broughtToFront == [app]`. The last two cases go red if the model reads `runningApps()` instead of `hasProcess`. | R2 scenarios |
| T3 | R2, R3 | World (existing rows) | Given the six rows that expect a launch animation (`LauncherTests` lines 22, 52, 56, 62, 86 and `FiveFingerTests` line 19), each with its target made running; and the rows for an unassigned gesture, a missing assignment, inactive gestures, a swipe, a window swipe and a swap. Then all keep their expectations, and the negatives also expect `bounces == []`. | The existing rows' literals; R3 |
| T4 | R3, R16 | World | Given the launch animation setting off, and Figma with no process. When `tap(2)`. Then `bounces == []`, `launchAnimations == []`, `broughtToFront == [Figma]`, one pulse, and the window is closed. | R3 scenario |
| T5 | R9 | World | Given Figma bouncing. When `.windowShown` is reported, once while `.startingUp` and once after `.finishedLaunching`. Then in both cases `bounceEndings == [Figma: .launchAnimation]` and `launchAnimations == []`, because the adapter plays the hand-off. A later `.windowShown`, `.ranOut` or `.wentNowhere` adds nothing to either history. | R9; R12 last sentence |
| T6 | R10 | World | Given Bartender, a menu bar app, bouncing. When `.finishedLaunching` is reported twice, then `.ranOut`. Then `limits == [2 s]` exactly, the repeat adding none, and `bounceEndings == [Bartender: .launchAnimation]`. | R10 menu bar scenario |
| T7 | R11 | World | Given Figma bouncing. When `.wentNowhere` arrives before finishing; or `.wentNowhere` after `.finishedLaunching` (a crash after startup); or `.ranOut` before finishing. Then each case ends with exactly `[Figma: .quietFade]` and no launch animation. | R11 scenarios |
| T8 | R12 | World | Given Xcode and Slack, both bouncing. Then each `bringToFrontBouncing` carried `cap == 10 s`. When Xcode has reported `.finishedLaunching` and its `.ranOut` arrives (R12's late menu bar app), Then it ends with `.launchAnimation`. When `.windowShown` arrives for Xcode again, or for an assigned app that never bounced (a launch from the Dock), Then every history is unchanged. | R12 literal 10 s; non-goal "launches Trackpad Launcher did not start" |
| T9 | R1, R14 | World | Given Figma's bounce has ended by `.windowShown`, by `.wentNowhere` or by `.ranOut`, and Figma still has no process. When `tap(2)` again. Then a new bounce starts with cap 10 s, so no record was stranded. | R1; "no model record can be stranded" |
| T10 | R13 | World | Given Xcode on 1 and Slack on 2, neither with a process. When `tap(1)`, then `tap(2)`, then `.windowShown` for Slack. Then before the report `bounces == [Xcode, Slack]` (start order, newest last). After it, `bounceEndings == [Slack: .launchAnimation]` and `bounces == [Xcode]`. Xcode's later `.ranOut` ends only Xcode. | R13 scenarios |
| T11 | R14, R16 | World | Given Figma bouncing and still with no process (the 60–440 ms before macOS lists it), and the launcher window reopened. When `tap(2)` again. Then `bounces.count == 1`, `broughtToFront == [Figma, Figma]`, `launchAnimations == []`, two pulses, and the window is closed. The same holds with Figma on gestures 1 and 2, tapped in turn. Without the record check this row goes red, because the fake records a second start. | R14 "Impatient second tap" |
| T12 | R14, R10 | World | Given Bartender bouncing, `.finishedLaunching` reported, then `startProcess` (listed now). When `tap(5)`. Then one bounce, no launch animation, and `broughtToFront.count == 2`. When `.ranOut` arrives, Then `.launchAnimation`: the bounce is still `.startedUp`, neither restarted nor reset. | R14 "Menu bar app started up, still bouncing" |
| T13 | R16, R2 | World | Given Figma bouncing and Arc running on the 1-finger gesture. When `tap(1)` fires and a swap brings an app to front. Then Arc gets its launch animation, the swap brings to front with no animation and no bounce, and Figma's bounce gets no ending and no limit. Goes red if any live bounce silences other gestures. | R16; R2 |

Pure / direct:

| ID | Requirements | Seam | Given / When / Then | Source of truth |
|----|--------------|------|---------------------|-----------------|
| T25 | R12 | `BounceOverlay.Deadline` | A deadline that is not cancelled calls `passed` from `animationDidStop` both with `finished == true` and with `finished == false` (a stop the system causes). A cancelled one calls nothing in either case. | "A stop the system causes … counts as passed, so no bounce can outlive its cap" |

Platform side (real `WorkspaceActions` / `LaunchWatch`, probe bundles, serialized):

| ID | Requirements | Seam | Given / When / Then | Source of truth |
|----|--------------|------|---------------------|-----------------|
| T29 | R1, R2 | `WorkspaceActions.hasProcess` | A probe bundle never launched gives false. Opened directly with `openApplication`, as the Dock would, with a 2 s slow start: true as soon as macOS lists the process (within 0.5 s), while `isFinishedLaunching` is still false. A menu bar probe gives true while `runningApps()` does not list it. After the probe is killed: false. | F7; `runningApps()` as the contrast |
| T30 | R11, R12 | `WorkspaceActions` | Given a probe that sleeps 5 s before `NSApplication` runs. When `bringToFrontBouncing(cap: 400 ms)`, with the driver ending on `.ranOut` with `.quietFade`. Then the history is exactly `[.ranOut]`, at 400–900 ms, and nothing follows in the next second. `hasProcess` is still true after the end: the app keeps starting. | R11 "still starting after 10 seconds", scaled |
| T31 | R10 | `WorkspaceActions` | Given a menu bar probe with no window, and `bringToFrontBouncing(cap: 5 s)`. When the driver answers `.finishedLaunching` with `limitLaunchBounce(to: 300 ms)` and ends on `.ranOut`. Then the history is `[.finishedLaunching, .ranOut]`, with the `.ranOut` 300–800 ms after the limit call, long before the cap. | R10 menu bar scenario, scaled |
| T32 | R12 | `WorkspaceActions` | Given a slow-start probe that reports nothing, and a driver that does **not** end on `.ranOut`. (a) Cap 500 ms, then at once `limit(to: 2 s)`: one `.ranOut`, at 500–1000 ms. (b) Cap 2 s, then `limit(to: 200 ms)`: one `.ranOut`, at 200–700 ms, and still only one at 2.5 s, after the cap has passed. | "a later limit can never extend a bounce"; "whichever passes first reports `.ranOut`, once" |
| T33 | R12, R14 | `WorkspaceActions` | Force the interleaving. Given a slow-start probe bouncing with cap 300 ms. When at 100 ms the test ends it with `.quietFade` and, in the same turn, calls `bringToFrontBouncing(cap: 2 s)` for the same app. Then no `.ranOut` arrives before 2 s, and one arrives at 2–2.5 s. Without the cancel flag, the removed deadline's stop at the next commit would run the new bounce out at once. | "Ending a bounce cancels its deadlines … before it removes the layer" |
| T34 | R11, R12 | `WorkspaceActions` | Force the interleaving. Given a probe that starts in 0.3 s with a window at finish. When the test ends the bounce in the same turn as `bringToFrontBouncing`, before macOS answers. Then nothing is reported for it until 1 s after the probe has finished launching, which the test sees through its own observation. | Port contract "pushes nothing more for it" |
| T35 | R11 | `WorkspaceActions` | Given (a) a bundle with no executable, or (b) a probe that exits 0.5 s in, before checking in. When `bringToFrontBouncing(cap: 5 s)`, and in a third run (a) with cap 500 ms and a driver that does **not** end on `.wentNowhere`. Then the history is exactly `[.wentNowhere]`, within 2 s, and nothing follows. In the third run nothing follows even when the cap passes: only the gate stands between that deadline and a second ending report. | R11 "fails to launch", "quits before a window shows" |
| T36 | R11, R12 | `WorkspaceActions` | Kill at random, 10 runs. Each run uses a fresh probe that checks in after 0.4 s, finishes 0.6 s later and opens a window 2 s after that. The test SIGKILLs it at a moment drawn uniformly from 0–1.4 s after macOS first lists it, and logs the seed (in the test's own failure message; no logging in Sources). Then each run's history is `[.wentNowhere]` or `[.finishedLaunching, .wentNowhere]`, with `.wentNowhere` within 1 s of the kill and nothing after. | F11, F12 |
| T41 | R14 | `WorkspaceActions` | Given a menu bar probe bouncing whose `.finishedLaunching` has arrived. When `bringToFrontBouncing` is called again for it. Then no second `.finishedLaunching` arrives within 1 s, and our window list holds one row panel. | Port contract "One bounce per app" |
| T42 | R6, R9, R11, R13 | `WorkspaceActions(screen:)` with the tip at (700, 400) on the `NSScreen` displays, + window list | Given two slow-start probes bouncing. Then our windows at layer 1000 are exactly one, framed as the display holding the tip. When the first ends with `.quietFade`, Then a second window of about 60 × 60 appears and is gone within 0.5 s, while the row stays. When the second ends with `.launchAnimation`, Then the row window is gone and a flight window larger than the icon appears and is gone within 0.6 s. A second `endLaunchBounce` for it adds nothing. 1 s later no window of ours remains. | R11 0.2 s; R13 one row; flight 0.34 s |
| T43 | R5, R6, R11, R13 | `WorkspaceActions(screen:)` with the tip set by the row on the `NSScreen` displays, + window list, Reduce motion forced | Given one slow-start probe bouncing with the tip at (700, 400). When it ends with `.quietFade`, Then the fade window is 60 × 60 with its bottom centre at (700, 408). With the tip 10 pt from the right edge, its right edge is the display's. With the tip 30 pt below the top edge, the display's top edge cuts it and its bottom is at tip + 8. With two bounces, ending the older one puts its window's centre 36 pt left of the tip. With Reduce motion off and the bounce ended mid-jump, its bottom is between tip + 8 and tip + 38, centred on the tip. | R5 8 pt; R6 10 pt; R13 12 pt; R11 "in place" |
| T44 | R12 | `WorkspaceActions(screen:)` with a `ScreenRead` that reports no display | When `bringToFrontBouncing(cap: 5 s)`. Then nothing is reported during the call, one `.ranOut` arrives on the next main-actor turn, no window of ours appears, and nothing follows. | "A bounce it cannot show runs out on the next main-actor turn" |
| T46 | R10, R11 | `LaunchWatch`, pid withheld | Withhold and inject. The test opens a menu bar probe itself and keeps the pid from `opened(_:)`. (a) Delivered after the app has finished launching: exactly `[.finishedLaunching]`, through the `.initial` observation. (b) Delivered after the app was killed: `[.wentNowhere]`. (c) Delivered after finishing, with `stop()` called from a main-actor task the test enqueues right after the pid, so it runs between the adoption and the finishing hop the adoption enqueued: nothing. (d) `stop()` called before the pid is delivered: nothing, through the probe's finishing plus 1 s. | Lifecycle steps 3 and 6 |

Verified without a test (owned by this slice; report what you could and could not check):
- **R1 (review).** `bringToFrontBouncing` calls `open(_:then:)` before `BounceOverlay.start`.
- Manual checks for R1, R4, R8, R11, R15, R16 and R10's menu bar app need a human at the Mac with a Debug build; leave them, the orchestrator reports them.

## Starting point

- S1 (committed): `ScreenRead` and `ScreenRead.now()` and `LaunchDisplay.containing(_:among:)`, in `LaunchFlight.swift`; `LaunchOverlay.play(for:from:among:)`; internal `LaunchOverlay.bitmap(for:scale:)` and `LaunchOverlay.makePanel(frame:)`; set-valued `Confined.onlyIn`.
- S1's probes: a test-only `.executableTarget` `LaunchProbe` at `LauncherKit/Tests/LaunchProbe/main.swift` reads a `ProbeScript` dictionary from its bundle's Info.plist; keys `preSleep`, `crashAfter`, `windowWillFinish`, `windowDidFinish`, `windowAfter`, `splash`, `blockInWillFinish`, `markerThenBlock`, `statusLevelWindow` (see the file's header comment); a menu bar app is the same with `LSUIElement`. `LauncherKit/Tests/LauncherPlatformTests/ProbeBundles.swift`: `ProbeBundles.withProbes { probes in … }` builds one ad-hoc-signed bundle per script with a fresh bundle ID, `makeWithoutExecutable()` builds one with no executable, push-based bounded waits for `finishedLaunching` and `terminated`, and on exit (even a failure) terminates, unregisters and deletes everything. `ProbeBundlesTests.swift` shows usage. Extend the helper where these rows need more (e.g. a wait for "macOS lists the process").
- S2a (in the working tree, uncommitted): `LaunchProgress`, `LaunchBounceEnding`, `LaunchBounce` (with `Step`, `cap`, `grace`, `next(after:)`) in `LauncherCore`; `LaunchReportGate` in `WorkspaceActions.swift`; `BounceRow` (+ `slide`), `BounceMotion` (+ `quietFade`, `period`, `animations`); `LaunchTuning.Bounce` and `LaunchTuning.bounce`. Files: `Sources/LauncherCore/LaunchBounce.swift`, `Sources/LauncherPlatform/BounceStaging.swift`, `LaunchReportGate` at the bottom of `WorkspaceActions.swift`; tests `Tests/LauncherCoreTests/LaunchBounceTests.swift` and `Tests/LauncherPlatformTests/LaunchBounceTests.swift` (rename the latter to `BounceStagingTests.swift`, suite name to match, so two files in the package do not share a name). `LaunchDisplay` is now `Equatable`. S2a's choices: squash is full at the instant of landing and eases to none across the rest phase; the Reduce motion pulse is a cosine between 1 and `pulseLow`; a row wider than its display is anchored to the left edge; `BounceMotion.init` takes `side` but does not use it (drop the parameter if it stays unused). Read `git status` / `git diff` for exact names. The full suite was green after S2a (613 tests); `SpotlightLastUsedTests` has been seen flaking on this Mac, unrelated to this work.

## Resuming after a crash

An earlier implementer of this brief was killed mid-run. Its work is in the working tree, uncommitted, and is close to complete: `LaunchBounce.swift`, `BounceOverlay.swift`, `LaunchWatch.swift`, the `Launcher`/`Ports`/`WorkspaceActions` changes, the fake and World surface, `LaunchBounceFiringTests.swift`, `LaunchWatchTests.swift`, `LaunchBounceAdapterTests.swift`, and a helper file `Tests/LauncherPlatformTests/BounceBench.swift` (rename it if its name does not say what it holds). Review it against this brief rather than starting over; finish what is missing and fix what is wrong.

The gate run on that state: 644 tests, 3 issues, all in `LaunchBounceAdapterTests.swift`:
- `hasProcessIsTrueFromTheMomentMacOSListsTheProcessAndFalseOnceItIsGone` (line 24): `isFinishedLaunching` was already true when the row expected false (T29's slow start is not slow enough, or the read is too late).
- `aBounceEndedBeforeMacOSAnswersHearsNothingMoreForIt` (line 138): the test's own app handle was nil (T34).
- `aRowIsOnePanelOnThePointersDisplayAndEachEndingLeavesNothingBehind` (line 236): the row window's frame was not what the row expected (T42; it checks a width of 132, while the brief says the row panel is the size of the pointer's display: decide which the code and test should be, from the Design section).

Find the real cause of each (reproduce, do not loosen bounds to pass), then run the full gate twice to see that the platform rows are stable.

## Done when

- [ ] The launch bounce vocabulary, `LaunchBounce` with its `Step` table, `Launcher.bounces`, `visual(for:)`, the three-way `fire`, and `progress(_:of:)` installed in `start()`, as designed.
- [ ] `SystemActions` gains `hasProcess`, `bringToFrontBouncing(_:cap:)`, `limitLaunchBounce(of:to:)`, `endLaunchBounce(of:with:)` and `onLaunchProgress`, with the design's contract text. `RecordingSystemActions` and `World` gain the surface above.
- [ ] `WorkspaceActions` warms `hasProcess` in its internal `init(screen:)`, behind the public convenience `init()` that reads `ScreenRead.now`. It implements `open(_:then:)` and keeps one `Launch`, a watch plus its `LaunchReportGate`, per bounce. Every report, from the watch or from the deadlines, passes `report(_:of:)`.
- [ ] `LaunchWatch` runs without the window look: the answer, both observations, `stop()`.
- [ ] `BounceOverlay(flights:screen:)` runs without pointer monitors: the row panel, `BounceRow` rests, `BounceMotion`, the deadlines (`BounceOverlay.Deadline`, internal) with their fail-safe, both endings, the re-flow slide, and the Debug `preview`.
- [ ] `Ports.swift` carries the contract text and loses "the completion is ignored". The banned-token scan stays green.
- [ ] T1–T13, T25, T29–T36, T41–T44, T46 pass, plus S2a's tests.
- [ ] The quick gate is green: `Scripts/test.sh` (runs `swift test` in `LauncherKit`).
