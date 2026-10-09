## Design

### Problem

Plan 002 adds three things to the plan 001 app: forgiving taps (count every distinct finger, 400 ms), click blocking for the first 3 seconds after a thumb anchors, and an optional Accessibility permission with a first-launch prompt and a live hint. Click blocking is hard to place because it is spread across three threads, two clocks and three owners. Only the recognizer, on the MultitouchSupport frame thread, knows that a thumb is anchored, when it anchored and whether another contact is down. The click itself reaches an active session event tap on whatever run loop that tap's source is on, stamped with a `CGEventTimestamp` that may not share a base with `FrameTime`. Only the main actor knows whether gestures are active and whether access is granted. The design must also work without answers to several open facts. It must not matter whether a dropped press still reads as down in `CGEventSource.buttonState`, whether a click came from the trackpad or a mouse, whether a bouncing finger keeps its ID, or whether Force Click's pressure events matter. Constraints carried over from plan 001: one `@MainActor @Observable` `Launcher` owns every decision; ports have exactly two adapters; policy is pure and lives in `LauncherCore`, which imports Foundation and Observation only; frames are recognised on the frame thread; one idempotent `reconcile()` restarts every device with a fresh recognizer, and a fresh recognizer re-adopts a resting thumb on its first frame; the frame timestamp is the only clock; there are no timers and no polling; rules are enforced by the source-policy gate. The grounding also surfaced two problems. First, tccd's push (`com.apple.tcc.access.changed`) is a global broadcast. Second, the shell closes the launcher window on any outside mouse-down and whenever the panel resigns key, so the system's Accessibility prompt would close the first-launch window. The prompt is another process: it takes focus when it appears, and its buttons are outside clicks. That breaks R10 ("once the prompt is dismissed, the launcher window MUST be open").

### Usage (caller's view)

**README excerpt.** `Launcher` still owns every decision. It now also reads one more fact, whether Trackpad Launcher has the Accessibility permission, through a third sensing port that pushes "may have changed". From that fact and gesture activity it decides whether clicks may be blocked, and tells the hardware port in the same `run` call that starts the devices. The hardware adapter does the rest. Each trackpad's recognizer reports, frame by frame, whether that trackpad is inside its blocking window. The adapter's one event tap drops a press that starts while any trackpad is inside its window, together with that press's release, drags and pressure. Frames record the press the way the tap treated it, so a blocked press is part of the tap and a delivered click cancels it. The window shows the Accessibility hint while access is missing. Tests drive all of it synchronously: frames carry their own time, and the in-memory hardware runs the real recognizer and the real click filter.

```swift
// TrackpadLauncher app target: the composition root. One new adapter, one new argument.
@main
enum TrackpadLauncherApp {
    static func main() {
        let application = NSApplication.shared
        let catalog = AppCatalog.system
        let launcher = Launcher(
            hardware: MultitouchTrackpads(),
            preferences: SystemTrackpadPreferences(),
            access: SystemAccessibilityPermission(),
            system: WorkspaceActions(),
            catalog: catalog,
            store: SettingsStore(defaults: .standard))
        let shell = MenuBarShell(launcher: launcher, catalog: catalog)
        launcher.start()   // reconcile; first launch: login item, the Accessibility prompt unless granted, the window
        withExtendedLifetime(shell) { application.run() }
    }
}
```

```swift
// LauncherCoreTests, the high seam. R8 "Firm tap opens the app": R4 + R5 + R8 + the haptic, synchronous.
@MainActor @Test func firmTwoFingerTapWithinThreeSecondsBringsFigmaAndClicksNothing() {
    let world = World(apps: ["Figma"], accessGranted: true)
    world.launcher.start()
    world.launcher.setAssignment(.app(world.app("Figma")), for: .two)

    let firm = TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 2, click: .firm).frames
    world.hardware.touch(firm, on: Trackpad.macBook14.id)

    #expect(world.system.broughtToFront == [world.app("Figma")])
    #expect(world.hardware.pressVerdicts == [.drop, .drop])      // press and release withheld: nothing right-clicked
    #expect(world.hardware.feedback == [Trackpad.macBook14.id])
}

// R7 + R11 live, both ways, no relaunch; the icon's input does not move.
@MainActor @Test func grantingAndRevokingFollowLive() {
    let world = World()
    world.launcher.start()
    #expect(!world.launcher.isAccessibilityGranted && !world.hardware.isBlockingClicks)

    world.access.set(granted: true)
    #expect(world.launcher.isAccessibilityGranted && world.hardware.isBlockingClicks)
    #expect(world.launcher.activity == .active)

    world.access.set(granted: false)
    #expect(!world.launcher.isAccessibilityGranted && !world.hardware.isBlockingClicks)
}
```

```swift
// The recognizer's own seam: the frame-side half of R4, asserted frame by frame, and R1's distinct count.
@Test(arguments: [(landMS: 2_900, blocks: true), (landMS: 3_100, blocks: false)])
func blockingWindowIsTheFirstThreeSecondsAfterTheThumbLands(landMS: Int, blocks: Bool) {
    let h = HandFrames()
    var recognizer = GestureRecognizer(handMode: .right, surface: .macBook14)
    let frames = [
        h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]),
        h.frame(atMS: landMS, [h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 62, 45)]),
    ]
    #expect(frames.map { recognizer.step($0).blocksClicks } == [false, blocks])
}

@Test func fourFingersCountEvenWhenTheFirstLiftsBeforeTheLastLands() {
    let frames = TouchScript(.macBook14).thumb(atMM: (10, 10))
        .tap(fingers: 4, stagger: .milliseconds(40), hold: .milliseconds(100)).frames
    #expect(fired(frames) == [.four])
}
```

```swift
// The click filter's own seam: R5 as a pure table.
@Test func aPressIsBlockedOrPassedWhole() {
    var filter = ClickFilter()
    let press = PressID(button: 0, number: 41)
    #expect(filter.decide(.press(press), trackpadBlocking: true) == .drop)
    #expect(filter.decide(.drag(button: 0), trackpadBlocking: false) == .passAsMove)   // pointer still moves (R6)
    #expect(filter.decide(.release(press), trackpadBlocking: false) == .drop)           // window closed meanwhile
    #expect(!filter.isWithholdingPress)
}
```

```swift
// LauncherUI: the hint is one more sibling after the activity switch; both notices share one view.
if !launcher.isAccessibilityGranted {
    SettingsNotice(
        message: "Clicks aren't blocked during gestures. Allow Accessibility access to block them.",
        button: "Grant access…",
        open: { actions.openSettings(.accessibility) })
}
```

### Shape

**Data first.**

- *What a frame says about the button.* `TouchFrame.buttonDown: Bool` becomes `TouchFrame.press: Press?`. `nil` means no button is down. `.click` means a button is down and macOS is delivering that press to apps, from any pointing device. `.blocked` means the click filter is withholding a press from apps. A single initializer, `Press(withheld:buttonDown:)`, holds the precedence: a withheld press is `.blocked` whatever the button state reads. Both hardware adapters use it, which is why the `buttonState` question does not matter (per `type-system-discipline`, `boundary-discipline`).
- *What a frame meant.* `step(_:)` returns `Recognition { fired: Gesture?; blocksClicks: Bool }`. `blocksClicks` is this trackpad's half of R4: a thumb that this recognizer saw land less than 3 s ago is still anchored, and another contact is down.
- *What the recognizer remembers.* `Anchor` gains `landedAt: FrameTime?`. It is nil when the thumb was already down on the recognizer's first frame, meaning a reconcile restarted the device under a resting thumb; such a thumb anchors but opens no blocking window. `previouslyDown` becomes `Set<TouchID>?`, nil before the first frame. That is the only place the "first frame" fact lives. The tap state becomes a `Tap` value: `start`, `down: [TouchID: SurfacePoint]` (landing points, for the drag check) and `touched: Set<TouchID>` (R1's count). `down.keys ⊆ touched` holds because `Tap.land(_:)` is the only way to add a finger.
- *What the event tap sees.* `PointerEvent` is `.press(PressID)`, `.release(PressID)`, `.drag(button:)` or `.pressure`. `PressID` is the button plus `kCGMouseEventNumber`, which matching down and up events share (sourced). `PointerVerdict` is `.pass`, `.drop` or `.passAsMove`. `ClickFilter` is a pure value holding `withheld: [button: PressID]`. `CGEvent`, `CGEventType` and `CFMachPort` never leave `LauncherPlatform`.
- *What the model shows.* `isAccessibilityGranted` is a stored observed field written only by `reconcile()`. It is not part of `GestureActivity`, so the icon cannot change because of it (R11). Window visibility becomes a private three-state value, `closed | open | heldOpen`. `isWindowOpen` is derived from it.

**Load-bearing decisions.**

1. *The recognizer owns the frame-side half of click blocking.* R4's predicate is a function of the anchor and the frame clock, and the recognizer is the only module that holds the anchor. So `step` computes `blocksClicks` after its state update, from `state.anchor`, `anchor.landedAt`, `frame.time` and the frame's contacts. The 3 s constant sits beside the 400 ms one in `GestureRules`. No timer is needed. Frames keep arriving while the thumb rests, so expiry is seen on the next frame (within about 10 ms). When nothing touches, nothing is anchored and nothing is blocked. A reconcile cannot restart the window: a fresh recognizer still re-adopts a resting thumb, as in 001, but with `landedAt == nil`, so no window opens. The failure is under-blocking, which is the safe direction. Restarting the window would break R4's "after the 3 seconds, clicks MUST work again" whenever an internal reconcile happened after 3 s (per `model-the-domain`).
2. *The filter's own decision is the single truth about a press.* `ClickFilter.decide` drops a press-down exactly when some running trackpad's latest `blocksClicks` is true at that event. It then drops the release with the same `PressID`, turns that press's drags into plain moves so the pointer keeps moving (R6), and drops pressure events while any press is withheld. Every other event passes unchanged. The frame thread does not work out "was this press blocked" for itself. It reads the filter (`isWithholdingPress`) when it samples the press. The recognizer's press rule then shrinks to one line: `.click` cancels a tap, `.blocked` does not (R8). The order of events cannot produce "a click and a gesture". A press that beats its finger's landing frame passes as a click, frames read `.click`, and the tap cancels. That is today's behaviour, recorded as the accepted race. The rule holds for either answer to the `buttonState` question (per "single source of truth per invariant").
3. *Click blocking is part of the hardware port, not a port of its own.* The tap's only input is the per-trackpad `blocksClicks` flags, and its only output the frame path reads is "withholding a press". Both are frame-path state. `TrackpadHardware.run` gains one argument, `blockClicks: Bool`. `run` already means "forget everything, start exactly this", and that now includes "remove the tap; install a fresh one if asked and allowed". Every reset is structural. The per-trackpad flags live in each `DeviceSession`, which `run` replaces. The filter's memory lives in the `ClickTap` that `run` replaces. If the system refuses the tap, nothing is filtered, every press reads `.click`, and taps behave exactly as without access (per `make-operations-idempotent`).
4. *The tap runs on its own thread's run loop.* Every click in the login session waits for the tap's callback. On the main run loop, that wait would include the app's UI work: the picker's enumeration, LaunchServices lookups, SwiftUI layout. It would also risk a stall: main blocked in a WindowServer call while the WindowServer waits on our tap, until the tap is disabled by timeout. A dedicated thread, `userInteractive`, holds only the tap's run loop source. It sleeps in the kernel between events and ends when `run` removes the tap. The thread retains its `ClickTap`, so no callback can outlive the object behind its `userInfo` pointer. On `tapDisabledByTimeout` or `tapDisabledByUserInput`, the callback forgets every withheld press (their releases may have passed while the tap was disabled) and re-enables the tap.
5. *Permission is one more push-only port, and the model filters the noise.* `AccessibilityPermission` has `onChange` ("may have changed"), `isGranted()` (a fresh `AXIsProcessTrusted()`) and `prompt()`. The real adapter forwards every `com.apple.tcc.access.changed` notification. That keeps its push testable with `notify_post`. `Launcher` reconciles only when the fresh value differs from `isAccessibilityGranted`, so another app's camera grant does not restart the devices and drop a tap in progress. `reconcile()` arms blocking with `blockClicks: activity.isActive && isAccessibilityGranted`. That gives R4 "No blocking while gestures are inactive" and R9 "Declined" in one expression. Revoke tears the tap down through the same path, without relying on macOS to stop delivery.
6. *First launch prompts once and holds the window open under the prompt.* "First launch" is the existing derived fact (no stored record), so no new stored field is needed. `start()` calls `prompt()` before the first save, next to the login item and for the same crash reason, unless access is already granted. It then opens the window as `heldOpen`. The shell now sends two kinds of close. Explicit closes (icon click, Escape) call `closeWindow()`. Soft closes (an outside click, the panel resigning key) call `dismissWindow()`, which a held window ignores. The hold ends at the first explicit close or fired gesture. Without it, R10 fails as soon as the prompt appears.
7. *Distinct fingers, 400 ms, fire on lift.* The tap's count is `touched.count`. A re-landed finger keeps its `TouchID` (when the driver reuses it) and counts once. `Gesture(fingerCount:)` is nil above four. Every other rule stays as it is: the anchor corner, the drag check, thumb before fingers, spoil recovery, and a reused ID on a lone finger starting a new tap (R1's own definition).
8. *Rules stay structure.* The scanner stops banning the two Accessibility APIs the design uses. It confines each one to the single file that owns it, and adds bans for what R6 and R9 forbid. Details are in the policy sketch below.

**Depth.**

| Module | Public surface | What it hides |
|---|---|---|
| `GestureRecognizer` | `init`, `step` → `Recognition` (2 fields) | All of R1–R3, the frame-side half of R4 (anchor time, 3 s, another contact, inherited thumbs), R8's press rule |
| `ClickFilter` | `init`, `decide`, `isWithholdingPress`, `forgetWithheldPresses` | R5's whole-press memory, drags as moves, pressure, recovery from missed releases |
| `TrackpadHardware` | 4 members (`run` gains one `Bool`) | Plus: the event tap, its thread and teardown, the mask, `CGEvent` parsing and rewriting, re-enabling, per-trackpad flags merged at the read, press sampling |
| `AccessibilityPermission` | 3 members | `AXIsProcessTrusted`, the prompt option, the TCC Darwin notification |
| `Launcher` | 5 read-only properties, 6 intents | Plus: arming (active and granted), the real-change filter, prompt-once, holding the window |

The interface grows by one field on `step`'s result, one argument on `run`, one port with three members, one observed property and one intent (`dismissWindow`). Everything else is inside.

**Concurrency** (Swift 6 language mode, one writer per field).

- *Main actor:* `Launcher`, the ports, every adapter's public surface, `ClickTap.install()` and `remove()`, and the TCC notification handler (registered on `DispatchQueue.main`, entered with `MainActor.assumeIsolated`, like IOKit and wake).
- *Frame thread* (per device): sample the press (reads the `ClickTap`'s filter under its `Mutex`), step the recognizer (its `Mutex`, never contended), then write that session's `blocking` flag (its own `Mutex<Bool>`). Gestures still hop to main with `Task { @MainActor }`.
- *Tap thread:* reads the `sessions` registry, copying the sessions out before reading each flag (no nested locks), then decides under the filter's `Mutex`.
- *Writers:* `sessions` is written by main (`run`); each `blocking` flag by its device's frame callback; the filter by the tap thread; the tap's port by main (install and remove), with the tap thread only re-enabling through it. No two threads write the same field. Merging across trackpads happens at the read (per `separate-before-serializing-shared-state`).

**Requirement trace and seams.**

| R | Carried by | Verified at |
|---|---|---|
| R1 | `Tap.touched`; `Gesture(fingerCount:)` nil above 4 | Recognizer seam: early lift before the last lands → `.four`; rolling five → nothing; two 1-finger taps 200 ms apart → `[.one, .one]`; a reused ID landing again mid-tap → `.four` (`HandFrames`). `Launcher` seam: Spotify not Notion; Arc twice. Bounce IDs on hardware: manual |
| R2 | `GestureRules.maxTapDuration = 400 ms` | Recognizer seam: uneven 3-finger (stagger 75, hold 200) → `.three` once; 500 ms → nothing; 390/410 boundary rows |
| R3 | Fire on the frame the last finger is gone (unchanged) | Recognizer seam: the per-frame `fired` list is non-nil exactly on the lift frame. Haptic timing: manual |
| R4 | `Recognition.blocksClicks`, `Anchor.landedAt`, `clickBlockingWindow`, `ClickFilter.decide`, arming in `reconcile` | Recognizer seam, per frame: finger within 3 s → true; 2.9/3.1 s; thumb alone; thumb lifted; slid out; inherited thumb → false. Filter seam: decisions with the flag on and off. `Launcher` seam: firm tap → `[.drop, .drop]`; after 4 s → `[.pass, .pass]`; inactive and declined → `!isBlockingClicks`; a reconcile at 3.5 s does not re-block. Real clicks and Force Click: manual |
| R5 | `ClickFilter`'s per-button memory, matched by `PressID` | Filter seam: a dropped press's release drops with the flag off; a passed press's release passes with it on; a stale entry clears on the next release or press of that button. `Launcher` seam: thumb lands during a pressed drag → `[.pass, .pass]`; press at 2.91 s, release at 3.10 s → `[.drop, .drop]`. Window drag on hardware: manual |
| R6 | Tap mask (no move, scroll or keyboard bits); drags rewritten only during a withheld press | Filter seam (drag rows); LauncherPlatformTests (mask bits exactly; `.passAsMove` sets `.mouseMoved`); `Launcher` seam: a press with only the thumb down → `.pass`. Pointer, scroll and a real mouse: manual |
| R7 | `onChange` → change filter → `reconcile` → `run(blockClicks:)` → install or remove | `Launcher` seam: `set(granted:)` both ways. LauncherPlatformTests: `notify_post` of the TCC name reaches `onChange` within the 5 s bound. Grant and revoke in System Settings: manual |
| R8 | `TouchFrame.Press`; `.click` cancels, `.blocked` does not; `Press(withheld:buttonDown:)` | Recognizer seam: `.blocked` mid-tap fires, `.click` cancels. `Launcher` seam: firm tap fronts Figma; press held 1 s → nothing fronted, `[.drop, .drop]`; without access → nothing fronted, no verdicts; after 3 s → nothing fronted, `[.pass, .pass]`. Haptic: manual |
| R9 | One port and one tap; the mask; the policy gate | `Launcher` seam: declined → gesture fronts and `!isBlockingClicks`. Source gate: banned and confined tokens. TCC log over install to first gesture: manual |
| R10 | `start()`: `prompt()` unless granted, before the save; `.heldOpen` | `Launcher` seam: first launch not granted → `prompts == 1`, open, survives `dismissWindow()`, closes on `closeWindow()`; first launch granted → `prompts == 0` and an ordinary window; relaunch → still 1. Real alert and stacking: manual |
| R11 | `isAccessibilityGranted` (outside `GestureActivity`); `SettingsNotice`; `SettingsPane.accessibility`; layout refit loop | `Launcher` seam: live both ways; `activity` unchanged. Copy, pane, refit while open: manual |

**Test handles.**

| Thing | Handle |
|---|---|
| Clock behind the 400 ms limit and the 3 s window | `TouchFrame.time`; no clock object exists |
| The blocking predicate, frame by frame | `step(_:).blocksClicks` |
| "Blocking in effect" as the recognizer sees it | `TouchFrame.press == .blocked` (`HandFrames.frame(press:)`, `TouchScript.tap(click:)`) |
| When a physical press starts | `TouchScript.ClickTiming`: `.onLanding` (beats the landing frame: the race), `.firm` (from the frame after landing), `.midway` |
| The tap's pass/drop decision | `ClickFilter.decide`, pure |
| The tap at the high seam | `InMemoryTrackpads` arms a real `ClickFilter` on `run(blockClicks: true)`, feeds it each scripted press edge using the previous frame's flags (as the real tap reads them), and records `pressVerdicts`; `isBlockingClicks` |
| Releases lost while the tap was disabled | `ClickFilter.forgetWithheldPresses()` |
| Trust and its push | `InMemoryAccessibilityPermission.set(granted:)` invokes `onChange` synchronously; `broadcast()` is another app's TCC change |
| The prompt | `InMemoryAccessibilityPermission.prompts` |
| The real push | `notify_post("com.apple.tcc.access.changed")` in LauncherPlatformTests |
| The window under the prompt | `dismissWindow()` against `closeWindow()` |
| A reconcile under a resting thumb | `preferences.set` between two scripts; the second script's first frame has the thumb `.down` |

**Deliberately not done.** No device attribution of clicks (`kCGMouseEventSubtype` is unproven for trackpad clicks; the R6 mouse scenario is met by "another finger is on the trackpad"). No report of whether the tap is live (R8 needs none, and the hint is about the permission). No grace delay, timer, deadline or second clock. No diffing in `run`. No stored "prompted" flag. Nothing in the mask beyond buttons, drags and pressure: no keyboard, scroll or plain movement. No posting or synthesising of events.

#### Module map

```
LauncherCore     (Foundation, Observation)   GestureRules (+ clickBlockingWindow, 400 ms) · TouchFrame.Press · Recognition ·
                                              GestureRecognizer (distinct count, anchor time, blocksClicks) ·
                                              PressID · PointerEvent · PointerVerdict · ClickFilter ·
                                              ports: TrackpadHardware (run + blockClicks), TrackpadPreferences,
                                              AccessibilityPermission (new), SystemActions · Launcher
LauncherPlatform (+ ApplicationServices,      MultitouchTrackpads (run installs or removes the ClickTap) · DeviceSession (press
                  notify)                     sampling, blocking flag) · sessions + anyTrackpadBlocksClicks · ClickTap (tap,
                                              thread, callback, PointerEvent parsing + mask, verdict application) ·
                                              SystemAccessibilityPermission · TouchFrame(parsing:press:)
LauncherUI                                    MenuBarShell (closeWindow and dismissWindow mapping, layout refit loop) ·
                                              LauncherView (+ the hint) · SettingsNotice · SettingsPane · LauncherActions
TrackpadLauncher app target                   composition root (+ SystemAccessibilityPermission)
Tests                                         LauncherCoreTests: recognizer, ClickFilter, Launcher seam, SourcePolicyTests;
                                              InMemoryTrackpads (fake tap), InMemoryAccessibilityPermission, TouchScript
                                              (.firm), HandFrames (press:), World (one makeLauncher) ·
                                              LauncherPlatformTests: TCC push, PointerEvent parsing, mask, rewrite
```

#### LauncherCore: recognizer and its inputs

```swift
import Foundation

/// Every fixed number in gesture recognition and click blocking, in one place. Not user-tunable.
package enum GestureRules {
    static let cornerWidth = 0.20
    static let cornerHeight = 0.25
    static let anchorReleaseMarginMM = 2.0
    /// First finger down to last finger up (R2). Strictly greater fails; boundary tests straddle it (390/410).
    static let maxTapDuration = Duration.milliseconds(400)
    static let dragThresholdMM = 3.0
    /// Clicks are blocked for this long after a thumb anchors (R4). Strictly less passes; tests straddle (2.9/3.1).
    static let clickBlockingWindow = Duration.seconds(3)
}

/// Everything the recognizer needs about one instant on one trackpad. A complete snapshot.
public struct TouchFrame: Sendable {
    public let time: FrameTime
    public let touches: [Touch]
    /// nil: no mouse button is down.
    public let press: Press?

    public init(time: FrameTime, touches: [Touch], press: Press?) { fatalError("not implemented") }

    /// A pressed button, as it matters to a tap (R8).
    public enum Press: Equatable, Sendable {
        /// macOS is delivering this press to apps as a click (any pointing device). It cancels a tap.
        case click
        /// The click filter is withholding this press from apps (R4, R5). It is part of the tap.
        case blocked

        /// The one precedence rule, used by both hardware adapters. A withheld press is `.blocked` whatever the
        /// session's button state reads. (Whether a dropped press still reads as down is unknown; it does not matter.)
        public init?(withheld: Bool, buttonDown: Bool) {
            if withheld { self = .blocked } else if buttonDown { self = .click } else { return nil }
        }
    }
}

/// What one frame meant on one trackpad.
public struct Recognition: Equatable, Sendable {
    /// At most once per tap, on the frame where its last finger is gone (R3).
    public let fired: Gesture?
    /// This trackpad's half of R4: a thumb this recognizer saw land less than 3 s ago is still anchored, and another
    /// contact is down. Whether a press is really blocked also needs the click filter armed (access granted, gestures
    /// active), which the recognizer never knows.
    public let blocksClicks: Bool
}

/// The tap-with-anchored-thumb rules for ONE trackpad, as a pure state machine. Feed every frame in order.
public struct GestureRecognizer: Sendable {
    public init(handMode: HandMode, surface: SurfaceSize) { fatalError("not implemented") }

    public mutating func step(_ frame: TouchFrame) -> Recognition {
        // TODO
        // let isFirstFrame = previouslyDown == nil;  let before = previouslyDown ?? []
        // down   = frame.touches keyed by id (first wins)
        // reused = ids in `before` whose touch is .landing           (lifted AND landed anew on this frame)
        // lifted = before − down.keys, plus reused
        // landed = touches that are .landing or not in `before`
        // defer { previouslyDown = Set(down.keys) }
        //
        // 1. Anchor maintenance (unchanged): anchor lifted, reused, or outside corner.holds → state = .idle
        // 2. switch state
        //    .idle:
        //      if let thumb = landed.first(where: corner.admits):
        //          // A contact already down when this recognizer started (a reconcile under a resting hand) anchors,
        //          // but opens no blocking window: its real landing time is unknown.
        //          anchor = Anchor(id: thumb.id, landedAt: isFirstFrame && thumb.phase == .down ? nil : frame.time)
        //          state = down.count == 1 ? .armed(anchor) : .spoiled(anchor)
        //    .armed(a):
        //      fingers = landed minus a
        //      if !fingers.isEmpty: state = frame.press == .click ? .spoiled(a) : .tapping(a, Tap(start: frame.time, landing: fingers))
        //    .tapping(a, tap):
        //      tap.down.removeValues(forKeys: lifted)
        //      if frame.press == .click                                  // a delivered click cancels; a blocked press does not (R8)
        //         || frame.time - tap.start > GestureRules.maxTapDuration
        //         || any finger in tap.down is > dragThresholdMM from its landing point → state = .spoiled(a)
        //      else if tap.down.isEmpty:                                 // the last finger is gone: fire now, no wait (R3)
        //          fired = Gesture(fingerCount: tap.touched.count)       // distinct fingers (R1); nil above four
        //          new = landed minus a
        //          state = new.isEmpty ? .armed(a) : .tapping(a, Tap(start: frame.time, landing: new))
        //      else:
        //          for t in landed minus a { tap.land(t) }               // a re-landed id is already in `touched`: counts once
        //          state = .tapping(a, tap)
        //    .spoiled(a): if down.keys all == a.id → .armed(a)           // unchanged
        // 3. blocksClicks = state.anchor.flatMap { a in a.landedAt.map { at in
        //        frame.time - at < GestureRules.clickBlockingWindow && down.keys.contains { $0 != a.id } } } ?? false
        //    return Recognition(fired: fired, blocksClicks: blocksClicks)
        fatalError("not implemented")
    }

    private struct Anchor: Sendable {
        let id: TouchID
        /// When this recognizer saw the thumb land. nil: the thumb was already down on the first frame.
        let landedAt: FrameTime?
    }

    private struct Tap: Sendable {
        let start: FrameTime
        /// Fingers down now, with their landing points (the drag check).
        var down: [TouchID: SurfacePoint]
        /// Every finger that touched during this tap (R1). Always a superset of `down.keys`.
        private(set) var touched: Set<TouchID>
        init(start: FrameTime, landing: [Touch]) { fatalError("not implemented") }
        /// The only way a finger joins: it goes into both `down` (new origin) and `touched`.
        mutating func land(_ touch: Touch) { fatalError("not implemented") }
    }

    private enum State: Sendable {
        case idle
        case armed(Anchor)
        case tapping(Anchor, Tap)
        case spoiled(Anchor)
        var anchor: Anchor? { fatalError("not implemented") }
    }

    private let corner: AnchorCorner
    private let surface: SurfaceSize
    private var state: State = .idle
    /// Contacts down on the previous frame. nil until the first frame.
    private var previouslyDown: Set<TouchID>? = nil
}
```

#### LauncherCore: the click filter

```swift
/// One press: its button and its `kCGMouseEventNumber`, which the press's down and up share.
public struct PressID: Hashable, Sendable {
    public let button: Int        // 0 left, 1 right, 2+ other
    public let number: Int64
    public init(button: Int, number: Int64) { fatalError("not implemented") }
}

/// Everything the click tap is ever told about, parsed. The mask admits nothing else (R9).
public enum PointerEvent: Equatable, Sendable {
    case press(PressID)
    case release(PressID)
    /// The pointer moved with `button` held.
    case drag(button: Int)
    /// A Force Touch pressure or stage change.
    case pressure
}

public enum PointerVerdict: Equatable, Sendable {
    case pass
    case drop
    /// Delivered as a plain pointer move: the pointer keeps moving, and no app sees a drag whose press it never got.
    case passAsMove
}

/// R4–R6 for one event stream, as a pure state machine. One filter per click tap, fed every event in order on the
/// tap's thread. It knows no clock and no device. `trackpadBlocking` is "some running trackpad's latest
/// `Recognition.blocksClicks` is true", read when the event arrives.
public struct ClickFilter: Sendable {
    public init() {}

    public mutating func decide(_ event: PointerEvent, trackpadBlocking: Bool) -> PointerVerdict {
        // TODO
        // .press(p):   withheld[p.button] = trackpadBlocking ? p : nil      // a new press of a button ends any stale one
        //              return trackpadBlocking ? .drop : .pass
        // .release(p): defer { withheld[p.button] = nil }                   // that button is up, whatever came before
        //              return withheld[p.button] == p ? .drop : .pass        // blocked or passed whole (R5), flag ignored
        // .drag(b):    return withheld[b] != nil ? .passAsMove : .pass
        // .pressure:   return withheld.isEmpty ? .pass : .drop              // a Force Click's stages belong to its press
        fatalError("not implemented")
    }

    /// From a dropped press until its release. Frames record the press as `.blocked` while this is true.
    public var isWithholdingPress: Bool { !withheld.isEmpty }

    /// The system disabled the tap, and releases may have passed meanwhile. Forget every withheld press.
    public mutating func forgetWithheldPresses() { withheld = [:] }

    private var withheld: [Int: PressID] = [:]
}
```

#### LauncherCore: ports

```swift
/// The multitouch hardware, and the click blocking that rides on its frames. Real: MultitouchTrackpads.
/// Test: InMemoryTrackpads.
@MainActor public protocol TrackpadHardware: AnyObject {
    var onEvent: (@MainActor (TrackpadEvent) -> Void)? { get set }
    func connected() -> [Trackpad]
    /// Forgets every session, removes the click tap, stops every device, then starts exactly `trackpads` with a fresh
    /// recognizer each and, if `blockClicks` and `trackpads` is not empty, a fresh click tap. Idempotent.
    /// The tap needs Accessibility. If the system refuses it, nothing is filtered, every press reads `.click`, and
    /// taps behave exactly as without access (R8, R9).
    func run(_ trackpads: [Trackpad], handMode: HandMode, blockClicks: Bool)
    func playFeedback(on trackpad: TrackpadID)
}

/// The Accessibility permission. Real: SystemAccessibilityPermission. Test: InMemoryAccessibilityPermission.
@MainActor public protocol AccessibilityPermission: AnyObject {
    /// On the main actor whenever trust MAY have changed: macOS broadcasts every permission change of every app.
    /// Carries no data. Re-read with `isGranted()`.
    var onChange: (@MainActor () -> Void)? { get set }
    /// Read fresh. Never prompts.
    func isGranted() -> Bool
    /// Shows the system's Accessibility prompt. Returns at once; the prompt belongs to another process.
    func prompt()
}
```

#### LauncherCore: the Launcher

```swift
@MainActor @Observable
public final class Launcher {
    public private(set) var rows: [GestureRow] = []
    public var isWindowOpen: Bool { window != .closed }
    public var handMode: HandMode { settings.handMode }
    public var activity: GestureActivity { GestureActivity(connected: Set(connected.map(\.kind)), values: preferenceValues) }
    /// Drives the Accessibility hint (R11). Deliberately not part of `activity`, so the icon never reads it.
    public private(set) var isAccessibilityGranted = false

    private var settings: Settings
    private var connected: [Trackpad] = []
    private var preferenceValues: [TrackpadKind: TrackpadPreferenceValues] = [:]
    private var window: Window = .closed
    @ObservationIgnored private let isFirstLaunch: Bool
    @ObservationIgnored private let hardware: any TrackpadHardware
    @ObservationIgnored private let preferences: any TrackpadPreferences
    @ObservationIgnored private let access: any AccessibilityPermission
    @ObservationIgnored private let system: any SystemActions
    @ObservationIgnored private let catalog: AppCatalog
    @ObservationIgnored private let store: SettingsStore

    /// `.heldOpen` is the first-launch window under the system's Accessibility prompt. The prompt takes focus when it
    /// appears, and its buttons are outside clicks; both would close an ordinary window before the user saw the
    /// hint (R10). A held window closes only on an explicit close or a fired gesture.
    private enum Window: Equatable { case closed, open, heldOpen }

    public init(hardware: any TrackpadHardware, preferences: any TrackpadPreferences, access: any AccessibilityPermission,
                system: any SystemActions, catalog: AppCatalog, store: SettingsStore) { fatalError("not implemented") }

    public func start() {
        hardware.onEvent = { [unowned self] event in
            switch event {
            case .gesture(let fired): fire(fired)
            case .trackpadsChanged: reconcile()
            }
        }
        preferences.onChange = { [unowned self] in reconcile() }
        // The broadcast covers every app and service: only a change of OUR trust re-runs the devices.
        access.onChange = { [unowned self] in if access.isGranted() != isAccessibilityGranted { reconcile() } }
        reconcile()
        guard isFirstLaunch else { return }
        // Both effects come before the first save: a crash in between repeats them next time, never loses them.
        system.registerLoginItem()
        let prompting = !isAccessibilityGranted
        if prompting { access.prompt() }   // R10: once, unless already granted
        store.save(settings)
        window = prompting ? .heldOpen : .open
        rows = makeRows()
    }

    public func setAssignment(_ choice: AppChoice, for gesture: Gesture) { fatalError("not implemented") }   // unchanged
    public func setHandMode(_ mode: HandMode) { fatalError("not implemented") }                              // unchanged

    public func openWindow() {
        if window == .closed { window = .open }
        rows = makeRows()
    }

    /// Icon click, Escape: always closes.
    public func closeWindow() { window = .closed }

    /// An outside click, or the panel losing focus: closes unless the window is held open under the first-launch prompt.
    public func dismissWindow() { if window == .open { window = .closed } }

    /// The one convergent operation: launch, hot-plug, wake, preference, hand mode, and now trust changes.
    private func reconcile() {
        connected = hardware.connected()
        preferenceValues = preferences.current()
        isAccessibilityGranted = access.isGranted()
        let active = activity.isActive
        // R4 "No blocking while gestures are inactive" and R9 "Declined", in one expression.
        hardware.run(active ? connected : [], handMode: settings.handMode, blockClicks: active && isAccessibilityGranted)
    }

    private func fire(_ event: GestureEvent) {
        // unchanged guards: inactive, unassigned, missing; then feedback, bring to front, and:
        // window = .closed   (a gesture closes even a held window)
        fatalError("not implemented")
    }

    private func makeRows() -> [GestureRow] { fatalError("not implemented") }   // unchanged
}
```

#### LauncherPlatform: frame path, click tap, permission

```swift
import CoreGraphics
import LauncherCore
import Synchronization

/// One running trackpad. Replaced by every `run`, which resets its blocking flag by construction.
final class DeviceSession: Sendable {
    let trackpad: TrackpadID
    private let recognizer: Mutex<GestureRecognizer>   // stepped only by this device's frame callback: never contended
    private let blocking = Mutex(false)                // writer: this device's frame callback; reader: the click tap
    private let clickTap: ClickTap?                    // installed by the same `run`, if any
    private let deliver: @Sendable (GestureEvent) -> Void

    init(trackpad: TrackpadID, recognizer: GestureRecognizer, clickTap: ClickTap?,
         deliver: @escaping @Sendable (GestureEvent) -> Void) { fatalError("not implemented") }

    /// Frame thread.
    func receive(_ touches: UnsafeMutableRawPointer?, count: Int32, timestamp: Double) {
        // TODO
        // let press = TouchFrame.Press(withheld: clickTap?.isWithholdingPress ?? false, buttonDown: anyMouseButtonDown())
        // let recognition = recognizer.withLock { $0.step(TouchFrame(parsing: touches, count: count, timestamp: timestamp, press: press)) }
        // blocking.withLock { $0 = recognition.blocksClicks }
        // if let g = recognition.fired { deliver(GestureEvent(gesture: g, trackpad: trackpad)) }
        fatalError("not implemented")
    }

    /// Click tap thread.
    var blocksClicks: Bool { blocking.withLock { $0 } }
}

/// Written by `run` (main). Read by the frame callback and the click tap.
let sessions = Mutex<[UInt: DeviceSession]>([:])

/// R4's "a trackpad is inside its blocking window", merged across trackpads at the read.
/// Copies the sessions out first, so no lock is held while another is taken.
func anyTrackpadBlocksClicks() -> Bool { Array(sessions.withLock { $0.values }).contains { $0.blocksClicks } }

extension MultitouchTrackpads {
    public func run(_ trackpads: [Trackpad], handMode: HandMode, blockClicks: Bool) {
        // TODO
        // guard let framework else { return }
        // sessions.withLock { $0 = [:] }                 // in-flight frames find nothing; the tap now sees no blocking trackpad
        // clickTap?.remove(); clickTap = nil             // a withheld press's release may now reach apps: a harmless stray up
        // unregister callbacks, stop devices, close actuators (unchanged)
        // if blockClicks && !trackpads.isEmpty { clickTap = ClickTap.install() }   // nil: refused, nothing filtered
        // for each wanted device: DeviceSession(trackpad:, recognizer: fresh, clickTap: clickTap, deliver: hop to main)
        //                          actuator, insert into sessions, register callback, start (unchanged)
        // Postcondition: frames flow from exactly `trackpads`; a tap exists iff asked, allowed and trackpads exist.
        fatalError("not implemented")
    }
}
```

```swift
import CoreGraphics
import Foundation
import LauncherCore
import Synchronization

/// The app's one event tap: an active session tap over mouse buttons, drags and pressure only (R9).
/// It exists from the `run` that armed click blocking until the next `run`.
/// Threads: installed and removed on main. Its callback runs on the tap's own `userInteractive` thread, whose run loop
/// holds only this tap's source and ends when the tap is removed. That thread retains the ClickTap, so no callback
/// outlives the object behind its `userInfo`.
final class ClickTap: Sendable {
    private let filter = Mutex(ClickFilter())          // writer: the tap thread; reader: frame threads
    private let port = Mutex<CFMachPort?>(nil)         // writer: main (install, remove); the tap thread only re-enables
    private let runLoop = Mutex<CFRunLoop?>(nil)       // set by the tap thread; main stops it on remove

    /// nil when the system refuses the tap (no Accessibility).
    @MainActor static func install() -> ClickTap? {
        // TODO
        // let tap = ClickTap()
        // guard let machPort = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
        //         eventsOfInterest: PointerEvent.tapMask, callback: clickTapCallback,
        //         userInfo: Unmanaged.passUnretained(tap).toOpaque()) else { return nil }
        // tap.port.withLock { $0 = machPort }
        // let thread = Thread { [tap] in                // retains `tap` until the loop ends
        //     tap.runLoop.withLock { $0 = CFRunLoopGetCurrent() }
        //     tap.port.withLock { p in p.map { CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, $0, 0), .commonModes) } }
        //     CFRunLoopRun()                             // returns once `remove()` invalidates the port and stops the loop
        // }
        // thread.qualityOfService = .userInteractive; thread.start()
        // return tap
        fatalError("not implemented")
    }

    /// Frame thread.
    var isWithholdingPress: Bool { filter.withLock { $0.isWithholdingPress } }

    /// Main. Idempotent. Never relies on macOS to stop delivery after a revoke.
    @MainActor func remove() {
        // TODO
        // port.withLock { if let p = $0 { CGEvent.tapEnable(tap: p, enable: false); CFMachPortInvalidate(p) }; $0 = nil }
        // runLoop.withLock { $0.map(CFRunLoopStop) }
        fatalError("not implemented")
    }

    /// Tap thread.
    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        // TODO
        // if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        //     filter.withLock { $0.forgetWithheldPresses() }               // releases may have passed while disabled
        //     port.withLock { $0.map { CGEvent.tapEnable(tap: $0, enable: true) } }
        //     return .passUnretained(event)
        // }
        // guard let pointer = PointerEvent(type, event) else { return .passUnretained(event) }
        // let blocking = anyTrackpadBlocksClicks()                         // read before the filter lock
        // return filter.withLock { $0.decide(pointer, trackpadBlocking: blocking) }.apply(to: event)
        fatalError("not implemented")
    }
}

private let clickTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return .passUnretained(event) }
    return Unmanaged<ClickTap>.fromOpaque(userInfo).takeUnretainedValue().handle(type, event)
}

extension PointerEvent {
    /// The tap's whole vocabulary. The mask is built from this list, and a test parses one synthetic event of every
    /// listed type, so the tap is never sent a type the parser does not read. Type 34 is NSEventTypePressure, which
    /// has no public CGEventType case (sourced). There are no keyboard, scroll or plain-move types (R6, R9).
    static let tapTypes: [CGEventType] = [
        .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
        .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, CGEventType(rawValue: 34)!,
    ]
    static var tapMask: CGEventMask { tapTypes.reduce(0) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) } }

    /// The button comes from the type for left and right, and from `mouseEventButtonNumber` for other buttons.
    /// The number comes from `mouseEventNumber`.
    init?(_ type: CGEventType, _ event: CGEvent) { fatalError("not implemented") }
}

extension PointerVerdict {
    /// `.passAsMove` rewrites the event's type to `.mouseMoved` (CGEventSetType) and passes it on.
    func apply(to event: CGEvent) -> Unmanaged<CGEvent>? { fatalError("not implemented") }
}
```

```swift
import ApplicationServices
import LauncherCore
import notify

/// AccessibilityPermission over AX trust and tccd's Darwin notification (probed: delivered about 30 ms after a TCC
/// change, on the main queue). The notification names no app and no service: it only means "re-read".
@MainActor public final class SystemAccessibilityPermission: AccessibilityPermission {
    public var onChange: (@MainActor () -> Void)?
    private var token: Int32 = 0

    /// notify_register_dispatch("com.apple.tcc.access.changed", &token, .main) { [weak self] _ in
    ///     MainActor.assumeIsolated { self?.onChange?() } }
    public init() { fatalError("not implemented") }
    isolated deinit { notify_cancel(token) }

    public func isGranted() -> Bool { AXIsProcessTrusted() }

    /// `AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)`. The key is spelled out
    /// because the imported `kAXTrustedCheckOptionPrompt` is a global `var`, which strict concurrency rejects.
    public func prompt() { fatalError("not implemented") }
}
```

#### LauncherUI

```swift
/// The System Settings panes the window opens. One table; the shell opens the URL, as in 001.
enum SettingsPane {
    case trackpad
    case accessibility
    var url: URL {
        switch self {
        case .trackpad: URL(string: "x-apple.systempreferences:com.apple.preference.trackpad")!
        case .accessibility: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        }
    }
}

struct LauncherActions {
    let installedApps: () -> [AppEntry]
    let chooseOtherApp: (Gesture) -> Void
    let openSettings: (SettingsPane) -> Void   // NSWorkspace.shared.open(pane.url); replaces openTrackpadSettings
    let quit: () -> Void
}

/// A hint plus a System Settings button. Used by the trackpad settings notice and the Accessibility hint, so the two
/// look alike.
struct SettingsNotice: View {
    let message: String
    let button: String
    let open: () -> Void
    var body: some View { fatalError("not implemented") }   // the existing TrackpadSettingsNotice layout
}

// LauncherView.body, inner VStack: rows · HandModeToggle · Divider · switch activity { HintText | trackpad notice } ·
//   if !launcher.isAccessibilityGranted { SettingsNotice(message: "Clicks aren't blocked during gestures. Allow
//   Accessibility access to block them.", button: "Grant access…", open: { actions.openSettings(.accessibility) }) }
//
// MenuBarShell changes:
//   icon click            → toggle with openWindow() / closeWindow()   (explicit)
//   Escape                → closeWindow()                              (explicit)
//   resign key            → dismissWindow() unless it is the status button's own click   (soft)
//   global mouse-down     → dismissWindow()                            (soft)
//   loop 1: Observations { launcher.activity.isActive }                                  → icon only
//   loop 2: Observations { (launcher.activity, launcher.isAccessibilityGranted) }         → refit()
//           (everything the window's height depends on; the hint can appear while the window is open)
//   loop 3: Observations { launcher.isWindowOpen }                                        → show() / hide()  (unchanged)
```

#### Tests: in-memory adapters, fixtures and the source policy

```swift
@MainActor final class InMemoryAccessibilityPermission: AccessibilityPermission {
    var onChange: (@MainActor () -> Void)?
    private(set) var granted: Bool
    private(set) var prompts = 0
    init(granted: Bool = false) { self.granted = granted }
    func isGranted() -> Bool { granted }
    func prompt() { prompts += 1 }
    /// The user flips the switch in System Settings: tccd broadcasts, synchronously here.
    func set(granted: Bool) { self.granted = granted; onChange?() }
    /// Another app's permission change: the same broadcast, nothing of ours changed.
    func broadcast() { onChange?() }
}

/// Real recognizer, real click filter, scripted frames, synchronous delivery.
@MainActor final class InMemoryTrackpads: TrackpadHardware {
    private(set) var running: [TrackpadID: GestureRecognizer] = [:]
    /// The fake click tap: armed iff the last `run` asked for it with trackpads.
    private var clickFilter: ClickFilter?
    var isBlockingClicks: Bool { clickFilter != nil }
    /// What the fake tap did with each scripted press and release, in order.
    private(set) var pressVerdicts: [PointerVerdict] = []
    private var blocking: [TrackpadID: Bool] = [:]     // each device's latest Recognition.blocksClicks
    private var pressInProgress: PressID?
    // onEvent, attached, deaf, feedback, connected, playFeedback, attach, detach, sleep, wake, inject: unchanged

    func run(_ trackpads: [Trackpad], handMode: HandMode, blockClicks: Bool) {
        // running = fresh recognizers; deaf = []; blocking = [:]; pressInProgress = nil
        // clickFilter = blockClicks && !trackpads.isEmpty ? ClickFilter() : nil
        fatalError("not implemented")
    }

    /// Scripted frames carry the physical press as `.click`. Per frame, as on hardware:
    /// 1. a press edge reaches the tap BETWEEN frames, so it is decided on the flags left by the previous frame:
    ///    rising edge → decide(.press(next PressID on button 0)); falling edge → decide(.release(that PressID));
    ///    each verdict is appended to `pressVerdicts` (only while armed);
    /// 2. the frame's press is re-sampled: Press(withheld: clickFilter?.isWithholdingPress ?? false, buttonDown: scripted.press != nil);
    /// 3. step; blocking[id] = recognition.blocksClicks; deliver `fired` inline.
    func touch(_ frames: [TouchFrame], on id: TrackpadID) { fatalError("not implemented") }
}

struct TouchScript {
    /// .onLanding: the press starts on the landing frame, before the tap could know a finger is down (the accepted
    /// race). .firm: from the frame after the first landing to the last lift, as a real firm tap. .midway: unchanged.
    enum ClickTiming { case none, onLanding, firm, midway }
    // tap(... click:) records the press range; `frames` sets press = .click inside it.
}

// HandFrames.frame(atMS:_:press: TouchFrame.Press? = nil)
// fired(_:) → frames.compactMap { recognizer.step($0).fired };  blocking(_:) → frames.map { recognizer.step($0).blocksClicks }
// World(apps:attached:accessGranted: Bool = false): `let access`, and one private makeLauncher(store:) used by init
//   and relaunch(), so the constructor is written once in the tests and once in the composition root.

@Suite struct SourcePolicyTests {
    /// Unchanged: log, network, own files, timer, polling, `nonisolated(unsafe)`.
    /// Removed: "AXIsProcessTrusted", "tapCreate", "CGEventTapCreate" (plan 002 R9 replaces 001 R20; now confined).
    /// Kept and added, each labelled with its requirement:
    ///   "R9 only Accessibility": IOHIDManager, CGRequestListenEventAccess, CGPreflightListenEventAccess,
    ///                            IOHIDRequestAccess, IOHIDCheckAccess, CGRequestPostEventAccess, CGPreflightPostEventAccess
    ///   "R9 no keyboard":        keyDown, keyUp, KeyDown, KeyUp, flagsChanged, FlagsChanged
    ///   "R6 never scrolling":    scrollWheel, ScrollWheel
    ///   "R9 never synthesise":   .post(tap:, CGEventPost, postToPid
    static let banned: [Entry] = [ /* … */ ]

    /// Each permission API lives in exactly one file, the adapter that owns it. Any other hit fails.
    struct Confined: Sendable { let token: String; let onlyIn: String; let rule: String }
    static let confined: [Confined] = [
        Confined(token: "AXIsProcessTrusted", onlyIn: "SystemAccessibilityPermission.swift", rule: "R9 one permission, one adapter"),
        Confined(token: "notify_register", onlyIn: "SystemAccessibilityPermission.swift", rule: "R7 the trust push"),
        Confined(token: "tapCreate", onlyIn: "ClickTap.swift", rule: "R9 the one event tap"),
        Confined(token: "CGEventTapCreate", onlyIn: "ClickTap.swift", rule: "R9 the one event tap"),
    ]
    @Test(arguments: confined) func onlyItsAdapterUses(_ entry: Confined) { /* scan; hits outside `onlyIn` fail */ }
    @Test func confinedScanFindsAUseOutsideItsFile() { /* planted-file self-check */ }
}

// LauncherPlatformTests
//   tccBroadcastReachesOnChange: SystemAccessibilityPermission(); notify_post("com.apple.tcc.access.changed");
//     onChange arrives within the 5 s bound (the AsyncStream pattern of the preference test). Harmless: listeners re-read.
//     The test never calls prompt().
//   everyTapTypeParses: one synthetic CGEvent per PointerEvent.tapTypes entry (CGEvent(mouseEventSource:…), number set
//     via setIntegerValueField(.mouseEventNumber, …)) → the expected PointerEvent.
//   maskIsExactlyButtonsDragsAndPressure: tapMask has bits {1,2,3,4,6,7,25,26,27,34} and no others.
//   passAsMoveRewritesTheType: apply(to:) on a leftMouseDragged leaves a .mouseMoved event.
```

**Docs changed in Phase D.** In `docs/architecture.md`, "Privacy and permissions", the sentence "The app asks for no permission." becomes: "The app asks for one permission, Accessibility, and uses it only to block trackpad clicks during gestures. It never asks for Input Monitoring or any other permission, never reads keyboard events, and works fully without it except click blocking. The Accessibility APIs and the event tap are each confined to one adapter file by the source-scan test." In "Concurrency", "No timers, no polling, no background loops" gains: "the one extra thread is the click tap's run loop, which exists only while click blocking is armed and sleeps until an event arrives." The TCC notification and the click tap join the list of pushes. `docs/domain-model.md` already defines *Click blocking* and *Accessibility hint*. *Tap*'s finger count already reads "fingers that touched during the tap".

### Synthesis decision

### Tradeoffs accepted

- We accept that a press reaching the tap before its finger's landing frame is delivered as a click, and that click cancels the tap. In exchange, a press is never both a click and a gesture, and there is no grace delay (a non-goal).
- We accept that a fresh recognizer gives a resting thumb no blocking window after a reconcile. A thumb anchored 0.5 s before a hot-plug loses its remaining 2.5 s. In exchange, no internal restart can ever block clicks past R4's 3 seconds.
- We accept tearing down and recreating the tap on every reconcile, including trust changes. A press withheld at that moment sends apps a stray release, which they ignore. In exchange, there is one convergent `run` and no second lifecycle path for the tap.
- We accept one extra thread while click blocking is armed, in exchange for click latency that never depends on the app's main thread and no WindowServer stall risk. It sleeps in the kernel between events and costs no idle CPU.
- We accept a mask that includes drags and pressure. While blocking is armed, the tap wakes for every drag in the session (a dictionary lookup each). In exchange, a blocked press is withheld whole: apps never see a drag or a Force Click stage of a press they never got.
- We accept that a mouse click is blocked while the thumb and another finger rest on the trackpad within the 3 s, because no proven field tells the devices apart. The R6 scenario (thumb alone) passes.
- We accept that the first-launch window, held open under the prompt, ignores outside clicks until the user closes it from the icon or with Escape. It may sit over System Settings. In exchange, R10 holds.
- We accept that `InMemoryTrackpads` reimplements about ten lines of press-edge glue around the real `ClickFilter`. In exchange, every R4, R5 and R8 scenario runs synchronously through the whole app.
- We accept two reads of trust per change (the filter's comparison, then `reconcile`), in exchange for `reconcile` re-reading every truth with no special case.
- We accept counting distinct `TouchID`s, which counts a bounce twice if the driver gives a re-landed finger a new ID. In exchange, the rule is one set and needs no position heuristics.

### Alternatives considered

- **A "blocking in effect" input to the recognizer.** The frame path would pass "the tap is live" and the recognizer would decide from its own window whether a press counts. The interface is no smaller, and the complexity it exposes is worse. R5's whole-press rule would live twice, in the filter and in the recognizer, and the two would have to agree at the window's edges and in the landing race. When they disagree, the user gets the click and the gesture. Rejected: two modules owning one decision.
- **A separate `ClickBlocker` port with its own two adapters.** It looks like a seam, but its only input (per-trackpad flags) and its only output (a withheld press) are frame-path state. The real adapters would share module globals, and the two fakes would have to be wired to each other. It is a shallow interface over a seam with nothing on its other side. Rejected.
- **The tap on the main run loop.** This removes the thread and the cross-thread CF handles, but every click in the session would wait on the app's UI thread, with a stall risk while main waits on the WindowServer. Rejected for robustness.
- **A deadline instead of a per-frame flag** ("blocking until T", compared with the event's time in the tap). It is self-expiring, but needs a clock both threads trust. `FrameTime` and `CGEventTimestamp` are not known to share a base, and frames already observe expiry within one frame. Rejected.
- **Restarting the window when a fresh recognizer re-adopts a resting thumb** (`landedAt` always set). One field fewer, but a reconcile after 3 s would block clicks for 3 more seconds, breaking R4. Rejected.

### Open questions and risks

- Is a first-launch window that ignores outside clicks until it is closed explicitly (icon, Escape, a gesture) acceptable? It may sit over System Settings if the user chooses "Open System Settings" in the prompt. The alternative is R10 failing whenever the prompt takes focus.
- Does reading every drag and pressure event in order to withhold a blocked press whole fit R9's "use it only to block clicks … MUST NOT read, record or change … any other event"? Or should the mask hold presses and releases only, letting a blocked press's drags and Force Click stages reach apps?
- Should a mouse click be blocked while the thumb and another finger rest on the trackpad within 3 s? If not, is it worth a trusted probe of whether trackpad clicks carry `kCGMouseEventSubtype == 3` (touch) and mouse clicks do not? That probe could add a source field to `PressID`.
- If a grant or revoke in System Settings does not post `com.apple.tcc.access.changed` the way `tccutil` does, is re-reading trust in `openWindow()` (still a push, never a timer) the accepted fallback for the hint? Blocking would then follow at the next reconcile.
- If `tapCreate` refuses for a moment right after a grant, blocking stays off until the next reconcile (wake, hot-plug, preference or hand-mode change). Is that acceptable? Manual R7 check.
- Does dropping pressure events during a blocked press stop Look up, and does Force Click still work normally outside the window? Manual R4 check on a Force Touch trackpad.
- Does the driver keep a bouncing finger's ID? This decides "Bouncing finger counts once" on hardware. The 001 S1 real-touch gate is still unticked.
- Does the frame stream always end with a frame that has no down contacts after the last lift? That frame is what clears `blocksClicks`. If the stream ever stopped with the thumb and a finger down, the flag would stay up until the next touch or `run`. This is the 001 frame-layout gate's "final frame with count == 0" check.
- Does `CFRunLoopRun` on the tap thread return after `remove()`? The design both invalidates the port and stops the loop. Manual: the thread count drops after a revoke.
- Are Debug (Apple Development) and Release (Developer ID) builds separate TCC clients that each need their own grant? Manual; affects only development.

### Next implementation step

Test-first at the recognizer seam: change `GestureRecognizer` to count distinct fingers with the 400 ms limit (the R1–R3 rows). That slice ships on its own, and the click-blocking slices extend the same state machine with `landedAt`, `Recognition` and `TouchFrame.Press`.
