## Design

### Problem

Plan 002 adds three things to a working app: taps that count every finger that touched and may last 400 ms (R1–R3), trackpad presses dropped for the first 3 seconds after a thumb anchors (R4–R8), and the one optional permission that makes dropping possible, followed live and explained in the window (R7, R9–R11). The shape is non-obvious because the two halves of click blocking live on different threads with different clocks: the R4 window is a fact of the recognizer's state and the frame clock on the multitouch thread, while the press arrives at a `CGEvent` tap on whatever run loop its mach port is scheduled on, carrying a `CGEventTimestamp` that may not share a base with `FrameTime` (grounding Q1: never compare them). R8 adds a third thread-crossing fact: the recognizer must treat a dropped press as no press, and nothing establishes whether `CGEventSource.buttonState` still reads a dropped press as down (open). Constraints that stay from plan 001: one `@MainActor @Observable` `Launcher` owning every decision; every port with exactly two adapters; `LauncherCore` on Foundation and Observation only; recognition on the frame thread with the frame timestamp as its only clock; one idempotent `reconcile()` that restarts every device; no timers, no polling; shared state behind a `Mutex` with one writer; rules enforced by `SourcePolicyTests`. Facts the design rests on: an active mouse-button tap needs Accessibility and returns nil without it (probed); tccd posts the Darwin notification `com.apple.tcc.access.changed` 30 ms after a TCC change on the main queue, and an untrusted process may post the same name itself (probed); matching down and up share `kCGMouseEventNumber` and `CGEventSetType` can rewrite an event (sourced); frames flow at ~100 Hz while any contact rests, so the 3-second expiry is observed on a frame (001 grounding); the shell refits the panel only through three triggers; `World` builds `Launcher` in two places and the composition root in a third.

### Usage (caller's view)

**README excerpt.** The recognizer now answers two questions per frame instead of one: `step(_:)` returns a `Recognition`, the gesture that fired on this frame (if any) and whether the gesture rules call for click blocking as of this frame (a thumb is anchored, under 3 seconds since it anchored, another finger is down). The hardware port's `run` takes one more fact, `clickBlocking`, and the real adapter installs the click tap when it is true and the permission allows it. The tap's pass-or-drop rule is a pure value, `PressFilter`: feed it every button event with whether blocking is in effect at that moment; it drops or passes a press whole and knows whether a press the system received is held. That last fact is what the frame stream reads as `TouchFrame.buttonDown` while the tap is live, so a dropped press is invisible to recognition and the recognizer's press rule does not change. A new port, `AccessibilityPermission`, reads trust fresh, pushes real changes, and shows the prompt. `Launcher` reads it in `reconcile()` like the other inputs, exposes `hasAccessibilityAccess` for the hint, arms blocking only while gestures are active and access is granted, and prompts once, on first launch, before opening the window.

```swift
// TrackpadLauncher app target: the composition root gains one adapter.
let launcher = Launcher(
    hardware: MultitouchTrackpads(),
    preferences: SystemTrackpadPreferences(),
    access: SystemAccessibilityPermission(),
    system: WorkspaceActions(),
    catalog: catalog,
    store: SettingsStore(defaults: .standard))
```

```swift
// LauncherCoreTests, the high seam: R7 + R8 + R9 + R11 through the whole app, synchronous.
@MainActor @Test func grantingAccessArmsBlockingAndAFirmTapOpensTheApp() {
    let world = World(apps: ["Arc"])                       // access not granted by default
    world.launcher.start()
    world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
    #expect(world.hardware.clickBlocking == false)          // R9 "Declined": gestures work, clicks are not blocked
    #expect(world.launcher.hasAccessibilityAccess == false) // R11: the hint shows

    world.access.set(granted: true)                         // the push: onChange → reconcile → run(clickBlocking: true)
    #expect(world.hardware.clickBlocking == true)
    #expect(world.launcher.hasAccessibilityAccess == true)

    // A firm 1-finger tap: the press lands mid-tap, after the landing frame opened the window; the fake runs it
    // through the real PressFilter the way the real adapter does, so the recognizer never sees it (R8).
    world.hardware.touch(TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 1, click: .midway).frames,
                         on: Trackpad.macBook14.id)
    #expect(world.system.broughtToFront == [world.app("Arc")])
    #expect(world.hardware.feedback == [Trackpad.macBook14.id])

    world.access.set(granted: false)                        // R7 "Revoking stops blocking", no relaunch
    #expect(world.hardware.clickBlocking == false)
    world.hardware.touch(TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 1, click: .midway).frames,
                         on: Trackpad.macBook14.id)
    #expect(world.system.broughtToFront.count == 1)         // the press stayed a click and cancelled the tap
}

// R10: the prompt is asked exactly once, on first launch, and only when not granted.
@MainActor @Test func firstLaunchPromptsOnceThenOpensTheWindow() {
    let world = World()
    world.launcher.start()
    #expect(world.access.prompts == 1 && world.launcher.isWindowOpen)
    world.relaunch().start()
    #expect(world.access.prompts == 1)
}
```

```swift
// The recognizer's own seam: R1 and R4 as frame scripts, pure and synchronous.
@Test func earlyLiftStillCountsEveryFingerThatTouched() {
    let frames = TouchScript(.macBook14).thumb(atMM: (10, 10))
        .tap(fingers: 4, stagger: .milliseconds(50), hold: .milliseconds(100)).frames   // finger 1 lifts before 4 lands
    #expect(fired(frames) == [.four])
}

@Test func clicksAreBlockedWhileAnchoredWithAFingerDownAndReturnAfterThreeSeconds() {
    let frames = TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 1, hold: .seconds(4)).frames
    let window = blocking(frames)                                  // [Recognition.blocksClicks] per frame
    #expect(window[frame(atMS: 0)] == false)                       // thumb alone: a lone press still clicks
    #expect(window[frame(atMS: 60)] == true)                       // finger down, 60 ms after anchoring
    #expect(window[frame(atMS: 2990)] == true && window[frame(atMS: 3010)] == false)
}
```

```swift
// The tap's rule, with no CoreGraphics: a press is dropped or passed whole (R5), a drag of a dropped press
// becomes pointer movement (R6), and a dropped press is never "held" (R8).
@Test func aPressIsDroppedOrPassedWhole() {
    var filter = PressFilter()
    let press = PressID(button: 0, number: 7)
    #expect(filter.decide(.down(press), blocking: true) == .drop)
    #expect(filter.isPassedPressHeld == false)
    #expect(filter.decide(.dragged(press), blocking: false) == .passAsPointerMove)
    #expect(filter.decide(.up(press), blocking: false) == .drop)     // blocking ended; the up follows its down
    #expect(filter.decide(.up(PressID(button: 0, number: 8)), blocking: true) == .pass)   // an up we never saw the down of
}
```

```swift
// LauncherUI: the hint reads one model fact and sends one shell action.
if !launcher.hasAccessibilityAccess {
    AccessibilityHint(grantAccess: actions.openAccessibilitySettings)   // below HintText or TrackpadSettingsNotice
}
```

### Shape

**Data first.**

- *What a frame produces.* `Recognition` is a `Sendable` struct with `fired: Gesture?` and `blocksClicks: Bool`. The second field is R4's first three conditions decided on the frame clock: `Anchor` regains the `since: FrameTime` the 001 sketch had and S1 dropped, and `blocksClicks` is `state.anchor != nil && frame.time - since < clickBlockDuration && (down − anchor).nonEmpty`, evaluated after the frame's transitions. It is true in `.tapping`, and in `.spoiled` while fingers rest or drag under an anchored thumb (R4 says "while at least one other finger is on the trackpad", not "while tapping"), false in `.armed` (thumb alone) and `.idle`.
- *What a tap counts.* `.tapping` carries `touched: Set<TouchID>` beside `fingers`; every non-anchor ID that lands joins it and the tap fires `Gesture(fingerCount: touched.count)`, nil above four (R1). A reused ID while another finger holds the tap open is already in `touched` and counts once; a reused ID when it was the only finger ends the tap and starts the next, as today and as R1's "Two quick 1-finger taps" wants. `peak` is gone. `maxTapDuration` becomes 400 ms; `clickBlockDuration` (3 s) joins `GestureRules`.
- *What the tap decides.* `PressID` is `(button, number)`: CoreGraphics' event number, which a down and its up share (sourced), qualified by the button so two devices' counters are less likely to collide. `PressFilter` is a pure state machine over `Event` (`.down`, `.up`, `.dragged` of a `PressID`) with `decide(_:blocking:) -> Verdict` (`.pass`, `.drop`, `.passAsPointerMove`) and `isPassedPressHeld`. Its state is two sets, `dropped` and `passed`; R5 is "an up goes where its down went", R6 is "a drag of a dropped press is a pointer move", and R8 is "`isPassedPressHeld` never counts a dropped press". It lives in `LauncherCore`, with no CoreGraphics type on it (per `boundary-discipline`); the adapter parses `CGEvent` into `Event` and maps `Verdict` back.
- *What `TouchFrame.buttonDown` means.* "A press the system received is held." While the tap is live the frame stream reads it from the filter; without a tap it samples `CGEventSource` as today. The recognizer's press rule (a press on the landing frame or mid-tap spoils) is unchanged, and R8 holds by construction: a dropped press never reaches recognition, a passed press cancels as today (per `encode-lessons-in-structure`: the fact is removed from the input instead of flagged in the rule).
- *What the permission is.* `AccessibilityPermission` is a port with `onChange`, `isGranted()` and `prompt()`; `Launcher` stores the read as `hasAccessibilityAccess`, an observed field outside `GestureActivity`, so the icon (which reads `activity.isActive`) never changes with it (R11).

**Load-bearing decisions.**

1. *The recognizer owns the R4 window and reports it; it needs no new input.* It already knows the anchor, the finger set and the frame time, so the predicate is one derivation per frame on the frame thread, and expiry is seen within a frame because a resting thumb keeps frames flowing (per `model-the-domain`: one state machine answers both questions). Nothing compares frame time with event time: the tap reads a Bool.
2. *The click tap belongs to the hardware port.* `TrackpadHardware.run(_:handMode:clickBlocking:)` grows one parameter and hides the whole thing: tap creation (nil without trust), the mask, the filter, the thread, disabled-notice recovery, the per-device flags the tap ORs, and the fallback to sampling when no tap exists. The decision and the press state cross threads inside one adapter, never across a port (per `separate-before-serializing-shared-state`: each `DeviceSession` owns a `Mutex<Bool>` written only by its frame callback; the tap reads them all through the `sessions` registry, so `run` clearing the registry resets every decision for free). The filter is a `Mutex<PressFilter>` written only by the tap callback and read by frame callbacks. No lock is ever taken inside another.
3. *The tap callback runs on its own run-loop thread.* The WindowServer disables a slow tap and clicks then pass silently; the main thread does this app's only slow work (the picker's enumeration, SwiftUI layout). The callback touches only `Mutex`-guarded state and never hops to main. The thread exits by itself when `run` invalidates the mach port: the port's run-loop source dies with it, the run loop has no sources left and `CFRunLoopRun` returns.
4. *One `reconcile()` still converges everything.* It reads `access.isGranted()` beside `connected()` and `current()` and calls `run(active ? connected : [], handMode:, clickBlocking: active && hasAccessibilityAccess)`. Grant, revoke, `run([])`, wake, hot-plug and hand-mode all tear the tap down and rebuild it from truth (per `make-operations-idempotent`); revoke never relies on macOS stopping delivery. The cost is that a reconcile re-adopts a resting thumb in a fresh recognizer, restarting its 3-second window: accepted (see Tradeoffs).
5. *Access follows the Darwin push, deduplicated at the adapter.* `com.apple.tcc.access.changed` is a global broadcast for every TCC change by every app; `SystemAccessibilityPermission` re-reads trust on each and calls `onChange` only when the value changed, so unrelated grants do not restart the user's gesture. The trust reader is injectable for the adapter's own test, which flips it and `notify_post`s the same name.
6. *The prompt is derived from first launch.* `start()` asks `access.prompt()` after the login item and the first save, only when not granted, then opens the window; later launches never prompt (R10, and the non-goal for earlier installs) with no new stored field.
7. *The view is additive and the refit is explicit.* `AccessibilityHint` is a sibling after the activity switch in the same `VStack`; a third `Observations` loop on `hasAccessibilityAccess` calls `refit()`, so a change while the window is open resizes the panel. The button opens `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility` through `LauncherActions`, as the trackpad button does.
8. *Rules by structure.* `SourcePolicyTests.banned` loses `AXIsProcessTrusted`, `tapCreate`, `CGEventTapCreate`; keeps `IOHIDManager`, `CGRequestListenEventAccess`, `CGPreflightListenEventAccess` and every timer and polling token; gains `keyDown`, `keyUp`, `flagsChanged` (R9: no keyboard event may be named in a mask or a monitor). A self-check pins both halves of that edit. `docs/architecture.md` "The app asks for no permission." becomes "The app asks for one optional permission, Accessibility, and uses it only to drop trackpad presses during a gesture; everything else works without it." and the Concurrency section names the tap thread beside the frame thread.

**Depth.**

| Module | Public surface | What it hides |
|---|---|---|
| `GestureRecognizer` | init, `step -> Recognition` | R1–R3 and the old R11 rules, plus the R4 window and its clock |
| `PressFilter` | init, `decide`, `isPassedPressHeld` | R5 whole-press identity, R6 drag rewriting, R8's "a dropped press is no press" |
| `TrackpadHardware` | 4 members (`run` +1 parameter) | everything from 001 plus the tap, its thread, the mask, re-enable on disable, cross-device OR, fallback sampling |
| `AccessibilityPermission` | 3 members | `AXIsProcessTrusted`, `AXIsProcessTrustedWithOptions`, `notify_register_dispatch`, dedupe |
| `Launcher` | +1 read-only property | the blocking policy, prompt-once, access following live, three inputs reconciled as one |

**Concurrency** (Swift 6, language mode 6). Frame thread: steps the recognizer under its never-contended `Mutex`, then writes the session's `blocksClicks` flag (its only writer), reads the filter's `isPassedPressHeld` before building the frame. Click thread: the tap callback reads the registry's sessions and their flags, then writes the filter (its only writer); it returns within microseconds. Main actor: `run` is the only writer of the registry and the only thing that creates or invalidates the tap; the permission push arrives on the main queue (probed) and is forwarded with `MainActor.assumeIsolated`. No per-frame hop to main; no timer anywhere (the 3-second bound rides on frames, the 5-second bounds on the Darwin push).

**Requirement trace.**

| R | Carried by | Verified at |
|---|---|---|
| R1 | `touched` in `.tapping`; `Gesture(fingerCount:)` | recognizer seam: early lift, rolling five, two 1-finger taps; a reused ID while another finger holds (hand frames) counts once; the driver's ID for a real bounce is manual |
| R2 | `GestureRules.maxTapDuration` 400 ms | recognizer seam: 390/410 rows, uneven 3-finger (150 ms stagger, lift at 350 ms), 500 ms hold |
| R3 | fire on the lift frame (unchanged) | recognizer seam, per-frame map; haptic timing manual |
| R4 | `Recognition.blocksClicks`; `ClickTap`; `reconcile` (`active && access`) | recognizer seam: thumb alone, finger down, 2990/3010 ms, thumb lifts, thumb slides out, lone corner finger; `Launcher` seam: `hardware.clickBlocking` with Tap to click on, declined, granted; every real-click scenario manual |
| R5 | `PressFilter` | pure rows: up follows its down across a blocking change, unknown up passes; drag-then-thumb manual |
| R6 | the mask; `.passAsPointerMove` | pure row for dragged; pointer, scroll, mouse manual |
| R7 | `onChange` → `reconcile` → `run` | `Launcher` seam via `access.set(granted:)`; `LauncherPlatformTests`: injected trust flipped, `notify_post`, `onChange` on main within 5 s, no `onChange` when unchanged; System Settings manual |
| R8 | `isPassedPressHeld` → `TouchFrame.buttonDown` | pure (a dropped press is never held); `Launcher` seam: `click: .midway` fires with blocking, spoils without, and after a 4 s rest; press-and-hold 1 s fires nothing (R2); haptic manual |
| R9 | the mask; `SourcePolicyTests`; `active && access` | policy scan and its self-check; `Launcher` seam: declined → gesture fires, `clickBlocking == false`; TCC log manual |
| R10 | `start()` | `Launcher` seam: `prompts == 1` then window open; relaunch → still 1; granted → 0; prompt in front of the panel manual |
| R11 | `hasAccessibilityAccess`; `AccessibilityHint`; `openAccessibilitySettings` | `Launcher` seam: flag follows `set(granted:)` both ways; copy, button, live refit manual |

**Deliberately not done.** No per-device attribution of button events (no public field names the source device; R6's mouse scenario is met by the "another finger is down" condition). No enable/disable of the tap from the frame thread as the window opens and closes. No pressure events in the mask until the Force Click manual check asks for them. No stored "prompted" flag. No change to the icon, the anchor corner, the drag threshold or the fire-on-lift rule. No comparison of `FrameTime` with `CGEventTimestamp`.

#### Module map

```
LauncherCore     (Foundation, Observation)          GestureRules (+clickBlockDuration, 400 ms) · Recognition · GestureRecognizer
                                                     (touched set, Anchor.since, blocksClicks) · PressID · PressFilter ·
                                                     AccessibilityPermission port · TrackpadHardware.run(+clickBlocking) ·
                                                     Launcher (+access, hasAccessibilityAccess)
LauncherPlatform (+ApplicationServices, notify)     ClickTap (tap, thread, mask, callback) · DeviceSession (+blocksClicks,
                                                     pressHeld) · MultitouchTrackpads.run (+tap lifecycle) ·
                                                     SystemAccessibilityPermission
LauncherUI       (AppKit, SwiftUI; MainActor)        AccessibilityHint · LauncherActions.openAccessibilitySettings ·
                                                     MenuBarShell (third observation loop → refit)
TrackpadLauncher app target                         composition root (+SystemAccessibilityPermission)
Tests                                               InMemoryTrackpads (+clickBlocking, PressFilter composition, decisions) ·
                                                     InMemoryAccessibilityPermission · World (+access, two constructors) ·
                                                     PressFilterTests · SourcePolicyTests (revised list, self-check) ·
                                                     LauncherPlatformTests (Darwin push)
docs                                                architecture.md: permissions sentence, concurrency sentence
```

#### LauncherCore: rules, recognition, the press filter

```swift
import Foundation

/// Every fixed number in gesture recognition, in one place. Not user-tunable.
package enum GestureRules {
    static let cornerWidth = 0.20
    static let cornerHeight = 0.25
    static let anchorReleaseMarginMM = 2.0
    /// First finger landing to last finger lift (R2). Was 300 ms; 400 is the first value tried, untuned.
    static let maxTapDuration = Duration.milliseconds(400)
    static let dragThresholdMM = 3.0
    /// Clicks are blocked for this long after a thumb anchors, while it stays anchored and another finger is down (R4).
    static let clickBlockDuration = Duration.seconds(3)
}

/// What one frame produced. `fired` at most once per tap, on the frame where the last finger lifts (R3).
/// `blocksClicks` is R4's window as of this frame: a thumb is anchored, under `clickBlockDuration` since it anchored,
/// and at least one other finger is down. Whether anything is actually dropped is the adapter's business.
public struct Recognition: Equatable, Sendable {
    public let fired: Gesture?
    public let blocksClicks: Bool
    public init(fired: Gesture?, blocksClicks: Bool) { fatalError("not implemented") }
}

/// Everything the recognizer needs about one instant on one trackpad. A complete snapshot:
/// a contact absent from `touches` has lifted. `[]` is the frame after the last lift.
public struct TouchFrame: Sendable {
    public let time: FrameTime
    public let touches: [Touch]
    /// A press the system received is held. While the click tap is live the adapter answers from `PressFilter`
    /// (a dropped press is never one, R8); without a tap it samples the session's button state as before.
    public let buttonDown: Bool
    public init(time: FrameTime, touches: [Touch], buttonDown: Bool) { fatalError("not implemented") }
}

/// The rules for ONE trackpad, as a pure state machine. Feed every frame in order.
/// Owned by exactly one frame thread (real adapter) or by the test (in-memory adapter); never shared.
public struct GestureRecognizer: Sendable {
    public init(handMode: HandMode, surface: SurfaceSize) { fatalError("not implemented") }

    public mutating func step(_ frame: TouchFrame) -> Recognition {
        // TODO (unchanged derivations: down, reused, lifted, landed; lifts before landings; defer previouslyDown)
        // 1. Anchor maintenance, every state with an anchor: lifted / reused / !holds → .idle   (unchanged)
        // 2. switch state
        //    .idle:    first landed touch the corner admits → Anchor(id, since: frame.time);
        //              state = down.count == 1 ? .armed : .spoiled                              (unchanged, plus `since`)
        //    .armed:   fingers = landed − anchor; if !fingers.isEmpty:
        //              state = frame.buttonDown ? .spoiled : .tapping(anchor, fingers: points, touched: ids, start: frame.time)
        //    .tapping(anchor, fingers, touched, start):
        //              fingers −= lifted
        //              if frame.buttonDown || frame.time - start > maxTapDuration || any remaining finger dragged > 3 mm
        //                  → .spoiled(anchor)                                                   (unchanged)
        //              else if fingers.isEmpty:
        //                  fired = Gesture(fingerCount: touched.count)                           // R1: distinct IDs; nil for 5+
        //                  new = landed − anchor; state = new.isEmpty ? .armed : .tapping(new, touched: new ids, start: now)
        //              else:
        //                  fingers[id] = position for each landed non-anchor touch (a reused ID gets its new origin)
        //                  touched ∪= landed non-anchor ids                                     // a reused ID is already there
        //    .spoiled: only the anchor down → .armed                                             (unchanged)
        // 3. blocksClicks = state.anchor.map { a in
        //        frame.time - a.since < GestureRules.clickBlockDuration && down.keys.contains { $0 != a.id } } ?? false
        //    (evaluated after the transitions: a thumb that lifted or slid out this frame reads false at once;
        //     a thumb re-landing over resting fingers opens a fresh window, as R4's "becomes anchored" says)
        // 4. return Recognition(fired: fired, blocksClicks: blocksClicks)
        fatalError("not implemented")
    }

    private struct Anchor: Sendable { let id: TouchID; let since: FrameTime }
    private enum State: Sendable {
        case idle
        case armed(Anchor)
        case tapping(Anchor, fingers: [TouchID: SurfacePoint], touched: Set<TouchID>, start: FrameTime)
        case spoiled(Anchor)
        var anchor: Anchor? { fatalError("not implemented") }
    }
    private let corner: AnchorCorner
    private let surface: SurfaceSize
    private var state: State = .idle
    private var previouslyDown: Set<TouchID> = []
}

/// One press, as the system numbers it: a mouse-down and its mouse-up carry the same event number (sourced).
/// The button qualifies it so two devices' counters are less likely to collide. Parsed by the tap adapter.
public struct PressID: Hashable, Sendable {
    public let button: Int64
    public let number: Int64
    public init(button: Int64, number: Int64) { fatalError("not implemented") }
}

/// R5, R6 and R8 for the click tap, as a pure state machine with no CoreGraphics on it. Feed every button event in
/// order with whether blocking is in effect at that moment. Invariants: a press is dropped or passed whole (its up goes
/// where its down went, whatever blocking says by then); an up whose down was never seen passes; a drag of a dropped
/// press passes as pointer movement so the pointer keeps moving and no app sees a drag without its down;
/// `isPassedPressHeld` never counts a dropped press.
public struct PressFilter: Equatable, Sendable {
    public enum Event: Equatable, Sendable {
        case down(PressID)
        case up(PressID)
        case dragged(PressID)
    }
    public enum Verdict: Equatable, Sendable {
        case pass
        case drop
        /// Return the event with its type rewritten to a pointer move.
        case passAsPointerMove
    }

    public init() {}

    public mutating func decide(_ event: Event, blocking: Bool) -> Verdict {
        // .down(id):    blocking ? (dropped.insert(id); .drop) : (passed.insert(id); .pass)
        // .up(id):      dropped.remove(id) != nil ? .drop : (passed.remove(id); .pass)
        // .dragged(id): dropped.contains(id) ? .passAsPointerMove : .pass
        fatalError("not implemented")
    }

    /// A press the system received is held right now: what `TouchFrame.buttonDown` reads while the tap is live.
    public var isPassedPressHeld: Bool { !passed.isEmpty }

    private var dropped: Set<PressID> = []
    private var passed: Set<PressID> = []
}
```

#### LauncherCore: ports and the Launcher

```swift
/// The multitouch hardware, and what it does to the trackpad's own presses.
@MainActor public protocol TrackpadHardware: AnyObject {
    var onEvent: (@MainActor (TrackpadEvent) -> Void)? { get set }
    func connected() -> [Trackpad]
    /// Forgets every session, stops every running device and removes the click tap; then starts exactly `trackpads`,
    /// each with a fresh GestureRecognizer for `handMode`, and installs the click tap iff `clickBlocking` and at least
    /// one trackpad starts. Idempotent. [] = nothing runs and nothing is tapped. While the tap is live, presses it drops
    /// never reach recognition (R8); if the tap cannot be created (no Accessibility), nothing is blocked and presses
    /// are sampled as before.
    func run(_ trackpads: [Trackpad], handMode: HandMode, clickBlocking: Bool)
    func playFeedback(on trackpad: TrackpadID)
}

/// The Accessibility permission. Real: SystemAccessibilityPermission. Test: InMemoryAccessibilityPermission.
@MainActor public protocol AccessibilityPermission: AnyObject {
    /// Called on the main actor after trust changed, and only then.
    var onChange: (@MainActor () -> Void)? { get set }
    /// Whether this process is trusted now, read fresh. Never prompts.
    func isGranted() -> Bool
    /// Shows the system's Accessibility prompt. Returns at once; a grant arrives through `onChange`. No-op when granted.
    func prompt()
}

@MainActor @Observable
public final class Launcher {
    public private(set) var rows: [GestureRow] = []
    public private(set) var isWindowOpen = false
    /// R11: the Accessibility hint shows while false. Kept out of `activity`, so the icon never changes with it.
    public private(set) var hasAccessibilityAccess = false
    public var handMode: HandMode { settings.handMode }
    public var activity: GestureActivity { GestureActivity(connected: Set(connected.map(\.kind)), values: preferenceValues) }

    @ObservationIgnored private let access: any AccessibilityPermission
    // … the 001 fields unchanged

    /// The constructor is written in three places: World.init, World.relaunch, TrackpadLauncherApp.main.
    public init(hardware: any TrackpadHardware, preferences: any TrackpadPreferences, access: any AccessibilityPermission,
                system: any SystemActions, catalog: AppCatalog, store: SettingsStore) { fatalError("not implemented") }

    public func start() {
        // hardware.onEvent = { .gesture → fire; .trackpadsChanged → reconcile }     (unchanged)
        // preferences.onChange = { reconcile() }                                     (unchanged)
        // access.onChange = { [unowned self] in reconcile() }                        // R7, R11 live
        // reconcile()
        // guard isFirstLaunch else { return }
        // system.registerLoginItem(); store.save(settings)                           (unchanged order)
        // if !hasAccessibilityAccess { access.prompt() }                             // R10: once, first launch only
        // openWindow()                                                               // the window is open behind the prompt
        fatalError("not implemented")
    }

    /// The one convergent operation behind launch, hot-plug, wake, preference, hand-mode and permission changes.
    private func reconcile() {
        // connected = hardware.connected(); preferenceValues = preferences.current()
        // hasAccessibilityAccess = access.isGranted()
        // let active = activity.isActive
        // hardware.run(active ? connected : [], handMode: settings.handMode,
        //              clickBlocking: active && hasAccessibilityAccess)             // R4 "inactive", R9 "Declined"
        fatalError("not implemented")
    }
    // setAssignment, setHandMode, openWindow, closeWindow, fire, makeRows: unchanged
}
```

#### LauncherPlatform: the frame stream and the click tap

```swift
import ApplicationServices
import CoreGraphics
import LauncherCore
import Synchronization

@MainActor public final class MultitouchTrackpads: TrackpadHardware {
    private var clickTap: ClickTap?
    // … the 001 fields unchanged

    public func run(_ trackpads: [Trackpad], handMode: HandMode, clickBlocking: Bool) {
        // TODO
        // 1. sessions.withLock { $0 = [:] }                     — registry cleared FIRST, as in 001; every per-device
        //                                                        blocksClicks flag goes with its session
        // 2. unregister callbacks, stop devices, close actuators (unchanged)
        // 3. clickTap?.invalidate(); clickTap = nil             — torn down by us, never left to macOS (revoke, run([]), wake)
        // 4. let devices = listTrackpads() filtered to `trackpads`
        // 5. if clickBlocking && !devices.isEmpty { clickTap = ClickTap(blocking: anySessionBlocksClicks) }   // nil without trust
        // 6. let pressHeld: @Sendable () -> Bool = clickTap.map { tap in { tap.isPassedPressHeld() } } ?? { anyMouseButtonDown() }
        // 7. for each device: DeviceSession(trackpad:, recognizer: fresh, pressHeld:, deliver: hop to main);
        //    actuator, registry insert, register callback, start (unchanged)
        // Postcondition: frames flow from exactly `trackpads` into fresh recognizers; a tap exists iff asked and allowed.
        fatalError("not implemented")
    }
}

/// One running trackpad. The recognizer is stepped only by this device's frame callbacks (never-contended Mutex);
/// `blocksClicks` is written only by those callbacks and read by the click thread.
final class DeviceSession: Sendable {
    let trackpad: TrackpadID
    let blocksClicks = Mutex(false)
    let pressHeld: @Sendable () -> Bool
    private let recognizer: Mutex<GestureRecognizer>
    private let deliver: @Sendable (GestureEvent) -> Void

    init(trackpad: TrackpadID, recognizer: GestureRecognizer, pressHeld: @escaping @Sendable () -> Bool,
         deliver: @escaping @Sendable (GestureEvent) -> Void) { fatalError("not implemented") }

    func receive(_ frame: TouchFrame) {
        // let r = recognizer.withLock { $0.step(frame) }        — lock released before the next line
        // blocksClicks.withLock { $0 = r.blocksClicks }
        // if let g = r.fired { deliver(GestureEvent(gesture: g, trackpad: trackpad)) }
        fatalError("not implemented")
    }
}

/// Written by `run` (main), read by frame callbacks and by the click thread.
let sessions = Mutex<[UInt: DeviceSession]>([:])

let contactFrameCallback: MultitouchSupport.ContactFrameCallback = { device, touches, count, timestamp, _ in
    // guard let device, let session = sessions.withLock({ $0[UInt(bitPattern: device)] }) else { return 0 }
    // session.receive(TouchFrame(parsing: touches, count: count, timestamp: timestamp, buttonDown: session.pressHeld()))
    return 0
}

/// Blocking is in effect when any running trackpad's window is open (R4 across trackpads). Read by the click thread.
func anySessionBlocksClicks() -> Bool {
    // sessions.withLock { Array($0.values) }.contains { $0.blocksClicks.withLock { $0 } }   — no nested locks
    fatalError("not implemented")
}

/// Still the no-tap path: a state query, no permission.
func anyMouseButtonDown() -> Bool { fatalError("not implemented") }

/// The active session event tap that drops trackpad presses while blocking is in effect (R4–R6, R9).
/// Created only with Accessibility trust (`CGEvent.tapCreate` returns nil otherwise, probed). Place: `.cgSessionEventTap`,
/// `.headInsertEventTap`, `.defaultTap`. Mask: exactly `EventKind.allCases`, nine mouse-button types; no keyboard,
/// scroll or move type ever enters it (R6, R9).
/// The callback runs on the tap's own run-loop thread, so a pass/drop decision never waits on main-thread work
/// (the picker's enumeration, SwiftUI layout); a slow callback would get the tap disabled by the WindowServer and
/// clicks would pass silently. It touches only Mutex-guarded state and returns within microseconds.
final class ClickTap: Sendable {
    /// nil when the tap cannot be created. Starts the click thread, which adds the port's run-loop source to its own
    /// run loop and runs it.
    init?(blocking: @escaping @Sendable () -> Bool) { fatalError("not implemented") }

    /// `PressFilter.isPassedPressHeld`, read by frame threads.
    func isPassedPressHeld() -> Bool { fatalError("not implemented") }

    /// CFMachPortInvalidate: the run-loop source dies with the port, the click thread's run loop has no sources left,
    /// CFRunLoopRun returns and the thread exits. Idempotent; safe from main while a callback is in flight.
    func invalidate() { fatalError("not implemented") }

    /// The mask is this table. The pressure type (NSEventTypePressure == 34) is one more case here if the Force Click
    /// manual check shows that dropping the mouse events alone does not stop Look up.
    private enum EventKind: CaseIterable {
        case leftDown, leftUp, leftDragged, rightDown, rightUp, rightDragged, otherDown, otherUp, otherDragged
        var type: CGEventType { fatalError("not implemented") }
        /// The domain event for a CGEvent of this kind, keyed by (mouseEventButtonNumber, mouseEventNumber).
        func event(for press: PressID) -> PressFilter.Event { fatalError("not implemented") }
        static let mask: CGEventMask = allCases.reduce(0) { $0 | (1 << CGEventMask($1.type.rawValue)) }
    }

    /// Reached by the C callback through `userInfo`. The port is set once before the thread starts; `@unchecked` covers
    /// only that CF reference.
    private final class State: @unchecked Sendable {
        let filter = Mutex(PressFilter())
        let blocking: @Sendable () -> Bool
        var port: CFMachPort?
    }
    private let state: State

    private static let callback: CGEventTapCallBack = { _, type, event, userInfo in
        // let state = Unmanaged<State>.fromOpaque(userInfo!).takeUnretainedValue()
        // if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        //     state.port.map { CGEvent.tapEnable(tap: $0, enable: true) }; return passUnretained(event) }
        // guard let kind = EventKind(type) else { return passUnretained(event) }      // never happens: the mask is the table
        // let press = PressID(button: event.getIntegerValueField(.mouseEventButtonNumber),
        //                     number: event.getIntegerValueField(.mouseEventNumber))
        // let blocking = state.blocking()                                              // before taking the filter lock
        // switch state.filter.withLock({ $0.decide(kind.event(for: press), blocking: blocking) }) {
        // case .pass: return passUnretained(event)
        // case .drop: return nil
        // case .passAsPointerMove: event.type = .mouseMoved; return passUnretained(event)
        // }
        fatalError("not implemented")
    }
}
```

#### LauncherPlatform: the permission adapter

```swift
import ApplicationServices
import LauncherCore
import notify

/// AccessibilityPermission over AXIsProcessTrusted and the Darwin notification tccd posts after any TCC change
/// (probed: 30 ms, main queue). The notification is a global broadcast, so trust is re-read and `onChange` runs only
/// when the value changed. No polling.
@MainActor public final class SystemAccessibilityPermission: AccessibilityPermission {
    /// Public so the adapter's test can `notify_post` the same name.
    public static let changeNotification = "com.apple.tcc.access.changed"
    public var onChange: (@MainActor () -> Void)?

    /// `trusted` is injectable for the adapter's own test, which flips it and posts the notification itself;
    /// the default reads AXIsProcessTrusted().
    public init(trusted: @escaping @Sendable () -> Bool = { AXIsProcessTrusted() }) {
        // lastKnown = trusted()
        // notify_register_dispatch(Self.changeNotification, &token, .main) { _ in MainActor.assumeIsolated { self.refresh() } }
        fatalError("not implemented")
    }

    isolated deinit { /* notify_cancel(token) */ }

    public func isGranted() -> Bool {
        // lastKnown = trusted(); return lastKnown                                     (fresh read, no callback)
        fatalError("not implemented")
    }

    /// AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true]); returns at once (sourced).
    public func prompt() { fatalError("not implemented") }

    private func refresh() {
        // let now = trusted(); guard now != lastKnown else { return }; lastKnown = now; onChange?()
    }
    private var lastKnown: Bool
    private var token: Int32 = 0
    private let trusted: @Sendable () -> Bool
}
```

#### LauncherUI

```swift
/// AppKit-only actions and suppliers the views use.
struct LauncherActions {
    let installedApps: () -> [AppEntry]
    let chooseOtherApp: (Gesture) -> Void
    let openTrackpadSettings: () -> Void
    /// NSWorkspace.open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") (sourced).
    let openAccessibilitySettings: () -> Void
    let quit: () -> Void
}

// MenuBarShell.init: a third observation loop, so a hint toggling while the window is open refits the panel (R11).
//   Task { for await _ in Observations({ launcher.hasAccessibilityAccess }) { self?.refit() } }

// LauncherView.body, inside the inner VStack after the activity switch:
//   if !launcher.hasAccessibilityAccess { AccessibilityHint(grantAccess: actions.openAccessibilitySettings) }

/// R11's exact copy, in the file that owns `hintStyle()`.
struct AccessibilityHint: View {
    let grantAccess: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Clicks aren't blocked during gestures. Allow Accessibility access to block them.").hintStyle()
            Button("Grant access…", action: grantAccess).buttonStyle(.bordered).buttonBorderShape(.capsule)
        }
    }
}
```

#### Tests: adapters, fixtures, the policy gate

```swift
/// Real recognizer and real PressFilter, scripted frames, synchronous main-actor delivery.
@MainActor final class InMemoryTrackpads: TrackpadHardware {
    /// What the last `run` asked for: the Launcher's blocking decision (R4 inactive, R7, R9).
    private(set) var clickBlocking = false
    /// Every frame's `blocksClicks` since the last `run`, per trackpad: R4 rows at the Launcher seam.
    private(set) var blockDecisions: [TrackpadID: [Bool]] = [:]
    // … 001 members unchanged (attached, running, deaf, feedback, attach, detach, sleep, wake, inject)

    func run(_ trackpads: [Trackpad], handMode: HandMode, clickBlocking: Bool) {
        // running = fresh recognizers; deaf = []; self.clickBlocking = clickBlocking
        // filters = [:]; lastDecision = [:]; blockDecisions = [:]; nextPress = 1
        fatalError("not implemented")
    }

    /// Scripted frames carry the physical button. While `clickBlocking`, each press runs through the real
    /// `PressFilter` against the PREVIOUS frame's `blocksClicks` (an event between frames sees the last decision,
    /// as on hardware; a press on the very landing frame therefore passes, which is the latency race made visible)
    /// and the recognizer reads `isPassedPressHeld`. Without it, `buttonDown` passes through as today.
    func touch(_ frames: [TouchFrame], on id: TrackpadID) {
        // for frame in frames:
        //   guard !deaf.contains(id), running[id] != nil else { return }
        //   var buttonDown = frame.buttonDown
        //   if clickBlocking {
        //     rising edge  → held[id] = PressID(button: 0, number: nextPress++); filters[id].decide(.down(held), blocking: lastDecision[id])
        //     falling edge → filters[id].decide(.up(held[id]), blocking: lastDecision[id]); held[id] = nil
        //     buttonDown = filters[id].isPassedPressHeld
        //   }
        //   let r = running[id]!.step(TouchFrame(time: frame.time, touches: frame.touches, buttonDown: buttonDown))
        //   lastDecision[id] = r.blocksClicks; blockDecisions[id, default: []].append(r.blocksClicks)
        //   if let g = r.fired { onEvent?(.gesture(GestureEvent(gesture: g, trackpad: id))) }
        fatalError("not implemented")
    }
}

/// Trust as an in-memory fact; `set` pushes like a TCC change (no push when unchanged, as the real adapter dedupes).
@MainActor final class InMemoryAccessibilityPermission: AccessibilityPermission {
    var onChange: (@MainActor () -> Void)?
    private(set) var granted = false
    private(set) var prompts = 0
    func isGranted() -> Bool { granted }
    func prompt() { prompts += 1 }
    func set(granted: Bool) { /* guard changed; self.granted = granted; onChange?() */ }
}

// World: `let access = InMemoryAccessibilityPermission()`, passed in both `Launcher(...)` calls (init and relaunch).

// Fixtures:
//   func fired(_ frames: [TouchFrame], ...) -> [Gesture]   { frames.compactMap { recognizer.step($0).fired } }
//   func blocking(_ frames: [TouchFrame], ...) -> [Bool]   { frames.map { recognizer.step($0).blocksClicks } }
//   func frame(atMS:) -> Int                                 { ms / 10 }   — TouchScript's frame index
// TouchScript: unchanged; `click:` is the physical button. Bounces, thumb-only presses, presses before the thumb and
// presses ending off the lift frame stay HandFrames (the 001 precedent).

/// Revised gate. Removed: AXIsProcessTrusted, tapCreate, CGEventTapCreate (R9 replaces 001's R20).
/// Kept: IOHIDManager, CGRequestListenEventAccess, CGPreflightListenEventAccess (no Input Monitoring), every timer
/// and polling token (001 R22 stands). Added: keyDown, keyUp, flagsChanged (R9: no keyboard event in any mask or monitor).
@Suite struct SourcePolicyTests {
    static let banned: [Entry] = [ /* … */
        Entry(token: "keyDown", rule: "no keyboard events"),
        Entry(token: "keyUp", rule: "no keyboard events"),
        Entry(token: "flagsChanged", rule: "no keyboard events"),
    ]
    /// Pins both halves of the plan 002 edit so neither drifts back.
    @Test func permissionListMatchesPlanTwo() {
        // let tokens = Set(Self.banned.map(\.token))
        // #expect(tokens.isDisjoint(with: ["AXIsProcessTrusted", "tapCreate", "CGEventTapCreate"]))
        // #expect(tokens.isSuperset(of: ["IOHIDManager", "CGRequestListenEventAccess", "CGPreflightListenEventAccess",
        //                                "Timer", "asyncAfter", "Task.sleep", "makeTimerSource", "keyDown"]))
    }
}

// LauncherPlatformTests: SystemAccessibilityPermission(trusted: { flag.withLock { $0 } }); flip the flag;
// notify_post(SystemAccessibilityPermission.changeNotification); onChange arrives on the main actor within the 5 s
// bound (the AsyncStream pattern of the preferences test); post again without flipping → no onChange.
```

**Test handles.** Everything a test cannot wait for or trigger directly.

| Thing | Handle |
|---|---|
| The permission and its live change | `InMemoryAccessibilityPermission.set(granted:)` (invokes `onChange` synchronously); the real push: `notify_post` of `SystemAccessibilityPermission.changeNotification` with an injected trust reader |
| The prompt request | `InMemoryAccessibilityPermission.prompts` |
| The R4 window, frame by frame | `GestureRecognizer.step(_:).blocksClicks` (recognizer seam); `InMemoryTrackpads.blockDecisions` (Launcher seam) |
| The tap's pass/drop decision | `PressFilter.decide(_:blocking:)`, pure |
| Whether the app armed blocking | `InMemoryTrackpads.clickBlocking` |
| A press the recognizer sees, or does not | `TouchFrame.buttonDown` (recognizer seam); `TouchScript.tap(click:)` run through the fake's `PressFilter` (Launcher seam) |
| The clock behind the 3 s window and the 400 ms limit | `TouchFrame.time`; no clock object exists |
| No keyboard, no Input Monitoring, no timers | `SourcePolicyTests` and its new self-check |

### Synthesis decision

### Tradeoffs accepted

- We accept that every reconcile (hot-plug, wake, preference, hand-mode and now permission changes) re-adopts a resting thumb in a fresh recognizer and restarts its 3-second window, in exchange for one convergent `run` that also owns the tap's lifecycle; the events are rare and the worst case is clicks blocked for up to 3 more seconds while the thumb rests with a finger down.
- We accept one more thread (the click thread's run loop) in exchange for pass/drop decisions that never wait on the main thread's UI work and a tap the WindowServer has no reason to disable; it sleeps in `mach_msg` and costs nothing idle.
- We accept that the tap, while installed, wakes the click thread for every mouse-button event session-wide, including a mouse's, in exchange for never enabling or disabling the tap from the frame thread; blocking applies only when a trackpad's window is open, and a user clicking is not idle under R22.
- We accept that `TouchFrame.buttonDown` now means "a press the system received is held" and that the in-memory hardware reproduces the real composition (filter plus recognizer, previous frame's decision), in exchange for a recognizer with no "blocking in effect" input and a single source of truth for "was this press blocked".
- We accept the latency race between a landing frame and the click event: a press that reaches the tap before the landing frame's decision passes and cancels the tap exactly as today without the permission (a click, no gesture, never both); the non-goals forbid the delay that would close it.
- We accept that a bouncing finger the driver gives a new ID counts twice under R1 (a 4-finger tap with such a bounce fires nothing) until hardware shows which way the driver goes.
- We accept `(button, number)` as press identity, which could in theory collide across two pointing devices, in exchange for using only public fields.
- We accept that the tap, its thread and the mask are verified only on hardware; the rule they apply is the pure `PressFilter`.
- We accept a mouse click while the thumb and a finger rest on the trackpad being blocked (no public field names the source device); R6's scenario, thumb alone plus a mouse click, passes by the "another finger is down" condition.

### Alternatives considered

- **The recognizer takes a `clickBlocking` input and ignores a press while its own window is open.** The smaller change on paper, but it makes the recognizer re-derive R5 (a press that began inside the window and is held past 3 s is spoiled although the tap dropped it whole) or get the race wrong (a press the tap passed is treated as blocked, so the user gets the click and the gesture). Two modules would own "was this press blocked". Rejected for the single source of truth.
- **A separate `ClickBlocker` port with `arm()` / `disarm()`.** Looks like a clean seam, but the per-frame decision would have to cross from the hardware adapter to the tap adapter through module-level shared state, and `Launcher` would coordinate two ports for one effect; a shallow port in front of a shared `Mutex`. The decision and the press state belong on the same side of one port.
- **The tap callback on the main run loop.** No new thread, but the main thread does the app's only slow work and a disabled tap passes clicks silently; the failure is exactly the feature's promise. Rejected for robustness.
- **Hop the window decision to main and enable/disable the tap as it opens and closes.** Zero wakeups for mouse clicks while idle, but a main-actor hop per window transition, and a disabled tap misses the passed presses the filter must know about. Rejected on cost and correctness; a possible later refinement if the idle blips ever matter.
- **Poll `AXIsProcessTrusted`, or re-read it only when the window opens.** Polling is banned; window-open-only misses R7's "within 5 seconds" while the window is closed. The Darwin push is probed and costs nothing.
- **A stored "prompted" flag.** A second boolean that must stay in sync with first launch; the first-launch fact already says "prompt once" and the non-goal about earlier installs agrees.
- **Keep peak counting with a short grace after the last lift.** Contradicts R3 and the no-grace non-goal; distinct IDs give R1 directly.

### Open questions and risks

- Is it acceptable that a very fast firm tap, whose click reaches the tap before the landing frame is processed, behaves like today without the permission (the click lands and the gesture does not fire)? The non-goals rule out the delay that would close the race; this should be felt on hardware before deciding anything.
- A dedicated run-loop thread for the tap is chosen over the main run loop for latency isolation. Does the extra thread sit well with the "no background loops" sentence in `docs/architecture.md` (it sleeps; it is a push), or would you rather accept the main-thread risk?
- During a dropped press, dragged events are rewritten to pointer moves so no app sees a drag without its down. Should they instead pass unchanged, and does any app misbehave either way (manual)?
- Does dropping the mouse down/up stop Force Click's Look up, or must the pressure type (34) join `EventKind`? One line if so; manual.
- Do trackpad presses carry mouse subtype 3? If they do, should `PressFilter.Event` carry "from a trackpad" so a mouse click passes even inside a window (the strict R6 reading)?
- Does the driver reuse a bouncing finger's ID (R1 "Bouncing finger counts once")? Run plan 001's unticked `mt-probe` with a deliberate bounce; if the ID changes, R1 needs a position-based match or a relaxation.
- Does a real grant or revoke in System Settings post `com.apple.tcc.access.changed`, and does `AXIsProcessTrusted()` flip without relaunch? If a grant were ever not broadcast, the fallback inside the rules is to re-read trust on the other pushes (`openWindow`, reconcile), never a timer.
- Does the first-launch prompt alert appear in front of the launcher panel, and does the panel refit when the hint appears while the window is open (the third observation loop)?
- Debug (Apple Development) and Release (Developer ID) builds are probably separate TCC clients; acceptable for the developer's workflow?

### Next implementation step

Change `GestureRecognizer.step` to return `Recognition`, restore `Anchor.since`, replace `peak` with the `touched` set and move `maxTapDuration` to 400 ms, driving every R1, R2 and R4-window row at the recognizer seam test-first; then write `PressFilter` and its pure rows before any CoreGraphics code exists.
