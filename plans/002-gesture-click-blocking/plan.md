# Plan: Click blocking and forgiving taps

## Problem statement

Tap to click must be off for gestures to work. So a firm tap during a gesture becomes a real press. A firm 1-finger tap clicks whatever is under the pointer. A firm 2-finger tap opens a context menu. The press also cancels the gesture, so the user gets the unwanted click and no app.

3-finger and 4-finger gestures sometimes do nothing. A tap counts only if the first finger landing and the last finger lifting fall within 300 ms. Fingers of a natural 3 or 4-finger tap land unevenly and often miss that window. A finger that lifts before the last one lands also drops out of the count. A 4-finger tap can then fire the 3-finger gesture.

## Solution

Trackpad Launcher asks for the Accessibility permission on first launch. With it, clicks are blocked for the first 3 seconds after the thumb lands in the anchor corner. A firm tap in that window opens the app instead of clicking. Without it, gestures work as before, and the launcher window shows a hint with a button to grant access.

Blocking has a time window so a thumb resting in the corner never disables clicking for long. 3 seconds is long enough for a few taps in a row and short enough to recover from.

Taps get more forgiving. The time limit grows from 300 ms to 400 ms. Every finger that touches during the tap counts, even if it lifted before another landed. The app still opens the moment the fingers lift.

This plan changes the plan in `plans/001-trackpad-launcher-app/plan.md`. Its R11 finger count, tap duration and press rule are replaced by R1, R2 and R8 here; R3 restates R11's fire-on-lift rule to rule out any wait. Its R20 "No permissions" is replaced by R9 here. The reason in its non-goal "Working with Tap to click on" no longer holds, because the app now asks for one permission.

## Requirements

### R1. Every finger that touches counts
A tap begins when a non-thumb finger lands while no other non-thumb finger is down, and ends when the last non-thumb finger lifts. The finger count of a tap MUST be the number of distinct non-thumb fingers that touched during the tap, whether or not they were down at the same moment. A finger that lifts and lands again within the same tap MUST count once. A tap with more than four distinct fingers MUST NOT fire a gesture.

#### Scenario: Early finger lifts before the last lands
- **GIVEN** the 4-finger gesture is assigned to Spotify and the 3-finger gesture to Notion
- **WHEN** the user anchors the thumb and taps with four fingers, and the first finger lifts before the fourth lands, all within 400 ms
- **THEN** Spotify comes to the front and Notion does not

#### Scenario: Five fingers in a rolling tap
- **GIVEN** all four gestures are assigned
- **WHEN** the user anchors the thumb and five fingers touch one after another within 400 ms, never more than four at once
- **THEN** nothing happens

#### Scenario: Two quick 1-finger taps
- **GIVEN** the 1-finger gesture is assigned to Arc and the 2-finger gesture to Figma
- **WHEN** the user anchors the thumb, taps with one finger, lifts, and taps again with one finger 200 ms later
- **THEN** Arc comes to the front twice and Figma never does

#### Scenario: Bouncing finger counts once
- **GIVEN** all four gestures are assigned and the 4-finger gesture is assigned to Spotify
- **WHEN** the user anchors the thumb and taps with four fingers, and one finger briefly lifts and lands again within the tap
- **THEN** Spotify comes to the front

### R2. A tap may last up to 400 ms
A tap that meets the other gesture rules MUST fire when its first finger landing and last finger lifting are no more than 400 ms apart. A tap longer than 400 ms MUST NOT fire, and no new tap begins until every non-thumb finger has lifted.

#### Scenario: Uneven 3-finger tap
- **GIVEN** the 3-finger gesture is assigned to Notion
- **WHEN** the user anchors the thumb, three fingers land over 150 ms, and the last lifts 350 ms after the first landed
- **THEN** Notion comes to the front exactly once

#### Scenario: Too slow
- **GIVEN** the 2-finger gesture is assigned to Figma
- **WHEN** the user anchors the thumb and holds two fingers down for 500 ms before lifting
- **THEN** nothing happens

### R3. Gestures fire the moment the fingers lift
A gesture MUST fire on the lift of its last finger, with no added wait for further fingers.

#### Scenario: No delay after lift
- **GIVEN** the 1-finger gesture is assigned to Arc
- **WHEN** the user anchors the thumb and taps with one finger
- **THEN** the haptic pulse plays as the finger lifts and Arc comes to the front with no added wait

### R4. Clicks are blocked for 3 seconds after the thumb anchors
While Trackpad Launcher has the Accessibility permission and gestures are active, trackpad clicks MUST be blocked for the first 3 seconds after a thumb becomes anchored, while that thumb stays anchored and while at least one other finger is on the trackpad. Clicks are left-clicks, right-clicks and Force Clicks. A press made while the anchored thumb is the only touch MUST pass, so pressing with the thumb or a lone finger in the corner still clicks. Once the thumb lifts or leaves the anchor corner, clicks MUST work again at once. After the 3 seconds, clicks MUST work again even with the thumb still anchored.

#### Scenario: Firm 1-finger tap does not click
- **GIVEN** access is granted and the pointer is over a button
- **WHEN** the user anchors the thumb and firmly taps with one finger within 3 seconds
- **THEN** the button is not clicked

#### Scenario: Firm 2-finger tap does not open a context menu
- **GIVEN** access is granted and the pointer is over a file in Finder
- **WHEN** the user anchors the thumb and firmly taps with two fingers within 3 seconds
- **THEN** no context menu opens

#### Scenario: Force Click does not Look up
- **GIVEN** access is granted and the pointer is over a word
- **WHEN** the user anchors the thumb and force-presses with one finger within 3 seconds
- **THEN** no Look up appears

#### Scenario: Clicks return after 3 seconds
- **GIVEN** access is granted
- **WHEN** the user rests the thumb in the anchor corner for 4 seconds, then presses the trackpad with one finger over a button
- **THEN** the button is clicked

#### Scenario: Clicks return when the thumb lifts
- **GIVEN** access is granted
- **WHEN** the user anchors the thumb, lifts it after 1 second, then clicks a button
- **THEN** the button is clicked

#### Scenario: Thumb slides out
- **GIVEN** access is granted
- **WHEN** the user anchors the thumb, slides it out of the anchor corner, then presses with one finger over a button
- **THEN** the button is clicked

#### Scenario: Lone finger in the corner still clicks
- **GIVEN** access is granted and the pointer is over a button
- **WHEN** only one finger is on the trackpad, resting in the anchor corner, and the user presses
- **THEN** the button is clicked

#### Scenario: Ordinary click
- **GIVEN** access is granted and nothing touches the anchor corner
- **WHEN** the user presses with one finger over a button
- **THEN** the button is clicked

#### Scenario: No blocking while gestures are inactive
- **GIVEN** access is granted and *Tap to click* is on
- **WHEN** the user rests the thumb in the anchor corner and clicks a button
- **THEN** the button is clicked

### R5. A press is blocked or passed as a whole
The press-down and the release of one press MUST both be blocked or both be passed.

#### Scenario: Thumb lands during a drag
- **GIVEN** access is granted and the user is dragging a window with a press held
- **WHEN** the thumb lands in the anchor corner during the drag
- **THEN** the drag continues and ends normally on release

#### Scenario: Press across the 3-second mark
- **GIVEN** access is granted and the pointer is over a button
- **WHEN** the user anchors the thumb, presses with one finger 2.9 seconds later and releases at 3.1 seconds
- **THEN** the whole press is blocked and nothing is clicked

### R6. Pointer, scrolling and mouse are never blocked
Pointer movement and scrolling MUST NOT be blocked. Clicks from a mouse MUST NOT be blocked while nothing but the anchored thumb touches the trackpad. (While another finger is on the trackpad inside the blocking window, macOS gives the app no way to tell a mouse press from a trackpad press, so a mouse click is then treated as a trackpad press.)

#### Scenario: Pointer still moves
- **GIVEN** access is granted
- **WHEN** the user anchors the thumb and slides one finger across the trackpad
- **THEN** the pointer moves as usual

#### Scenario: Scrolling still works
- **GIVEN** access is granted and the pointer is over a long page
- **WHEN** the user anchors the thumb and scrolls with two fingers
- **THEN** the page scrolls

#### Scenario: Mouse clicks still work
- **GIVEN** access is granted and a mouse is connected
- **WHEN** the user rests the thumb in the anchor corner and clicks a button with the mouse in the other hand
- **THEN** the button is clicked

### R7. Blocking follows the permission live
Click blocking MUST start within 5 seconds of access being granted and stop within 5 seconds of it being revoked, with no relaunch.

#### Scenario: Granting starts blocking
- **GIVEN** access is not granted
- **WHEN** the user turns Trackpad Launcher on under Accessibility, then 5 seconds later anchors the thumb and firmly taps with one finger over a button
- **THEN** the button is not clicked, without relaunching the app

#### Scenario: Revoking stops blocking
- **GIVEN** access is granted
- **WHEN** the user turns Trackpad Launcher off under Accessibility, then 5 seconds later anchors the thumb and firmly taps with one finger over a button
- **THEN** the button is clicked, without relaunching the app

### R8. A blocked press counts as a tap
While clicks are blocked (R4), a press during a tap MUST NOT cancel it, and the tap MUST fire its gesture under the usual rules. When clicks are not blocked, a press MUST cancel the tap, as today.

#### Scenario: Firm tap opens the app
- **GIVEN** access is granted and the 2-finger gesture is assigned to Figma
- **WHEN** the user anchors the thumb and firmly taps with two fingers within 3 seconds, pressing the trackpad down
- **THEN** Figma comes to the front, nothing is right-clicked, and the gesture's haptic plays as for a light tap

#### Scenario: Press and hold does nothing
- **GIVEN** access is granted and the 1-finger gesture is assigned to Arc
- **WHEN** the user anchors the thumb, presses with one finger, holds for 1 second and releases
- **THEN** nothing is clicked and Arc does not come to the front

#### Scenario: Without access, a press stays a click
- **GIVEN** access is not granted and the 1-finger gesture is assigned to Arc
- **WHEN** the user anchors the thumb and presses the trackpad down with one finger over a button
- **THEN** the button is clicked and Arc does not come to the front

#### Scenario: After 3 seconds, a press stays a click
- **GIVEN** access is granted and the 1-finger gesture is assigned to Arc
- **WHEN** the user rests the thumb for 4 seconds, then presses the trackpad down with one finger over a button
- **THEN** the button is clicked and Arc does not come to the front

### R9. Accessibility is the only permission, and it is optional
Trackpad Launcher MUST NOT ask for any permission other than Accessibility. Every feature except click blocking MUST work without it. With access granted, the app MUST use it only to block clicks as described here. It MUST NOT read, record or change keyboard input, scrolling, pointer movement or any other event: the only events it reads are presses and what belongs to a press (its release, its drags and its Force Click pressure stages), and the only events it changes are those of a blocked press.

#### Scenario: Declined
- **GIVEN** the user declined Accessibility
- **WHEN** they assign an app and perform its gesture
- **THEN** the app comes to the front, and clicks are not blocked

#### Scenario: No other prompts
- **WHEN** a user installs the app, dismisses the Accessibility prompt, assigns an app and performs its gesture
- **THEN** no other permission prompt appears and the gesture works

### R10. First launch asks for Accessibility
On first launch Trackpad Launcher MUST show the system's Accessibility prompt once, unless access is already granted. Once the prompt is dismissed, the launcher window MUST be open, showing the Accessibility hint if access was not granted. Later launches MUST NOT show the prompt.

#### Scenario: First launch
- **WHEN** the user opens the app for the first time and dismisses the Accessibility prompt without granting access
- **THEN** the launcher window is open and shows the Accessibility hint

#### Scenario: Second launch
- **GIVEN** the user dismissed the prompt on first launch
- **WHEN** the app starts at login
- **THEN** no prompt appears

### R11. Accessibility hint in the launcher window
While access is not granted, the launcher window MUST show a hint below the gesture hint or the trackpad settings notice. The hint reads "Clicks aren't blocked during gestures. Allow Accessibility access to block them." and has a "Grant access…" button. The button MUST open System Settings > Privacy & Security > Accessibility. The hint MUST disappear within 5 seconds of access being granted and come back within 5 seconds of it being revoked, with no relaunch. The menu bar icon MUST NOT change because of the permission.

#### Scenario: Hint while not granted
- **GIVEN** access is not granted and gestures are active
- **WHEN** the user opens the launcher window
- **THEN** the hint and the "Grant access…" button are shown, and the menu bar icon shows gestures as active

#### Scenario: Button opens the right pane
- **WHEN** the user clicks "Grant access…"
- **THEN** System Settings opens on Privacy & Security > Accessibility

#### Scenario: Granting removes the hint live
- **GIVEN** the window shows the hint
- **WHEN** the user turns Trackpad Launcher on under Accessibility and opens the window again 5 seconds later
- **THEN** the hint is gone, without relaunching the app

#### Scenario: Revoking brings the hint back
- **GIVEN** access is granted
- **WHEN** the user turns Trackpad Launcher off under Accessibility and opens the window 5 seconds later
- **THEN** the hint is shown, without relaunching the app

#### Scenario: Hidden when granted
- **GIVEN** access is granted
- **WHEN** the user opens the launcher window
- **THEN** no Accessibility hint is shown

## Non-goals

- **Blocking the pointer or scrolling.** Freezing the pointer whenever the thumb rests in the corner would feel broken, and taps barely move it.
- **Detecting a gesture before its click.** A press arrives before the fingers lift, so the app cannot know in time that it is a tap. Blocking keys off the anchored thumb instead.
- **A grace period after the last finger lifts.** The user wants apps to open instantly. A late finger that lands after all others lifted starts a new tap.
- **Tuning other gesture rules.** The anchor corner size and the drag threshold stay as they are.
- **Recording real taps to fit the timing.** The user chose to try 400 ms first.
- **A setting to turn click blocking off.** Declining or revoking Accessibility already turns it off.
- **Feedback when a click is blocked.** Blocked clicks are silent. The gesture's own haptic is the feedback.
- **Changing the 3-second window.** It is fixed, like the other gesture rules.
- **Prompting installs that already launched an earlier build.** The prompt appears only on first launch. Such installs see only the hint.

## Design

### Problem

Plan 002 adds three things to the plan 001 app: forgiving taps (every distinct finger counts, 400 ms), click blocking for the first 3 seconds after a thumb anchors, and one optional permission with a first-launch prompt and a live hint. Click blocking is the non-obvious part because it is spread across three threads, two clocks and three owners. Only the recognizer, on the MultitouchSupport frame thread, knows that a thumb is anchored, when it anchored and whether another finger is down. The click itself reaches an active session event tap on whatever run loop its source is scheduled on, stamped with a `CGEventTimestamp` that is not known to share a base with `FrameTime` (grounding Q1: never compare them). Only the main actor knows whether gestures are active and whether access is granted. Several facts stay open and the design must not depend on them: whether a dropped press still reads as down in `CGEventSource.buttonState`, whether a click came from the trackpad or a mouse, whether a bouncing finger keeps its ID, and whether Force Click's pressure events must be dropped too. Facts it does rest on (grounding): an active mouse-button tap needs Accessibility and returns nil without it (probed); tccd posts the Darwin notification `com.apple.tcc.access.changed` about 30 ms after a TCC change on the main queue, and an ordinary process may post the same name (probed); a mouse-down and its mouse-up share `kCGMouseEventNumber`, and `CGEventSetType` can rewrite an event (sourced); frames flow at ~100 Hz while any contact rests, so a 3-second expiry is observed on a frame; `kAXTrustedCheckOptionPrompt` imports as a global `var` that strict concurrency rejects, and its value is `"AXTrustedCheckOptionPrompt"` (checked). Constraints carried over from plan 001: one `@MainActor @Observable` `Launcher` owns every decision; every port has exactly two adapters; policy is pure and lives in `LauncherCore`, which imports Foundation and Observation only; frames are recognised on the frame thread; one idempotent `reconcile()` restarts every device with a fresh recognizer, and a fresh recognizer re-adopts a resting thumb on its first frame; the frame timestamp is the only clock; no timers, no polling; rules are enforced by the source-policy gate. Two more facts from the grounding shape the design: the shell closes the launcher window on any outside mouse-down and whenever the panel resigns key, so the system's Accessibility prompt (another process, which takes focus and whose buttons are outside clicks) would close the first-launch window and break R10; and the TCC notification is a global broadcast for every app's permissions, not ours alone.

### Usage (caller's view)

**README excerpt.** `Launcher` still owns every decision. It now reads one more fact, whether Trackpad Launcher has the Accessibility permission, through a third sensing port that pushes "trust changed". From that fact and gesture activity it decides whether clicks may be blocked and tells the hardware port so in the same `run` call that starts the devices. The hardware adapter does the rest: each trackpad's recognizer reports, frame by frame, whether that trackpad is inside its blocking window; the adapter's one event tap drops a press that starts while any trackpad is inside its window, together with that press's release, its drags and its Force Click stages; and the frame stream records each press the way the tap treated it, so a blocked press is part of the tap and a delivered click cancels it. The window shows the Accessibility hint while access is missing. Tests drive all of it synchronously: frames carry their own time, and the in-memory hardware runs the real recognizer and the real click filter.

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
        launcher.start()   // reconcile; first launch: login item, the Accessibility prompt unless granted, the held window
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

// R10: the prompt once, the window held open under it, closed only by an explicit close.
@MainActor @Test func firstLaunchPromptsOnceAndHoldsTheWindowOpenUnderThePrompt() {
    let world = World()
    world.launcher.start()
    #expect(world.access.prompts == 1 && world.launcher.isWindowOpen)
    world.launcher.dismissWindow()                 // the prompt took focus, or its button was clicked
    #expect(world.launcher.isWindowOpen)
    world.launcher.closeWindow()                   // icon click or Escape
    #expect(!world.launcher.isWindowOpen)
    world.relaunch().start()
    #expect(world.access.prompts == 1)
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
// The click filter's own seam: R5 as a pure table, and what a frame reads from it.
@Test func aPressIsBlockedOrPassedWhole() {
    var filter = ClickFilter()
    let press = PressID(button: 0, number: 41)
    #expect(filter.decide(.press(press), trackpadBlocking: true) == .drop)
    #expect(filter.holding == .withheld)
    #expect(filter.decide(.drag(button: 0), trackpadBlocking: false) == .passAsMove)   // pointer still moves (R6)
    #expect(filter.decide(.release(press), trackpadBlocking: false) == .drop)           // window closed meanwhile
    #expect(filter.holding == .nothing)
    #expect(TouchFrame.Press(holding: .withheld, buttonDown: false) == .blocked)         // a withheld press, whatever buttonState reads
    #expect(TouchFrame.Press(holding: .nothing, buttonDown: true) == nil)                // the tap has not decided this press yet
    #expect(TouchFrame.Press(holding: nil, buttonDown: true) == .click)                  // no tap: today's sampling
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

- *What a frame says about the button.* `TouchFrame.buttonDown: Bool` becomes `TouchFrame.press: Press?`. `nil` means no press matters to this tap. `.click` means macOS delivered a press to apps (from any pointing device): it cancels a tap. `.blocked` means the click filter is withholding a press: it is part of the tap. One initializer, `Press(holding:buttonDown:)`, holds the precedence and both hardware adapters use it: with a live filter, `.withheld` reads `.blocked` whatever the session's button state says, `.passed` reads `.click` while the button is still down, and `.nothing` reads nil even if the button state is down (the tap has not decided that press yet, or passed it unseen); with no filter (no tap, no permission), the button state alone says `.click`. So a press never reads as a click before the tap has passed it, a withheld press never reads as a click, and a press whose release the tap missed heals on the next frame (per `type-system-discipline`, `boundary-discipline`).
- *What a frame meant.* `step(_:)` returns `Recognition { fired: Gesture?; blocksClicks: Bool }`. `blocksClicks` is this trackpad's half of R4: a thumb this recognizer saw land less than 3 s ago is still anchored, and another contact is down.
- *What the recognizer remembers.* `Anchor` gains `landedAt: FrameTime?`: nil when the thumb was already resting on the recognizer's first frame (a reconcile restarted the device under a resting hand, phase `.down`); such a thumb anchors but opens no blocking window. A `.landing` thumb on the first frame is a real landing (the pad sends no frames while nothing touches it, so after every `run` the first landing is the first frame) and opens its window at `frame.time`. `previouslyDown` becomes `Set<TouchID>?`, nil before the first frame: the only place the "first frame" fact lives. The tap state becomes a `Tap` value: `start`, `down: [TouchID: SurfacePoint]` (landing points, for the drag check) and `touched: Set<TouchID>` (R1's count); `down.keys ⊆ touched` holds because `Tap.land(_:)` is the only way a finger joins.
- *What the event tap sees.* `PointerEvent` is `.press(PressID)`, `.release(PressID)`, `.drag(button:)` or `.pressure`. `PressID` is the button plus `kCGMouseEventNumber`. `PointerVerdict` is `.pass`, `.drop` or `.passAsMove`. `ClickFilter` is a pure value holding, per button, whether the press in progress is withheld or passed; `holding` is its one-word summary (`.withheld` wins over `.passed`, else `.nothing`). `CGEvent`, `CGEventType` and `CFMachPort` never leave `LauncherPlatform`.
- *What the model shows.* `isAccessibilityGranted` is a stored observed field written only by `reconcile()`. It is not part of `GestureActivity`, so the icon cannot change because of it (R11). Window visibility is a private three-state value, `closed | open | heldOpen`; `isWindowOpen` is derived from it.

**Load-bearing decisions.**

1. *The recognizer owns the frame-side half of click blocking.* R4's predicate is a function of the anchor and the frame clock, and the recognizer is the only module that holds the anchor. `step` computes `blocksClicks` after its state update from `state.anchor`, `anchor.landedAt`, `frame.time` and the frame's contacts. The 3 s constant sits beside the 400 ms one in `GestureRules`. No timer: frames keep arriving while the thumb rests, so expiry is seen on the next frame (within about 10 ms), and when nothing touches, nothing is anchored and nothing is blocked. A reconcile cannot restart the window: a fresh recognizer re-adopts a resting (`.down`) thumb with `landedAt == nil`, so no window opens; a thumb that lands on its first frame opens one. The failure is under-blocking, the safe direction; restarting the window would break R4's "after the 3 seconds, clicks MUST work again" whenever an internal reconcile happened after 3 s (per `model-the-domain`).
2. *The filter's own decision is the single truth about a press.* `ClickFilter.decide` drops a press-down exactly when some running trackpad's latest `blocksClicks` is true at that event, then drops the release with the same `PressID`, turns that press's drags into plain moves so the pointer keeps moving (R6), and drops pressure events while any press is withheld. Every other event passes unchanged. The frame thread never works out "was this press blocked" for itself: it reads `holding` from the filter when it samples the press, and the recognizer's press rule shrinks to one line: `.click` cancels a tap, `.blocked` does not (R8). No ordering of events can produce "a click and a gesture" or "neither": a press the tap passed reads `.click` only after the tap passed it, and a press the tap dropped reads `.blocked` whatever the button state table says. A press that beats its finger's landing frame passes as a click, frames read `.click`, and the tap cancels; that is today's behaviour, recorded as the accepted race (per "single source of truth per invariant").
3. *Click blocking is part of the hardware port, not a port of its own.* The tap's only input is the per-trackpad `blocksClicks` flags, and its only output the frame path reads is `holding`. Both are frame-path state. `TrackpadHardware.run` gains one argument, `blockClicks: Bool`. `run` already means "forget everything, start exactly this", and that now includes "remove the tap; install a fresh one if asked and allowed". Every reset is structural: the per-trackpad flags live in each `DeviceSession`, which `run` replaces; the filter lives in the `ClickTap`, which `run` replaces. If the system refuses the tap, nothing is filtered, presses are sampled as today, and taps behave exactly as without access (per `make-operations-idempotent`).
4. *The tap runs on its own thread's run loop.* Every click in the login session waits for the tap's callback. On the main run loop that wait would include the app's UI work (the picker's enumeration, LaunchServices lookups, SwiftUI layout) and risk a stall with main blocked in a WindowServer call while the WindowServer waits on our tap, until the tap is disabled by timeout. A dedicated `userInteractive` thread holds only the tap's run loop source, sleeps in the kernel between events and ends when `run` removes the tap. The thread retains its `ClickTap`, so no callback can outlive the object behind its `userInfo` pointer. On `tapDisabledByTimeout` or `tapDisabledByUserInput` the callback forgets every held press (their releases may have passed while the tap was disabled) and re-enables the tap.
5. *Permission is one more push-only port; the adapter removes the noise.* `AccessibilityPermission` has `onChange` ("trust changed"), `isGranted()` (a fresh `AXIsProcessTrusted()`) and `prompt()`. The real adapter listens to `com.apple.tcc.access.changed`, re-reads trust on every broadcast and calls `onChange` only when the value changed, so another app's camera grant does not restart the devices and drop a tap in progress. `Launcher` reconciles on every `onChange`, like the other two ports, and `reconcile()` arms blocking with `blockClicks: activity.isActive && isAccessibilityGranted`: R4 "No blocking while gestures are inactive" and R9 "Declined" in one expression. Revoke tears the tap down through the same path, without relying on macOS to stop delivery. The adapter's trust reader is injectable so its own test can flip it and post the notification itself.
6. *First launch prompts once and holds the window open under the prompt.* "First launch" is the existing derived fact (no stored record), so no new stored field is needed. `start()` calls `prompt()` before the first save, next to the login item and for the same crash reason, unless access is already granted, then opens the window as `heldOpen`. The shell now sends two kinds of close: explicit closes (icon click, Escape, and the window's own System Settings buttons) call `closeWindow()`; soft closes (an outside click, the panel resigning key) call `dismissWindow()`, which a held window ignores. The hold ends at the first explicit close, a fired gesture, or a grant: when `reconcile` sees trust become granted while the window is held, it closes the window, because the hint has done its job and the user is in System Settings. Without the hold, R10 fails as soon as the prompt appears.
7. *Distinct fingers, 400 ms, fire on lift.* The tap's count is `touched.count`. A re-landed finger keeps its `TouchID` when the driver reuses it and counts once; `Gesture(fingerCount:)` is nil above four. Every other rule stays: the anchor corner, the drag check, thumb before fingers, spoil recovery, and a reused ID on a lone finger starting a new tap (R1's own definition of a tap's end).
8. *Rules stay structure.* The scanner stops banning the two Accessibility APIs the design uses, confines each to the single file that owns it, adds bans for what R6 and R9 forbid, and pins the kept tokens with a self-check. Details in the policy sketch.

**Depth.**

| Module | Public surface | What it hides |
|---|---|---|
| `GestureRecognizer` | `init`, `step` → `Recognition` (2 fields) | All of R1–R3, the frame-side half of R4 (anchor time, 3 s, another contact, inherited thumbs), R8's press rule |
| `ClickFilter` | `init`, `decide`, `holding`, `forgetHeldPresses` | R5's whole-press memory per button, drags as moves, pressure, recovery from missed releases, the facts a frame reads |
| `TrackpadHardware` | 4 members (`run` gains one `Bool`) | Plus: the event tap, its thread and teardown, the mask, `CGEvent` parsing and rewriting, re-enabling, per-trackpad flags merged at the read, press sampling |
| `AccessibilityPermission` | 3 members | `AXIsProcessTrusted`, the prompt option, the TCC Darwin notification and its noise |
| `Launcher` | 5 read-only properties, 6 intents | Plus: arming (active and granted), prompt-once, holding the window and releasing it |

The interface grows by one field on `step`'s result, one argument on `run`, one port with three members, one observed property and one intent (`dismissWindow`). Everything else is inside.

**Concurrency** (Swift 6 language mode, one writer per field).

- *Main actor:* `Launcher`, the ports, every adapter's public surface, `ClickTap.install()` and `remove()`, and the TCC notification handler (registered on `DispatchQueue.main`, entered with `MainActor.assumeIsolated`, like IOKit and wake).
- *Frame thread* (per device): read the filter's `holding` (its `Mutex`), sample the button state, step the recognizer (its `Mutex`, never contended), then write that session's `blocking` flag (its own `Mutex<Bool>`). Gestures still hop to main with `Task { @MainActor }`.
- *Tap thread:* read the `sessions` registry, copying the sessions out before reading each flag (no nested locks), then decide under the filter's `Mutex`.
- *Writers:* `sessions` by main (`run`); each `blocking` flag by its device's frame callback; the filter by the tap thread; the tap's port by main (install and remove), with the tap thread only re-enabling through it. No two threads write the same field. Merging across trackpads happens at the read (per `separate-before-serializing-shared-state`).

**Requirement trace and seams.**

| R | Carried by | Verified at |
|---|---|---|
| R1 | `Tap.touched`; `Gesture(fingerCount:)` nil above 4 | Recognizer seam: early lift before the last lands → `.four`; rolling five → nothing; two 1-finger taps 200 ms apart → `[.one, .one]`; a reused ID landing again mid-tap → `.four` (`HandFrames`). `Launcher` seam: Spotify not Notion; Arc twice. Bounce IDs on hardware: manual |
| R2 | `GestureRules.maxTapDuration = 400 ms` | Recognizer seam: uneven 3-finger (stagger 75, hold 200) → `.three` once; 500 ms → nothing; 390/410 boundary rows |
| R3 | Fire on the frame the last finger is gone (unchanged) | Recognizer seam: the per-frame `fired` list is non-nil exactly on the lift frame. Haptic timing: manual |
| R4 | `Recognition.blocksClicks`, `Anchor.landedAt`, `clickBlockingWindow`, `ClickFilter.decide`, arming in `reconcile` | Recognizer seam, per frame: finger within 3 s → true; 2.9/3.1 s; thumb alone; thumb lifted; slid out; inherited thumb → false. Filter seam: decisions with the flag on and off. `Launcher` seam: firm tap → `[.drop, .drop]`; after 4 s → `[.pass, .pass]`; inactive and declined → `!isBlockingClicks`; a reconcile at 3.5 s does not re-block. Real clicks and Force Click: manual |
| R5 | `ClickFilter`'s per-button memory, matched by `PressID` | Filter seam: a dropped press's release drops with the flag off; a passed press's release passes with it on; a stale entry clears on the next release or press of that button. `Launcher` seam: thumb lands during a pressed drag → `[.pass, .pass]`; press at 2.91 s, release at 3.10 s → `[.drop, .drop]`. Window drag on hardware: manual |
| R6 | Tap mask (no move, scroll or keyboard bits); drags rewritten only during a withheld press | Filter seam (drag rows); LauncherPlatformTests (mask bits exactly; `.passAsMove` sets `.mouseMoved`); `Launcher` seam: a press with only the thumb down → `.pass`. Pointer, scroll and a real mouse: manual |
| R7 | `onChange` → `reconcile` → `run(blockClicks:)` → install or remove | `Launcher` seam: `set(granted:)` both ways. LauncherPlatformTests: an injected trust flip plus `notify_post` of the TCC name reaches `onChange` within the 5 s bound; a post without a flip does not. Grant and revoke in System Settings: manual |
| R8 | `TouchFrame.Press`; `.click` cancels, `.blocked` does not; `Press(holding:buttonDown:)` | Recognizer seam: `.blocked` mid-tap fires, `.click` cancels. `Launcher` seam: firm tap fronts Figma; press held 1 s → nothing fronted, `[.drop, .drop]`; without access → nothing fronted, no verdicts; after 3 s → nothing fronted, `[.pass, .pass]`. Haptic: manual |
| R9 | One port and one tap; the mask; the policy gate | `Launcher` seam: declined → gesture fronts and `!isBlockingClicks`. Source gate: banned, confined and pinned tokens. TCC log over install to first gesture: manual |
| R10 | `start()`: `prompt()` unless granted, before the save; `.heldOpen` | `Launcher` seam: first launch not granted → `prompts == 1`, open, survives `dismissWindow()`, closes on `closeWindow()` and on a grant; first launch granted → `prompts == 0` and an ordinary window; relaunch → still 1. Real alert and stacking: manual |
| R11 | `isAccessibilityGranted` (outside `GestureActivity`); `SettingsNotice`; `SettingsPane.accessibility`; layout refit loop | `Launcher` seam: live both ways; `activity` unchanged. Copy, pane, refit while open: manual |

**Test handles.**

| Thing | Handle |
|---|---|
| Clock behind the 400 ms limit and the 3 s window | `TouchFrame.time`; no clock object exists |
| The blocking predicate, frame by frame | `step(_:).blocksClicks` |
| What the recognizer sees of a press | `TouchFrame.press` (`HandFrames.frame(press:)`, `TouchScript.tap(click:)`) |
| When a physical press starts | `TouchScript.ClickTiming`: `.onLanding` (beats the landing frame: the race), `.firm` (from the frame after landing), `.midway` |
| The tap's pass/drop decision and what a frame reads from it | `ClickFilter.decide`, `ClickFilter.holding`, `TouchFrame.Press(holding:buttonDown:)`, all pure |
| The tap at the high seam | `InMemoryTrackpads` arms a real `ClickFilter` on `run(blockClicks: true)`, feeds it each scripted press edge using the previous frame's flags (as the real tap reads them), and records `pressVerdicts`; `isBlockingClicks` |
| Releases lost while the tap was disabled | `ClickFilter.forgetHeldPresses()` |
| Trust and its push | `InMemoryAccessibilityPermission.set(granted:)` invokes `onChange` synchronously on a change |
| The prompt | `InMemoryAccessibilityPermission.prompts` |
| The prompt's place in the first-launch sequence | `InMemoryAccessibilityPermission.onPrompt`, run inside `prompt()`; the World wires it to snapshot `store.load()` (the `onRegisterLoginItem` pattern) |
| The real push and its noise filter | `SystemAccessibilityPermission(trusted:)` with `notify_post(SystemAccessibilityPermission.changeNotification)` in LauncherPlatformTests |
| The window under the prompt | `dismissWindow()` against `closeWindow()`; `set(granted: true)` while held |
| A reconcile under a resting thumb | `preferences.set` between two scripts; the second script's first frame has the thumb `.down` |

**Deliberately not done.** No device attribution of clicks (`kCGMouseEventSubtype` is unproven for trackpad clicks; the R6 mouse scenario is met by "another finger is on the trackpad"). No report of whether the tap is live beyond the fake's `isBlockingClicks` (R8 needs none, and the hint is about the permission). No grace delay, timer, deadline or second clock. No diffing in `run`. No stored "prompted" flag. Nothing in the mask beyond buttons, drags and pressure: no keyboard, scroll or plain movement. No posting or synthesising of events. No enabling or disabling of the tap from the frame thread.

#### Module map

```
LauncherCore     (Foundation, Observation)   GestureRules (+ clickBlockingWindow, 400 ms) · TouchFrame.Press · Recognition ·
                                              GestureRecognizer (distinct count, anchor time, blocksClicks) ·
                                              PressID · PointerEvent · PointerVerdict · ClickFilter (+ Holding) ·
                                              ports: TrackpadHardware (run + blockClicks), TrackpadPreferences,
                                              AccessibilityPermission (new), SystemActions · Launcher (+ access, window hold)
LauncherPlatform (+ ApplicationServices,      MultitouchTrackpads (run installs or removes the ClickTap) · DeviceSession (press
                  notify)                     sampling, blocking flag) · sessions + anyTrackpadBlocksClicks · ClickTap (tap,
                                              thread, callback, PointerEvent parsing + mask, verdict application) ·
                                              SystemAccessibilityPermission (dedupe, injectable reader) · TouchFrame(parsing:press:)
LauncherUI                                    MenuBarShell (closeWindow and dismissWindow mapping, layout refit loop) ·
                                              LauncherView (+ the hint) · SettingsNotice · SettingsPane · LauncherActions
TrackpadLauncher app target                   composition root (+ SystemAccessibilityPermission)
Tests                                         LauncherCoreTests: recognizer, ClickFilter, Launcher seam, SourcePolicyTests;
                                              InMemoryTrackpads (fake tap), InMemoryAccessibilityPermission, TouchScript
                                              (.firm), HandFrames (press:), World (one makeLauncher) ·
                                              LauncherPlatformTests: TCC push and dedupe, PointerEvent parsing, mask, rewrite
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
    /// Clicks are blocked for this long after a thumb anchors (R4). Strictly less blocks; tests straddle (2.9/3.1).
    static let clickBlockingWindow = Duration.seconds(3)
}

/// Everything the recognizer needs about one instant on one trackpad. A complete snapshot.
public struct TouchFrame: Sendable {
    public let time: FrameTime
    public let touches: [Touch]
    /// nil: no press matters to this tap.
    public let press: Press?

    public init(time: FrameTime, touches: [Touch], press: Press?) { fatalError("not implemented") }

    /// A pressed button, as it matters to a tap (R8).
    public enum Press: Equatable, Sendable {
        /// macOS delivered this press to apps as a click (any pointing device). It cancels a tap.
        case click
        /// The click filter is withholding this press from apps (R4, R5). It is part of the tap.
        case blocked

        /// The one precedence rule, used by both hardware adapters. `holding` is the click filter's summary, nil when
        /// no filter is live (no tap, no permission). A withheld press is `.blocked` whatever the button state reads;
        /// a passed press is `.click` while the button is still down (so a release the tap missed heals on the next
        /// frame); a press the filter has not seen is nothing yet (it will read `.click` once the tap passes it, or
        /// `.blocked` once it drops it). Without a filter the button state alone decides, as before plan 002.
        public init?(holding: ClickFilter.Holding?, buttonDown: Bool) {
            switch holding {
            case .withheld: self = .blocked
            case .passed: guard buttonDown else { return nil }; self = .click
            case .nothing: return nil
            case nil: guard buttonDown else { return nil }; self = .click
            }
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
    public init(fired: Gesture?, blocksClicks: Bool) { fatalError("not implemented") }
}

/// The tap-with-anchored-thumb rules for ONE trackpad, as a pure state machine. Feed every frame in order.
/// Owned by exactly one frame thread (real adapter) or by the test (in-memory adapter); never shared.
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
        //          // The pad sends no frames while nothing touches it, so a thumb landing on the first frame really
        //          // landed now. Only an already-resting contact (.down) has an unknown landing time: no window.
        //          landedNow = !isFirstFrame || thumb.phase == .landing
        //          anchor = Anchor(id: thumb.id, landedAt: landedNow ? frame.time : nil)
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
        /// When this recognizer saw the thumb land. nil: the thumb was already resting on the first frame.
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
    /// What a frame needs to know about the press in progress. `.withheld` wins when buttons disagree.
    public enum Holding: Equatable, Sendable { case nothing, withheld, passed }

    public init() {}

    public mutating func decide(_ event: PointerEvent, trackpadBlocking: Bool) -> PointerVerdict {
        // TODO
        // .press(p):   held[p.button] = trackpadBlocking ? .withheld(p) : .passed(p)   // a new press of a button ends any stale one
        //              return trackpadBlocking ? .drop : .pass
        // .release(p): defer { held[p.button] = nil }                                  // that button is up, whatever came before
        //              return held[p.button] == .withheld(p) ? .drop : .pass           // blocked or passed whole (R5), flag ignored
        // .drag(b):    return held[b] is .withheld ? .passAsMove : .pass
        // .pressure:   return held.values.contains(.withheld) ? .drop : .pass          // a Force Click's stages belong to its press
        fatalError("not implemented")
    }

    /// Read by the frame thread when it samples a press: `.withheld` from a dropped press until its release, else
    /// `.passed` from a passed press until its release, else `.nothing`.
    public var holding: Holding { fatalError("not implemented") }

    /// The system disabled the tap, and releases may have passed meanwhile. Forget every held press.
    public mutating func forgetHeldPresses() { held = [:] }

    private enum Held: Equatable { case withheld(PressID), passed(PressID) }
    private var held: [Int: Held] = [:]
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
    /// The tap needs Accessibility. If the system refuses it, nothing is filtered, presses are sampled as before,
    /// and taps behave exactly as without access (R8, R9).
    func run(_ trackpads: [Trackpad], handMode: HandMode, blockClicks: Bool)
    func playFeedback(on trackpad: TrackpadID)
}

/// The Accessibility permission. Real: SystemAccessibilityPermission. Test: InMemoryAccessibilityPermission.
@MainActor public protocol AccessibilityPermission: AnyObject {
    /// On the main actor after trust changed, and only then. Carries no data; re-read with `isGranted()`.
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
    /// hint (R10). A held window closes only on an explicit close, a fired gesture, or a grant.
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
        access.onChange = { [unowned self] in reconcile() }            // R7, R11 live; the adapter reports real changes only
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

    /// Icon click, Escape, the window's own System Settings buttons: always closes.
    public func closeWindow() { window = .closed }

    /// An outside click, or the panel losing focus: closes unless the window is held open under the first-launch prompt.
    public func dismissWindow() { if window == .open { window = .closed } }

    /// The one convergent operation: launch, hot-plug, wake, preference, hand mode, and now trust changes.
    private func reconcile() {
        connected = hardware.connected()
        preferenceValues = preferences.current()
        let granted = access.isGranted()
        // A grant ends the hold: the hint has done its job and the user is in System Settings.
        if granted && !isAccessibilityGranted && window == .heldOpen { window = .closed }
        isAccessibilityGranted = granted
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

@MainActor public final class MultitouchTrackpads: TrackpadHardware {
    private var clickTap: ClickTap?
    // … the 001 fields unchanged (framework, notificationPort, iterators, startedDevices, actuators, wakeObserver)

    public func run(_ trackpads: [Trackpad], handMode: HandMode, blockClicks: Bool) {
        // TODO
        // guard let framework else { return }
        // sessions.withLock { $0 = [:] }                 // in-flight frames find nothing; the tap now sees no blocking trackpad
        // clickTap?.remove(); clickTap = nil             // a withheld press's release may now reach apps: a harmless stray up
        // unregister callbacks, stop devices, close actuators (unchanged)
        // let devices = listTrackpads() filtered to `trackpads`
        // if blockClicks && !devices.isEmpty { clickTap = ClickTap.install() }   // nil: refused, nothing filtered
        // for each device: DeviceSession(trackpad:, recognizer: fresh, clickTap: clickTap, deliver: hop to main)
        //                  actuator, insert into sessions, register callback, start (unchanged)
        // Postcondition: frames flow from exactly `trackpads`; a tap exists iff asked, allowed and trackpads exist.
        fatalError("not implemented")
    }
    // connected, playFeedback, listTrackpads, product, drain: unchanged
}

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
    func receive(_ frame: TouchFrame) {
        // let recognition = recognizer.withLock { $0.step(frame) }   — lock released before the next line
        // blocking.withLock { $0 = recognition.blocksClicks }
        // if let g = recognition.fired { deliver(GestureEvent(gesture: g, trackpad: trackpad)) }
        fatalError("not implemented")
    }

    /// Frame thread: the filter's summary when a tap is live, nil otherwise.
    var holding: ClickFilter.Holding? { clickTap?.holding }

    /// Click tap thread.
    var blocksClicks: Bool { blocking.withLock { $0 } }
}

/// Written by `run` (main). Read by the frame callback and the click tap.
let sessions = Mutex<[UInt: DeviceSession]>([:])

let contactFrameCallback: MultitouchSupport.ContactFrameCallback = { device, touches, count, timestamp, _ in
    // guard let device, let session = sessions.withLock({ $0[UInt(bitPattern: device)] }) else { return 0 }
    // let press = TouchFrame.Press(holding: session.holding, buttonDown: anyMouseButtonDown())
    // session.receive(TouchFrame(parsing: touches, count: count, timestamp: timestamp, press: press))
    return 0
}

/// Still a state query, no permission: the no-tap path and the "still down" check of a passed press.
func anyMouseButtonDown() -> Bool { fatalError("not implemented") }   // unchanged

/// R4's "a trackpad is inside its blocking window", merged across trackpads at the read.
/// Copies the sessions out first, so no lock is held while another is taken.
func anyTrackpadBlocksClicks() -> Bool { Array(sessions.withLock { $0.values }).contains { $0.blocksClicks } }
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
    var holding: ClickFilter.Holding { filter.withLock { $0.holding } }

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
        //     filter.withLock { $0.forgetHeldPresses() }                     // releases may have passed while disabled
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
    /// has no public CGEventType case (checked: `CGEventType(rawValue: 34)` is usable in a mask and as a rewrite).
    /// There are no keyboard, scroll or plain-move types (R6, R9).
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
/// change, on the main queue). The notification names no app and no service, so trust is re-read on every broadcast
/// and `onChange` runs only when the value changed. No polling.
@MainActor public final class SystemAccessibilityPermission: AccessibilityPermission {
    /// Public so the adapter's test can `notify_post` the same name.
    public static let changeNotification = "com.apple.tcc.access.changed"
    public var onChange: (@MainActor () -> Void)?

    /// `trusted` is injectable for the adapter's own test, which flips it and posts the notification itself;
    /// the default reads AXIsProcessTrusted().
    public init(trusted: @escaping @Sendable () -> Bool = { AXIsProcessTrusted() }) {
        // lastKnown = trusted()
        // notify_register_dispatch(Self.changeNotification, &token, .main) { [weak self] _ in
        //     MainActor.assumeIsolated { self?.refresh() } }
        fatalError("not implemented")
    }

    isolated deinit { notify_cancel(token) }

    public func isGranted() -> Bool {
        // lastKnown = trusted(); return lastKnown                      (fresh read, no callback)
        fatalError("not implemented")
    }

    /// `AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)`. The key is spelled out
    /// because the imported `kAXTrustedCheckOptionPrompt` is a global `var` that strict concurrency rejects (checked);
    /// its value is that string.
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
    /// launcher.closeWindow() (explicit: System Settings takes focus, and a held window must not sit over it),
    /// then NSWorkspace.shared.open(pane.url). Replaces openTrackpadSettings.
    let openSettings: (SettingsPane) -> Void
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
    /// Runs inside `prompt()`, so a test can observe what is stored at that moment (the `onRegisterLoginItem` pattern).
    var onPrompt: (() -> Void)?
    init(granted: Bool = false) { self.granted = granted }
    func isGranted() -> Bool { granted }
    func prompt() { prompts += 1; onPrompt?() }
    /// The user flips the switch in System Settings: a real change, pushed synchronously here (no push when unchanged,
    /// as the real adapter dedupes).
    func set(granted: Bool) { guard granted != self.granted else { return }; self.granted = granted; onChange?() }
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
    /// 1. a press edge reaches the tap BETWEEN frames, so it is decided on the flags left by the previous frame, merged
    ///    across trackpads: rising edge → decide(.press(next PressID on button 0)); falling edge → decide(.release(that));
    ///    each verdict is appended to `pressVerdicts` (only while armed);
    /// 2. the frame's press is re-sampled: Press(holding: clickFilter?.holding, buttonDown: scripted.press != nil);
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
    /// Pins both halves of the plan 002 edit so neither drifts back: no confined token is also banned, and the kept
    /// IOHID, Input Monitoring, timer and polling tokens are still banned.
    @Test func confinedAndBannedListsNeverOverlapAndKeepTheTimerAndInputMonitoringBans() { /* … */ }
}

// LauncherPlatformTests
//   tccBroadcastReachesOnChangeOnlyWhenTrustChanged: SystemAccessibilityPermission(trusted: { flag.withLock { $0 } });
//     flip the flag; notify_post(SystemAccessibilityPermission.changeNotification); onChange arrives on the main actor
//     within the 5 s bound (the AsyncStream pattern of the preference test); post again without a flip → no onChange.
//     Harmless: other listeners re-read. The test never calls prompt().
//   everyTapTypeParses: one synthetic CGEvent per PointerEvent.tapTypes entry (CGEvent(mouseEventSource:…), number set
//     via setIntegerValueField(.mouseEventNumber, …)) → the expected PointerEvent.
//   maskIsExactlyButtonsDragsAndPressure: tapMask has bits {1,2,3,4,6,7,25,26,27,34} and no others.
//   passAsMoveRewritesTheType: apply(to:) on a leftMouseDragged leaves a .mouseMoved event.
```

**Docs changed in Phase D.** In `docs/architecture.md`, "Privacy and permissions", the sentence "The app asks for no permission." becomes: "The app asks for one permission, Accessibility, and uses it only to block trackpad clicks during gestures. It never asks for Input Monitoring or any other permission, never reads keyboard events, and works fully without it except click blocking. The Accessibility APIs and the event tap are each confined to one adapter file by the source-scan test." In "Concurrency", "No timers, no polling, no background loops" gains: "the one extra thread is the click tap's run loop, which exists only while click blocking is armed and sleeps until an event arrives", and the TCC notification joins the list of pushes. In `docs/domain-model.md`, *Click blocking*'s last sentence follows the amended R6 ("Pointer movement and scrolling are never blocked; a mouse click is blocked only while another finger rests on the trackpad inside the blocking window, when it cannot be told from a trackpad press") and *Blocking window* is added; *Accessibility hint* and *Tap*'s finger count ("fingers that touched during the tap") already match.

### Synthesis decision

Both candidates converged on the whole shape: the recognizer returns `Recognition { fired, blocksClicks }` and keeps the anchor's landing time, so the 3-second window is decided on the frame clock with no timer; the finger count is a `touched` set of distinct IDs with the limit at 400 ms; a pure press filter in `LauncherCore` owns R5's whole-press rule (matched by `kCGMouseEventNumber`) and rewrites a blocked press's drags to moves; the event tap rides inside the hardware port through one new `run` argument, is rebuilt by every reconcile, runs on its own run-loop thread and reads per-trackpad `Mutex<Bool>` flags through the `sessions` registry; a three-member `AccessibilityPermission` port follows the Darwin notification; `Launcher` stores trust outside `GestureActivity`, arms blocking with `active && granted`, and prompts once from the first-launch fact; the hint is a sibling after the activity switch with a refit trigger; the policy list is revised with a self-check. That convergence is the signal; the differences were point decisions.

**Base: candidate-1.** The cross-judge scored it 17/18 against 14/18 and recommended it; my own scoring was 17 (3, 3, 3, 3, 3, 2) against 13 (2, 2, 2, 3, 2, 2), so we agree on the base. Candidate-1 won on R10: it alone checked how the shell closes the window (resign-key and the global mouse-down monitor both call `closeWindow()`), saw that the system prompt would close the first-launch window, and held the window open; candidate-2's `openWindow()` after `prompt()` fails on hardware and its own test cannot catch it. It also won on recovery from a disabled tap (candidate-2's `passed` set could hold a press whose release the tap missed, cancelling every later tap until the next reconcile), on the callback's lifetime (the tap thread retains the `ClickTap`), on R4 across a reconcile (an inherited thumb opens no window, where candidate-2 re-blocks clicks for up to 3 s), on encoding the press as a type (`TouchFrame.Press`) instead of overloading `buttonDown`'s meaning, on keying drags by button (candidate-2 keyed them by the press's event number, which nothing documents), on the toolchain fact about `kAXTrustedCheckOptionPrompt` (checked), and on the stronger policy mechanism (confining each permission API to one file).

**Grafted from candidate-2:** the permission adapter's dedupe (`onChange` only on a real change, so `Launcher.start` treats the third port exactly like the other two and no unrelated grant restarts the devices), with its injectable trust reader and public notification name so the adapter's `notify_post` test can assert both a flip and a non-change; and the self-check that pins the policy edit. **Taken from the cross-judge:** the frame's press is derived from the filter's state while a tap is live (`ClickFilter.holding`, with the `.passed` case) instead of from `withheld` plus the session's button state, which closed a race in candidate-1 where a frame could read a press as a click before the tap dropped it, leaving the user with neither click nor gesture; a press still needs the button down to read `.click`, so a release the tap missed heals on the next frame. The first-frame rule was first made independent of the driver's phase (`landedAt: isFirstFrame ? nil : frame.time`); that under-blocked every first landing after a `run`, so it now reads the phase: `.landing` opens a window, `.down` does not. The held window now ends on a grant (closing, since the user is in System Settings), and the window's own settings buttons close it explicitly, closing the third.

**Rejected from candidate-2:** restarting the blocking window on reconcile (breaks R4's "after the 3 seconds"); `buttonDown` meaning different things depending on adapter state; no hold for the prompt (R10); a third observation loop beside the icon loop (one loop per concern instead); a separate hint view (both notices share `SettingsNotice`); the pressure type left out of the mask until a manual check fails (the Force Click scenario is a requirement, so the mechanism ships and the check verifies it). **Dropped from candidate-1:** the fake's `broadcast()` and the trust comparison in `Launcher` (both moved into the adapter's dedupe).

### Tradeoffs accepted

- We accept that a press reaching the tap before its finger's landing frame is delivered as a click, and that click cancels the tap. In exchange, a press is never both a click and a gesture, and there is no grace delay (a non-goal).
- We accept that a press the tap passed unseen while disabled by the system (a microsecond window) reads as nothing to the recognizer, so a tap could fire beside such a click. In exchange, no frame can ever read a press as a click before the tap has passed it, which would cost the user both the click and the gesture.
- We accept that a fresh recognizer gives a resting thumb no blocking window after a reconcile. A thumb anchored 0.5 s before a hot-plug loses its remaining 2.5 s. In exchange, no internal restart can ever block clicks past R4's 3 seconds.
- We accept tearing down and recreating the tap on every reconcile, including trust changes. A press withheld at that moment sends apps a stray release, which they ignore. In exchange, there is one convergent `run` and no second lifecycle path for the tap.
- We accept one extra thread while click blocking is armed, in exchange for click latency that never depends on the app's main thread and no WindowServer stall risk. It sleeps in the kernel between events and costs no idle CPU.
- We accept a mask that includes drags and pressure. While blocking is armed, the tap wakes for every drag and pressure change in the session (a dictionary lookup each). In exchange, a blocked press is withheld whole: apps never see a drag or a Force Click stage of a press they never got.
- We accept that a mouse click is blocked while the thumb and another finger rest on the trackpad within the 3 s, as R6's parenthetical states, because no proven field tells the devices apart. The R6 scenario (thumb alone) passes.
- We accept that the first-launch window, held open under the prompt, ignores outside clicks until the user closes it from the icon or with Escape, grants access, or fires a gesture. In exchange, R10 holds.
- We accept that `InMemoryTrackpads` reimplements about ten lines of press-edge glue around the real `ClickFilter`. In exchange, every R4, R5 and R8 scenario runs synchronously through the whole app.
- We accept counting distinct `TouchID`s, which counts a bounce twice if the driver gives a re-landed finger a new ID. In exchange, the rule is one set and needs no position heuristics.
- We accept that the TCC adapter wakes on every permission change of every app (a trust read each), in exchange for a push with no timer and a port whose callback means exactly "trust changed".

### Alternatives considered

- **A "blocking in effect" input to the recognizer.** The frame path would pass "the tap is live" and the recognizer would decide from its own window whether a press counts. The interface is no smaller, and the complexity it exposes is worse. R5's whole-press rule would live twice, in the filter and in the recognizer, and the two would have to agree at the window's edges and in the landing race. When they disagree, the user gets the click and the gesture. Rejected: two modules owning one decision.
- **A separate `ClickBlocker` port with its own two adapters.** It looks like a seam, but its only input (per-trackpad flags) and its only output (a held press) are frame-path state. The real adapters would share module globals, and the two fakes would have to be wired to each other. It is a shallow interface over a seam with nothing on its other side. Rejected.
- **The tap on the main run loop.** This removes the thread and the cross-thread CF handles, but every click in the session would wait on the app's UI thread, with a stall risk while main waits on the WindowServer. Rejected for robustness.
- **A deadline instead of a per-frame flag** ("blocking until T", compared with the event's time in the tap). It is self-expiring, but needs a clock both threads trust. `FrameTime` and `CGEventTimestamp` are not known to share a base, and frames already observe expiry within one frame. Rejected.
- **Restarting the window when a fresh recognizer re-adopts a resting thumb** (`landedAt` always set). One field fewer, but a reconcile after 3 s would block clicks for 3 more seconds, breaking R4. Rejected.
- **Polling `AXIsProcessTrusted`, or re-reading it only when the window opens.** Polling is banned; window-open-only misses R7's "within 5 seconds" while the window is closed. The Darwin push is probed and costs nothing.
- **A stored "prompted" flag.** A second boolean that must stay in sync with first launch; the first-launch fact already says "prompt once" and the non-goal about earlier installs agrees.
- **Opening the window only after the prompt is dismissed.** Nothing observable tells the app when the system alert closes, so the window would need a timer or a heuristic over other apps' activation. The hold needs neither.

### Open questions and risks

- Does the driver report a contact that is already resting when a device restarts (wake, hot-plug, grant reconcile) as `.down` (not MakeTouch/`.landing`)? The first-frame rule depends on it. Settle with mt-probe. If it reports `.landing`, a reconcile under a resting hand could over-block clicks for up to 3 s.
- Is a first-launch window that ignores outside clicks until it is closed explicitly (icon, Escape, a gesture, a grant) acceptable? After a *deny* it stays until the user closes it. The alternative is R10 failing whenever the prompt takes focus.
- R6 and R9 were amended during design to say what the mechanism can guarantee: a mouse click is blocked while another finger rests on the trackpad inside the window, and the tap reads a press's drags and pressure stages. Both amendments need the human's confirmation. If a trusted probe later shows that trackpad clicks carry `kCGMouseEventSubtype == 3` (touch) and mouse clicks do not, `PressID` could gain a source field and mouse clicks could pass even inside the window; nothing in R6 requires it.
- Does a grant or revoke in System Settings post `com.apple.tcc.access.changed` the way `tccutil` does, and does `AXIsProcessTrusted()` flip without relaunch? If a grant were ever not broadcast, the fallback inside the rules is to re-read trust in `openWindow()` (still a push, never a timer) for the hint; blocking would then follow at the next reconcile.
- If `tapCreate` refuses for a moment right after a grant, blocking stays off until the next reconcile (wake, hot-plug, preference or hand-mode change). Is that acceptable? Manual R7 check.
- Does dropping pressure events during a blocked press stop Look up, and does Force Click still work normally outside the window? Does the WindowServer deliver type-34 events to a session tap at all? Manual R4 check on a Force Touch trackpad.
- Does the driver keep a bouncing finger's ID? This decides "Bouncing finger counts once" on hardware. The 001 S1 real-touch gate is still unticked; running it with a deliberate bounce answers this.
- Does the frame stream always end with a frame that has no down contacts after the last lift? That frame is what clears `blocksClicks`. If the stream ever stopped with the thumb and a finger down, the flag would stay up until the next touch or `run`. This is the 001 frame-layout gate's "final frame with count == 0" check.
- Does `CFRunLoopRun` on the tap thread return after `remove()`? The design both invalidates the port and stops the loop. Manual: the thread count drops after a revoke.
- Are Debug (Apple Development) and Release (Developer ID) builds separate TCC clients that each need their own grant? Manual; affects only development.
- The latency race between the landing frame and the click event is accepted under the "no grace delay" non-goal; is a firm tap fast enough to hit it in practice? To be felt on hardware; if it is common, the human may want to revisit the non-goal.

### Next implementation step

Test-first at the recognizer seam (slice S1): change `GestureRecognizer` to count distinct fingers with the 400 ms limit (the R1–R3 rows). That slice ships on its own, and the click-blocking slices extend the same state machine with `landedAt`, `Recognition` and `TouchFrame.Press`.

## Testing Decisions

### Strategy

Five seams, highest first. Four exist today; the recognizer seam only widens its return type, and the one new seam (`ClickFilter`) is a pure value the design already names. Everything we own runs for real: the recognizer, the click filter, `Launcher`, `SettingsStore` over a throwaway suite, the real permission adapter's push path, `CGEvent` parsing.

1. **`Launcher` (LauncherCoreTests), the high seam.** `World(apps:attached:accessGranted:)` builds the real `Launcher` over `InMemoryTrackpads`, `InMemoryTrackpadPreferences`, `InMemoryAccessibilityPermission`, `RecordingSystemActions`, the temp catalog and the throwaway suite, through one private `makeLauncher(store:)` shared by `init` and `relaunch()`. `InMemoryTrackpads` steps the real `GestureRecognizer` and, when the last `run` asked for `blockClicks` with trackpads, arms a real `ClickFilter` that stands in for the event tap: a scripted press edge is decided between frames on the flags the previous frame left, merged across trackpads (as the real tap reads the sessions' flags), its verdict is appended to `pressVerdicts`, and the frame's press is re-sampled through `TouchFrame.Press(holding:buttonDown:)` exactly as the real frame callback does. It observes `broughtToFront`, `feedback`, `pressVerdicts`, `isBlockingClicks`, `running`, `isAccessibilityGranted`, `isWindowOpen`, `activity`, `access.prompts` and the suite. It misses the real tap, its thread and the WindowServer, real trust, the system prompt, the shell and the views: all manual. Rows resemble `LauncherKit/Tests/LauncherCoreTests/LauncherTests.swift`, `ActivityTests.swift` and `PersistenceTests.swift` (its `onRegisterLoginItem` snapshot is the pattern for ordering).
2. **`GestureRecognizer.step` → `Recognition`** over `TouchScript` and `HandFrames` frames (`GestureRecognizerTests.swift`). Two helpers over a fresh recognizer: `fired(_:)` (every fired gesture over every frame, as today) and `blocking(_:)` (`blocksClicks` per frame). The frame timestamp is the only clock, so the 400 ms limit and the 3 s window are driven by `TouchFrame.time` alone; rows that assert per frame follow `reusedTouchIDLandingAgainStartsASecondTap`. `TouchScript` gains `ClickTiming.firm` and `HandFrames.frame` gains `press:`; a row chooses `.click` or `.blocked`, so the recognizer's press rule is proven without the filter. Misses which trackpad, arming and the merge across trackpads (seam 1 and manual).
3. **`ClickFilter.decide` / `holding` and `TouchFrame.Press(holding:buttonDown:)`**, pure values with no clock and no device. Rows feed `PointerEvent`s in order with `trackpadBlocking` chosen per event and assert the verdict and `holding` after each: R5's whole-press memory, drags, pressure, stale entries, recovery after a disabled tap. Misses `CGEvent` (seam 4).
4. **LauncherPlatformTests: real adapters that need no hardware and no permission.** `SystemAccessibilityPermission(trusted:)` over a flag the test flips, with the test itself posting `com.apple.tcc.access.changed` through `notify_post` (`checks/notify-post.md`: an ordinary process may), awaited with the bounded `AsyncStream` pattern of `LauncherKit/Tests/LauncherPlatformTests/SystemTrackpadPreferencesTests.swift`; `PointerEvent.init(_:_:)` over synthetic `CGEvent`s; `PointerEvent.tapMask`; `PointerVerdict.apply(to:)` (the fixture style of `TouchFrameParsingTests.swift`). Misses creating the tap (needs trust) and real trust changes.
5. **`SourcePolicyTests`**: the revised banned list, the new confined list, and the self-checks that pin the plan 002 edit.

Faked at the seam: the event tap (the fake's few lines of edge glue around the real `ClickFilter`), trust (an in-memory port whose `set(granted:)` pushes synchronously, and only on a change, like the real adapter's dedupe), frames (scripts). Real: everything else, including the Darwin notification path. The clock needs no fake: no clock object exists, and the only waits are the two bounds in seam 4. Randomness: none in the design.

Techniques, applied. *Own the clock:* every bound in the design is a frame timestamp; boundary rows straddle 400 ms (390/410) and 3 s (2.9/3.1), and T10 advances only the clock, fingers still, to see the window expire. *Withhold and inject:* the fake tap withholds a scripted press (`.firm`) and the rows read both what the recognizer saw (`.blocked`) and what apps would have got (`pressVerdicts`); releases lost while the real tap was disabled are injected as `forgetHeldPresses()` (T21). *Hold the blocking call:* not applicable; the design bounds no call with a deadline or cancel of its own. The WindowServer's tap timeout is recovered by `forgetHeldPresses()` plus re-enable, the first pure (T21), the second manual. *Force the interleaving:* the thumb landing during a pressed drag (T31), the press straddling the 3-second mark (T30), the press that beats its finger's landing frame (T33, the accepted race), a reconcile under a resting thumb (T37), a grant while the window is held (T40), a gesture while it is held (T41). *Kill at random:* as in plan 001, replaced by rows at both post-crash states of the first-launch sequence, which has exactly one gap: prompt before the first save (T42) and stored → never again (T38). *Boundary values:* 400 ms, 3 s, four fingers against a rolling five, 200 ms between taps, a 1 s held press, a 4 s rest, the 5 s push bound. *Whole history:* `fired` and `blocksClicks` per frame, `pressVerdicts` in order, `broughtToFront` as a list.

Risk noted, not a defect: Darwin notifications coalesce, so "post without a flip, then flip and post" cannot tell a deduplicating adapter from one that fires on every broadcast. T43 proves the negative with a bounded wait before the positive, in the one target where a wait is allowed (LauncherPlatformTests, never scanned).

### Test scenarios

Conventions: right hand and `SurfaceSize.macBook14` unless stated; thumb at (10, 10) mm; fingers at (62, 45) mm, 8 mm apart; `TouchScript` frames 10 ms apart at time 1.0 s + ms, with the thumb landing at 0 ms and the first finger at 50 ms; `HandFrames` frames at the listed ms; "fired" is `fired(frames)`, "blocking" is `blocking(frames)`; "firm tap N" is `TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: N, click: .firm).frames` on macBook14 (the press runs from the frame after the first landing through the lift frame), "light tap N" the same without `click:`; a scripted press reaches the recognizer as `.click` at seam 2 and as whatever the fake tap decided at seam 1; "nothing" means `broughtToFront` and `feedback` gained no entry; "granted" is `World(…, accessGranted: true)`, and a `World` is not granted unless stated. `p`, `q`, `p1`… are `PressID(button: 0, number: n)` with distinct numbers; `r0` is button 1. Every `World` row calls `start()` before acting.

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R1 | recognizer | `thumb.tap(fingers: 4, stagger: 40 ms, hold: 100 ms)`: fingers land at 50, 90, 130, 170 ms and lift at 150, 190, 230, 270 ms, so the first lifts before the fourth lands and never more than three are down at once. → fired == [.four] | R1 scenario "Early finger lifts before the last lands"; the peak rule gives .three |
| T2 | R1 | recognizer | `thumb.tap(fingers: 5, stagger: 40 ms, hold: 100 ms)`: five distinct fingers over 260 ms, at most three down at once. → fired == [] | R1 scenario "Five fingers in a rolling tap"; "A tap with more than four distinct fingers MUST NOT fire" |
| T3 | R1 | recognizer | `thumb.tap(fingers: 1).wait(100 ms).tap(fingers: 1)`: the first lifts at 170 ms, the second lands at 370 ms. → fired == [.one, .one] | R1 scenario "Two quick 1-finger taps" (200 ms later); non-goal "A grace period after the last finger lifts" |
| T4 | R1 | recognizer | HandFrames: thumb 9 lands at 0; fingers 1–4 land at 100; all down at 110; at 120 finger 2 carries `.landing` again at its spot with 1, 3, 4 down; all down at 130; thumb only at 150. → fired == [.four] | R1 scenario "Bouncing finger counts once"; `Touch` contract (a tracked ID with `.landing` lifted and landed anew); a landing counter gives five and nothing |
| T5 | R2 | recognizer | `thumb.tap(fingers: 3, stagger: 75 ms, hold: 200 ms)`: lands at 50, 125, 200 ms (over 150 ms), last lift at 400 ms, 350 ms after the first landing. → fired == [.three] | R2 scenario "Uneven 3-finger tap" (exactly once); under 300 ms nothing fires |
| T6 | R2 | recognizer | Parametrised holdMS ∈ {390, 410}: `thumb.tap(fingers: 1, hold: holdMS).tap(fingers: 1)` → fired == [.one, .one] for 390 and [.one] for 410; and `thumb.tap(fingers: 2, hold: 500 ms)` → fired == [] | R2 "no more than 400 ms apart", scenario "Too slow"; `GestureRules.maxTapDuration` is strictly greater, rows 10 ms either side (float-sensitive, as plan 001's 290/310 were); the trailing tap proves recovery |
| T7 | R2 | recognizer | HandFrames: thumb at 0; finger 1 lands at 100 and is still down at 300 and 520; finger 2 lands at 540 with 1 still down; 1 lifts at 560; 2 lifts at 600; finger 3 lands at 700 and lifts at 800. → fired == [.one] | R2 "no new tap begins until every non-thumb finger has lifted": finger 2's 60 ms visit fires nothing; the trailing tap proves recovery |
| T8 | R3 | recognizer | HandFrames: thumb at 0; finger lands at 100, down at 110 and 120; thumb only at 130 and 140; nothing at 150. → `frames.map { recognizer.step($0).fired }` == [nil, nil, nil, nil, .one, nil, nil] | R3 "on the lift of its last finger, with no added wait": the fire is on the first frame the finger is absent and on no later one |
| T9 | R4 | recognizer | Parametrised landMS ∈ {1000, 2900, 3100, 4000}: thumb lands at 0; at landMS the thumb is down and a finger lands. → blocking == [false, landMS < 3000] | R4 "the first 3 seconds after a thumb becomes anchored", scenario "Clicks return after 3 seconds" (4 s); R5's 2.9 s; `GestureRules.clickBlockingWindow` is strictly less, rows 100 ms either side |
| T10 | R4 | recognizer | Thumb at 0; finger lands at 2950; both still down at 2990 and 3010. → blocking == [false, true, true, false] | R4 "After the 3 seconds, clicks MUST work again even with the thumb still anchored": expiry is seen on a frame where nothing but the clock moved |
| T11 | R4 | recognizer | Parametrised over two scripts: `thumb.wait(1 s).liftThumb()`; and `TouchScript(.macBook14).tap(fingers: 1)` with no thumb at all. → blocking all false | R4 "A press made while the anchored thumb is the only touch MUST pass", scenarios "Lone finger in the corner still clicks" and "Ordinary click" |
| T12 | R4 | recognizer | Thumb at 0; finger lands at 100; at 200 and 300 only the finger is down. → blocking == [false, true, false, false] | R4 "Once the thumb lifts … clicks MUST work again at once", scenario "Clicks return when the thumb lifts" |
| T13 | R4 | recognizer | Thumb at (24, 10) at 0; finger lands at 100; at 200 the thumb is at (x, 10) with the finger still down, x ∈ {26.5, 28.0}. → blocking == [false, true, x == 26.5] | R4 scenario "Thumb slides out"; `GestureRules.anchorReleaseMarginMM` 2 mm past 24.96 mm (plan 001 T19's edge) |
| T14 | R4 | recognizer | Fresh recognizer whose first frame (0) already holds the thumb, phase `.down`; finger lands at 10; thumb only at 100; nothing at 200; thumb `.landing` at 300; thumb down and a finger landing at 350. → blocking == [false, false, false, false, false, true]. A second row: first frame holds the thumb `.landing`, finger lands at 10 → [false, true] | Design decision 1 "a fresh recognizer re-adopts a resting (`.down`) thumb with `landedAt == nil`, so no window opens", and a `.landing` thumb on the first frame opens one; R4 "after the 3 seconds, clicks MUST work again" across an internal reconcile; the re-landed thumb proves windows still open afterwards |
| T15 | R8 | recognizer | Parametrised press ∈ {.blocked, .click} × timing ∈ {on the landing frame, from mid-tap}: thumb at 0; finger lands at 100 (press on it only for "landing"); down at 110 and 120 with the press; thumb only at 130 with the press and at 140 without; a clean 1-finger tap 300→330. → fired == [.one, .one] for `.blocked`, [.one] for `.click` | R8 "a press during a tap MUST NOT cancel it … When clicks are not blocked, a press MUST cancel the tap"; both transitions (`armed` on the landing frame, `tapping` mid-tap) |
| T16 | R8 | recognizer | Plan 001 T10 (`physicalClickIsNotATapAndTheNextTapStillFires` in `LauncherKit/Tests/LauncherCoreTests/GestureRecognizerTests.swift`) renamed `deliveredClickIsNotATapAndTheNextTapStillFires`, parametrised over fingers {1, 3} × `ClickTiming` {.onLanding, .firm, .midway}; `TouchScript` renders the press as `.click`. → fired == [Gesture(N)] (the trailing tap only) | R8 "a press MUST cancel the tap, as today"; plan 001 R11 scenario "Click is not a tap" |
| T17 | R4, R5 | ClickFilter | Parametrised button ∈ {0, 1, 2} (left, right, other), press `p` on it. Filter A: `decide(.press(p), trackpadBlocking: true) == .drop`, `holding == .withheld`, `decide(.release(p), trackpadBlocking: false) == .drop`, `holding == .nothing`. Filter B: `decide(.press(p), false) == .pass`, `holding == .passed`, `decide(.release(p), true) == .pass`, `holding == .nothing` | R5 "The press-down and the release of one press MUST both be blocked or both be passed"; R4 "left-clicks, right-clicks and Force Clicks"; grounding Q1 (`kCGMouseEventNumber` shared by down and up) |
| T18 | R5 | ClickFilter | `press(p1, false)` → .pass with its release never seen; `press(p2, true)` (same button) → .drop, `holding == .withheld`; `release(p2, false)` → .drop, `holding == .nothing`. Then `press(p3, true)` → .drop; `release(p4, false)` (same button, another number) → .pass, `holding == .nothing` | Design decision 2 "a new press of a button ends any stale one"; "that button is up, whatever came before" (recovery from a release the tap missed) |
| T19 | R6, R9 | ClickFilter | `drag(button: 0)` with nothing held → .pass; after `press(p, true)`: `drag(0)` → .passAsMove and `drag(1)` → .pass; after `press(r0, false)`: `drag(1)` → .pass; after `release(p)`: `drag(0)` → .pass | R6 "Pointer movement … MUST NOT be blocked"; R9 "the only events it changes are those of a blocked press" (a drag with nothing held and a drag of a passed press go through untouched); design "turns that press's drags into plain moves so the pointer keeps moving", drags keyed by button |
| T20 | R4, R9 | ClickFilter | `pressure` with nothing held → .pass; after `press(p, true)` → .drop; after `release(p)` → .pass; after `press(q, false)` → .pass | R4 scenario "Force Click does not Look up" (grounding Q1: Look up is driven from the pressure stages of the same press); R9 "what belongs to a press (… its Force Click pressure stages)" and "the only events it changes are those of a blocked press" (pressure passes with nothing held and during a passed press); design "drops pressure events while any press is withheld" |
| T21 | R5 | ClickFilter | `press(p, true)` → .drop; `forgetHeldPresses()` → `holding == .nothing`; `pressure` → .pass; `release(p, false)` → .pass. Separately `press(q, false)` then `forgetHeldPresses()` → `holding == .nothing` | Design decision 4 "the callback forgets every held press (their releases may have passed while the tap was disabled)"; synthesis (a passed press whose release was missed must not cancel every later tap) |
| T22 | R8 | ClickFilter | `press(p, false)` then `press(r0, true)` → `holding == .withheld`; `release(r0)` → `holding == .passed`; `release(p)` → `holding == .nothing` | Design "`.withheld` wins over `.passed`, else `.nothing`"; R8 (a withheld press reads as part of the tap whatever else is down) |
| T23 | R8 | pure value | `TouchFrame.Press(holding:buttonDown:)` over all eight inputs: (.withheld, false) → .blocked; (.withheld, true) → .blocked; (.passed, true) → .click; (.passed, false) → nil; (.nothing, true) → nil; (.nothing, false) → nil; (nil, true) → .click; (nil, false) → nil | R8: a blocked press is part of the tap, a delivered click cancels, "as today" when nothing is blocked (nil holding is plan 001's sampling); tradeoff "no frame can ever read a press as a click before the tap has passed it"; "a release the tap missed heals on the next frame" |
| T24 | R1 | Launcher | Spotify on `.four`, Notion on `.three`; T1's script on macBook14. → `broughtToFront == [Spotify]`, `feedback.count == 1` | R1 scenario "Early finger lifts before the last lands" (Spotify, not Notion) |
| T25 | R1 | Launcher | Arc on `.one`, Figma on `.two`; T3's script. → `broughtToFront == [Arc, Arc]` | R1 scenario "Two quick 1-finger taps" (Arc twice, Figma never) |
| T26 | R3, R4, R5, R8 | Launcher | Parametrised N ∈ 1…4; granted; four apps assigned to the four gestures; firm tap N. → `broughtToFront == [Gesture(N)'s app]`, `pressVerdicts == [.drop, .drop]`, `feedback == [macBook14.id]` | R8 scenario "Firm tap opens the app" (Figma fronts, nothing right-clicked, the haptic plays as for a light tap); R4 scenarios "Firm 1-finger tap does not click", "Firm 2-finger tap does not open a context menu"; R5 (the release after the lift frame is dropped although the window has closed by then); R3 (feedback on the lift) |
| T27 | R8 | Launcher | Granted; Arc on `.one`; `thumb.tap(fingers: 1, hold: 1 s, click: .firm)`. → nothing, `pressVerdicts == [.drop, .drop]` | R8 scenario "Press and hold does nothing" (nothing clicked, Arc not fronted) |
| T28 | R4, R8 | Launcher | Granted; Arc on `.one`; `thumb.wait(4 s).tap(fingers: 1, click: .firm)`. → nothing, `pressVerdicts == [.pass, .pass]` | R4 scenario "Clicks return after 3 seconds"; R8 scenario "After 3 seconds, a press stays a click" |
| T29 | R8, R9 | Launcher | Not granted; Arc on `.one`; light tap 1 → `broughtToFront == [Arc]`; then firm tap 1 → no further entry, `pressVerdicts == []`, `!hardware.isBlockingClicks` | R9 scenario "Declined" (the gesture works, clicks are not blocked); R8 scenario "Without access, a press stays a click" |
| T30 | R5, R8 | Launcher | Granted; Arc on `.one`; `thumb.wait(2850 ms).tap(fingers: 1, hold: 200 ms, click: .firm)`: the finger lands 2.90 s after the thumb, the press starts at 2.91 s, the lift at 3.10 s and the release at 3.11 s. → `pressVerdicts == [.drop, .drop]`, `broughtToFront == [Arc]` | R5 scenario "Press across the 3-second mark" ("the whole press is blocked and nothing is clicked"); R8 (the blocked press counts as a tap) |
| T31 | R5 | Launcher | Granted; HandFrames on macBook14: a finger at (62, 45) lands at 0 with press `.click` (a drag in progress); at 50 the thumb lands in the corner with the press held; both down at 100 with the press; both at 150 without it; thumb only at 200. → `pressVerdicts == [.pass, .pass]`, nothing | R5 scenario "Thumb lands during a drag" (the drag continues and ends normally on release); a release decided on the current flag would be dropped |
| T32 | R4, R6 | Launcher | Granted; Arc on `.one`; HandFrames: thumb lands at 0; press `.click` at 50 and 100 with only the thumb down; released at 150; a light 1-finger tap 300→330. → `pressVerdicts == [.pass, .pass]`, `broughtToFront == [Arc]` | R4 "A press made while the anchored thumb is the only touch MUST pass", scenario "Lone finger in the corner still clicks"; R6 "Clicks from a mouse MUST NOT be blocked while nothing but the anchored thumb touches the trackpad", scenario "Mouse clicks still work" (the fake cannot tell a mouse press from a trackpad press, and with the thumb alone it need not: the press passes whatever pressed) |
| T33 | R8 | Launcher | Granted; Arc on `.one`; `thumb.tap(fingers: 1, click: .onLanding)` (the press reaches the tap before the landing frame). → nothing, `pressVerdicts == [.pass, .pass]` | Tradeoff "a press reaching the tap before its finger's landing frame is delivered as a click, and that click cancels the tap"; non-goal "Detecting a gesture before its click"; R8 "When clicks are not blocked, a press MUST cancel" |
| T34 | R4 | Launcher | Granted → `hardware.isBlockingClicks`; `preferences.set(.tapToClick, rawValue: 1, for: .builtIn)` → `!isBlockingClicks`, `running.isEmpty`; back to 0 → `isBlockingClicks`. Also `World(attached: [], accessGranted: true)` → `!isBlockingClicks` | R4 "while gestures are active", scenario "No blocking while gestures are inactive"; design `blockClicks: activity.isActive && isAccessibilityGranted` |
| T35 | R7 | Launcher | Not granted; Arc on `.one` → `!isBlockingClicks`; `access.set(granted: true)` → `isBlockingClicks`; firm tap 1 → `[Arc]`, `[.drop, .drop]`; `access.set(granted: false)` → `!isBlockingClicks`; firm tap 1 → no further app and no further verdict | R7 scenarios "Granting starts blocking" and "Revoking stops blocking" (without relaunching) |
| T36 | R11 | Launcher | `World()` → `!isAccessibilityGranted`, `activity == .active`; `access.set(granted: true)` → `isAccessibilityGranted`, `activity == .active`; `access.set(granted: false)` → `!isAccessibilityGranted`, `activity == .active` | R11 "disappear within 5 seconds of access being granted and come back … with no relaunch"; "The menu bar icon MUST NOT change because of the permission" (the icon reads only `activity.isActive`) |
| T37 | R4 | Launcher | Granted; Arc on `.one`; script 1: `thumb.wait(3500 ms)` (the thumb rests and never lifts); `preferences.set(.tapToClick, rawValue: 0, for: .builtIn)` (a reconcile that stays active); script 2, HandFrames: thumb `.down` at 0; finger lands at 50; press `.click` at 60 (finger down) and 100 (finger gone); released at 110. → `pressVerdicts == [.pass, .pass]`, nothing | R4 "After the 3 seconds, clicks MUST work again even with the thumb still anchored" across an internal reconcile; design decision 1 "A reconcile cannot restart the window"; test handle "A reconcile under a resting thumb" |
| T38 | R10 | Launcher | `World()` → `access.prompts == 1`, `isWindowOpen`, `loginItemRegistrations == 1`; `dismissWindow()` → `isWindowOpen`; `closeWindow()` → `!isWindowOpen`; `relaunch().start()` → `access.prompts == 1`, `!isWindowOpen` | R10 scenarios "First launch" (the window is open after the prompt, which takes focus and whose buttons are outside clicks) and "Second launch"; plan 001 R17, R18 unchanged |
| T39 | R10 | Launcher | `World(accessGranted: true)` → `access.prompts == 0`, `isWindowOpen`; `dismissWindow()` → `!isWindowOpen`. Then `relaunch().start()`; `openWindow()`; `dismissWindow()` → `!isWindowOpen` | R10 "unless access is already granted"; plan 001 R3 (an outside click closes an ordinary window: the hold exists only under the prompt) |
| T40 | R10, R11 | Launcher | `World()` (held after `start()`); `access.set(granted: true)` → `!isWindowOpen`, `isAccessibilityGranted` | Design decision 6 "The hold ends at … a grant"; R11 (the hint has done its job) |
| T41 | R10 | Launcher | `World(apps: [Arc])` (held after `start()`); Arc on `.one`; light tap 1 → `broughtToFront == [Arc]`, `!isWindowOpen` | Design decision 6 "The hold ends at … a fired gesture"; plan 001 R3 "Gesture closes the window" |
| T42 | R10 | Launcher | `World()`; `access.onPrompt = { snapshots.append(world.store.load()) }`; `start()` → `snapshots == [nil]`, then `store.load() != nil` | R10 "once": design decision 6 "`start()` calls `prompt()` before the first save … a crash in between repeats them next time, never loses them" (the other post-crash state is T38's relaunch); pattern of plan 001 T43 |
| T43 | R7 | SystemAccessibilityPermission | `SystemAccessibilityPermission(trusted: { flag })` with the flag false → `isGranted() == false`; `notify_post(SystemAccessibilityPermission.changeNotification)` without a flip → no `onChange` within a 1 s bound; flip the flag to true and post → `onChange` runs on the main actor within 5 s and `isGranted() == true`; flip to false and post → `onChange` again, `isGranted() == false`. The test never calls `prompt()` and makes no TCC change | R7 "within 5 seconds … with no relaunch"; grounding Q2 (tccd posts this name on the main queue 30 ms after a change); `checks/notify-post.md` (a test may post it); design decision 5 "`onChange` only when the value changed" |
| T44 | R6, R9 | PointerEvent.tapMask | `tapMask` has exactly the bits {1, 2, 3, 4, 6, 7, 25, 26, 27, 34} | `CGEventTypes.h` (grounding Q1): left and right down/up 1–4, dragged 6, 7, 27, other down/up 25, 26; `NSEventTypePressure` 34 (`checks/toolchain.md`); R9 "the only events it reads are presses and what belongs to a press (its release, its drags and its Force Click pressure stages)" and "MUST NOT read … keyboard input, scrolling, pointer movement or any other event"; R6 "Pointer movement and scrolling MUST NOT be blocked" (no scroll or plain-move bit) |
| T45 | R5, R6, R9 | PointerEvent.init | Synthetic `CGEvent`s with `mouseEventNumber` set: leftMouseDown 41 → `.press(PressID(button: 0, number: 41))`; leftMouseUp 41 → `.release(PressID(0, 41))`; rightMouseDown/Up 42 → `.press/.release(PressID(1, 42))`; otherMouseDown/Up with `mouseEventButtonNumber` 3 and number 43 → `PressID(3, 43)`; leftMouseDragged → `.drag(button: 0)`; rightMouseDragged → `.drag(button: 1)`; otherMouseDragged with button 4 → `.drag(button: 4)`; an event whose type is set to 34 → `.pressure`; `.mouseMoved`, `.scrollWheel` and a keyboard event → nil | `CGEventTypes.h` `kCGMouseEventNumber` and `kCGMouseEventButtonNumber` (grounding Q1); R5 (down and up share the number); R9 "the only events it reads are presses and what belongs to a press": a move, a scroll and a key parse to nothing, so even an event the mask let through would be passed unread; R6 |
| T46 | R6, R9 | PointerVerdict.apply | `.passAsMove.apply(to:)` on a leftMouseDragged event returns an event whose `type == .mouseMoved`; `.pass` returns the same event with its type unchanged; `.drop` returns nil | `CGEvent.h` `CGEventSetType` and `CGEventTypes.h` "returning NULL discards" (grounding Q1); R6 "Pointer movement … MUST NOT be blocked"; R9 "the only events it changes are those of a blocked press" (`.pass` leaves the event as it came) |
| T47 | R6, R9 | SourcePolicyTests | Parametrised over the revised `banned` list: plan 001's entries minus `AXIsProcessTrusted`, `tapCreate`, `CGEventTapCreate`, plus `IOHIDRequestAccess`, `IOHIDCheckAccess`, `CGRequestPostEventAccess`, `CGPreflightPostEventAccess` ("R9 only Accessibility"), `keyDown`, `keyUp`, `KeyDown`, `KeyUp`, `flagsChanged`, `FlagsChanged` ("R9 no keyboard"), `scrollWheel`, `ScrollWheel` ("R6 never scrolling"), `.post(tap:`, `CGEventPost`, `postToPid` ("R9 never synthesise"): zero hits under the package's Sources and the app target; the planted-hit self-check still finds exactly `print(` | R9 "MUST NOT ask for any permission other than Accessibility" and "MUST NOT read, record or change keyboard input, scrolling, pointer movement or any other event"; R6 "Pointer movement and scrolling MUST NOT be blocked"; plan 001 R22 (the timer and polling rows stay); `docs/architecture.md` "add to its list rather than adding prose" |
| T48 | R7, R9 | SourcePolicyTests | Parametrised over `confined`: `AXIsProcessTrusted` and `notify_register` only in `SystemAccessibilityPermission.swift`; `tapCreate` and `CGEventTapCreate` only in `ClickTap.swift`: no hit in any other file. Self-check: a temp tree holding `SystemAccessibilityPermission.swift` and `Other.swift`, both containing `AXIsProcessTrusted()`, yields exactly the `Other.swift` hit | R9 "With access granted, the app MUST use it only to block clicks"; design decision 8 "confines each to the single file that owns it" |
| T49 | R9 | SourcePolicyTests | `confinedAndBannedListsNeverOverlapAndKeepTheTimerAndInputMonitoringBans`: no confined token contains or is contained by a banned token; `banned` still holds `IOHIDManager`, `CGRequestListenEventAccess`, `CGPreflightListenEventAccess`, `Timer`, `asyncAfter`, `makeTimerSource`, `Task.sleep` | Design decision 8 "pins the kept tokens with a self-check"; grounding Q5 (the Input Monitoring rows serve R9; the timer and polling rows are not revoked) |

### Verified without a test

Build and tool checks run from the worktree with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Manual sequences run on this 14" MacBook Pro against a Debug build with Accessibility granted to that build in System Settings unless the check says otherwise; "fresh install" means the settings suite removed and `tccutil reset Accessibility <bundle id>` run.

- **R1 (bounce IDs on hardware).** Run plan 001's `mt-probe` real-touch gate with a deliberate bounce: four fingers down, lift one for an instant and re-land it, lift all. Expected: the re-landed contact reports the same identifier with state 3 again. If the driver assigns a new identifier, T4's set rule over-counts a bounce to five and the "Bouncing finger counts once" scenario needs a position heuristic; record that in the open questions before S3.
- **R2, R3 (feel on hardware).** With Notion on 3 and Spotify on 4: ten uneven 3-finger and ten uneven 4-finger taps each front their app every time, never the other's; the pulse is felt as the fingers leave with no perceptible delay; a deliberate half-second 2-finger hold fronts nothing.
- **R4 (hardware).** Each scenario as written: pointer over a Finder toolbar button, thumb anchored, firm 1-finger tap within 3 s → not clicked; over a file, firm 2-finger tap → no context menu; over a word in TextEdit, Force Click → no Look up (and a Force Click with nothing in the corner still looks up); thumb rests 4 s, then press → clicked; thumb lifted after 1 s, then click → clicked; thumb slid out, then press → clicked; a lone finger resting in the corner, press → clicked; nothing in the corner, press → clicked; Tap to click on, thumb resting, click → clicked. With a Magic Trackpad paired: thumb and a finger resting on it, a press on the built-in trackpad within 3 s → blocked (the merge across trackpads in `anyTrackpadBlocksClicks()` has no in-process seam).
- **R5 (hardware).** Drag a Finder window with the press held; land the thumb in the corner mid-drag; keep dragging; release → the window followed throughout and stays where it was released.
- **R6 (hardware).** Thumb anchored: a sliding finger moves the pointer; a two-finger scroll scrolls a long page; with a mouse in the other hand and the thumb alone resting, a mouse click clicks (R6 "while nothing but the anchored thumb touches the trackpad"). Then, with the thumb and a finger both resting on the trackpad inside the window, a mouse click does not click, as R6's parenthetical says (it is treated as a trackpad press); after 3 s with both still resting, it clicks again.
- **R7 (hardware).** Access off: turn Trackpad Launcher on under Accessibility; within 5 s a firm 1-finger tap over a button is not clicked, no relaunch; turn it off; within 5 s a firm tap clicks. Then grant and tap again within a second of the grant, to see whether `tapCreate` ever refuses right after a grant (open question); if blocking is missing until the next reconcile, record it against R7.
- **R8 (hardware).** Figma on 2: firm 2-finger tap → Figma fronts, nothing is right-clicked, the pulse plays; Arc on 1: press and hold 1 s → nothing clicked, no Arc; access off: press → clicked, no Arc; thumb 4 s then press → clicked, no Arc.
- **R9.** "MUST NOT ask for any permission other than Accessibility": T47–T49, plus one session from a fresh install through dismissing the prompt, assigning an app and the first gesture: `log show --last 15m --predicate 'subsystem == "com.apple.TCC"'` lists only `kTCCServiceAccessibility` for the bundle ID and no other service, and no Input Monitoring prompt appears. "The only events it reads … and the only events it changes": the mask, the parser and the rewrite (T44–T46) and the filter's drag and pressure rows (T19, T20); on hardware, with access granted and the thumb anchored with a finger beside it, typing in TextEdit, a two-finger scroll and a pointer slide behave exactly as with access off.
- **R10 (hardware).** Fresh install: launch → the system Accessibility alert appears; the launcher window is open and shows the hint; dismiss the alert → the window stays; Escape closes it; relaunch → no alert, only the icon. With access pre-granted (grant, quit, remove the suite, launch) → no alert and an ordinary window. Record whether the alert sits in front of the panel.
- **R11.** `grep -rF` for the two literals "Clicks aren't blocked during gestures. Allow Accessibility access to block them." and "Grant access…" hits `LauncherKit/Sources/LauncherUI` once each; `grep -rn isAccessibilityGranted LauncherKit/Sources/LauncherUI` hits only the hint and the refit loop, never `StatusIcon` or the icon loop; the Accessibility pane URL `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility` appears once. Manual: with access off the hint reads the copy verbatim below the gesture hint, and below the trackpad settings notice when Tap to click is on, and the icon shows gestures active; "Grant access…" closes the window and opens System Settings > Privacy & Security > Accessibility; grant, reopen within 5 s → the hint is gone; revoke, reopen → it is back; no relaunch. With the window open, `tccutil reset Accessibility <bundle id>` → the hint appears and the panel grows to fit (loop 2's refit).
- **Design mechanisms with no row.** The tap thread: Activity Monitor's thread count for the process rises by one after a grant and falls by one after a revoke (`CFRunLoopRun` returns after `remove()`). Idle CPU with the tap installed: plan 001's R22 check repeated with access granted (0.0% after ten minutes idle). Recovery from a disabled tap: pause the process in the debugger for several seconds while clicking, resume, then a firm tap inside a window is still blocked (the callback saw `tapDisabledByTimeout`, forgot its presses and re-enabled). One writer per field: the package builds in Swift 6 language mode with strict concurrency and T47 keeps `nonisolated(unsafe)` banned. `LauncherCore` imports Foundation and Observation only (the existing `coreImportsOnlyFoundationAndObservation`), so `ClickFilter`, `PointerEvent` and `TouchFrame.Press` carry no CoreGraphics. `docs/architecture.md` "Privacy and permissions" and "Concurrency" read as the design's Phase D paragraph says.

## Slices

S1 is the design's named first step and the only slice that touches the recognizer's rules alone; it ships to hardware on its own because the app already runs the recognizer. S2 lands the permission end to end before anything is armed on it. S3 is the one slice verified only through the suite: it decides click blocking in the core and proves every R4, R5 and R8 scenario through the whole app on the fake tap, while the real adapter merely compiles against the new port. S4 is "for real".

### S1: Forgiving taps

**What to build:** The recognizer counts every distinct finger that touched during a tap (`Tap.touched`, via `Tap.land(_:)`) with the limit at 400 ms (`GestureRules.maxTapDuration`), fires on the frame the last finger is gone as today, and lets no new tap begin while a spoiled tap's fingers are still down. From the user's side: uneven 3-finger and 4-finger taps open their apps, a 4-finger tap never fires the 3-finger gesture, and a rolling five-finger tap does nothing. Existing tests: `tapLongerThanThreeHundredMillisecondsIsNotATap` is removed in favour of T6; `fingerCountIsThePeakNotTheCountAtTheLastLift` is renamed to say that every finger that touched counts (same frames, same expectation); `fiveFingerTapFiresNothing` (a simultaneous five) stays.

**Blocked by:** None (can start immediately).

**Requirements:** R1, R2, R3.

**Test scenarios:** T1–T8, T24, T25.

- [ ] Every row is green through `Scripts/test.sh`; T8's per-frame map is the only place the fire frame is asserted and it passes with no change to the fire rule.
- [ ] `GestureRules.maxTapDuration` is 400 ms and the only place that number lives; no test name says "three hundred".
- [ ] The R1 bounce check under Verified without a test has been run with a real touch and its outcome recorded in the plan's open questions.
- [ ] The R2/R3 feel check on hardware is ticked.

### S2: The Accessibility permission: port, first-launch prompt, held window, live hint

**What to build:** The `AccessibilityPermission` port with `SystemAccessibilityPermission` (injectable trust reader, the TCC push deduplicated) and `InMemoryAccessibilityPermission` (`set(granted:)`, `prompts`, and an `onPrompt` hook mirroring `RecordingSystemActions.onRegisterLoginItem`); `Launcher(access:)` with `isAccessibilityGranted` written only by `reconcile()`, the prompt once before the first save, the `closed | open | heldOpen` window with `dismissWindow()` beside `closeWindow()`, and the hold ending on an explicit close, a fired gesture or a grant; `World(accessGranted:)` over one private `makeLauncher(store:)`; in LauncherUI `SettingsNotice`, `SettingsPane`, `LauncherActions.openSettings(_:)` replacing `openTrackpadSettings`, the shell's explicit and soft close mapping, and the refit loop over `(activity, isAccessibilityGranted)`; the composition root; the policy gate restructured (`AXIsProcessTrusted`, `tapCreate`, `CGEventTapCreate` moved from `banned` to `confined`, the R6 and R9 bans added, the confined self-check and `confinedAndBannedListsNeverOverlapAndKeepTheTimerAndInputMonitoringBans`); the `docs/architecture.md` "Privacy and permissions" rewrite and the glossary's *Blocking window* entry (already in the working tree) committed with this slice. From the user's side: first launch shows the system prompt with the launcher window open under it; the hint with "Grant access…" shows while access is missing and follows grants and revokes live; the icon never changes for it.

**Blocked by:** None (touches no recognizer file; S1 and S2 can land in either order).

**Requirements:** R7 (the push and the model's reading of it), R9 (one permission; the gate), R10, R11.

**Test scenarios:** T36, T38–T43, T47–T49.

- [ ] Every new LauncherCoreTests row is synchronous; T43 is the only new row with a bound and it lives in LauncherPlatformTests.
- [ ] The `Launcher` constructor is written exactly twice: `World.makeLauncher` and the composition root.
- [ ] The R10 and R11 checks and the R9 TCC-log session under Verified without a test are ticked.
- [ ] `docs/architecture.md` no longer says the app asks for no permission, and `SourcePolicyTests` fails on any Accessibility API outside `SystemAccessibilityPermission.swift`.

### S3: Click blocking decided in the core

**What to build:** `Recognition`, `TouchFrame.Press` with `Press(holding:buttonDown:)`, `Anchor.landedAt` with the first-frame rule, `GestureRules.clickBlockingWindow`, the recognizer's one-line press rule and `blocksClicks`; `PressID`, `PointerEvent`, `PointerVerdict`, `ClickFilter` with `holding` and `forgetHeldPresses()`; `TrackpadHardware.run(_:handMode:blockClicks:)` and `reconcile()` arming with `activity.isActive && isAccessibilityGranted`; `InMemoryTrackpads` arming a real `ClickFilter` (`pressVerdicts`, `isBlockingClicks`), `TouchScript.ClickTiming.firm`, `HandFrames.frame(press:)`, the `fired` helper; `LauncherPlatform` compiling against the new port: `MultitouchTrackpads.run` accepting `blockClicks` and installing nothing yet, `DeviceSession` with its `blocking` flag and a nil `holding`, `TouchFrame(parsing:press:)`, the frame callback sampling through `Press(holding:buttonDown:)`. Existing tests changed: `physicalClickIsNotATapAndTheNextTapStillFires` becomes T16; `reusedTouchIDLandingAgainStartsASecondTap` maps `.fired`; `TouchFrameParsingTests` pass `press:`. Verifiable through the suite: every R4, R5 and R8 scenario runs through the whole app on the fake tap.

**Blocked by:** S1 (the state machine it extends), S2 (the port it arms on).

**Requirements:** R4, R5, R6 (the filter's half: a blocked press's drags pass as moves), R7 (arming), R8, R9 ("Declined"; the filter changes only a blocked press's drags and pressure stages).

**Test scenarios:** T9–T23, T26–T35, T37.

- [ ] Every row is synchronous; `LauncherCore` still imports Foundation and Observation only.
- [ ] `GestureRecognizer`'s public surface is `init` and `step` → `Recognition`; `ClickFilter`'s is `init`, `decide`, `holding`, `forgetHeldPresses`; the 400 ms and 3 s numbers live only in `GestureRules`.
- [ ] The app builds and behaves on hardware as before this slice (no tap yet: a press still clicks and cancels the tap).

### S4: The click tap for real

**What to build:** `ClickTap` (installed on main; its own `userInteractive` run-loop thread that retains it; the callback parsing `PointerEvent`s, reading `anyTrackpadBlocksClicks()` before the filter lock, applying verdicts, forgetting held presses and re-enabling on the two disabled types; `remove()` invalidating the port and stopping the loop); `PointerEvent.tapTypes`, `tapMask`, `PointerEvent.init(_:_:)`, `PointerVerdict.apply(to:)`; `MultitouchTrackpads.run` removing the tap first and installing a fresh one when asked, allowed and trackpads exist; `DeviceSession.holding` read from the tap; the `docs/architecture.md` "Concurrency" sentences on the tap thread and the TCC push (already in the working tree) committed with this slice. From the user's side: with access granted, a firm tap within 3 s of anchoring opens the app and clicks nothing; clicks return after 3 s, when the thumb lifts or when it slides out; Force Click does not Look up; drags, scrolling and the mouse are untouched; blocking follows grants and revokes live.

**Blocked by:** S3.

**Requirements:** R4, R5, R6, R7, R8 (on hardware), R9 (the mask and the parser read only a press and what belongs to it; the rewrite changes only a blocked press's drags; the tap confined to one file; the TCC log).

**Test scenarios:** T44, T45, T46.

- [ ] The hardware session under Verified without a test (R4, R5, R6, R7, R8, the R9 TCC log, the tap thread count, idle CPU, the disabled-tap recovery) is run with access granted and ticked; any `GestureRules` or mask change is written back into the design.
- [ ] T48's `tapCreate` and `CGEventTapCreate` confinement has its one real hit in `ClickTap.swift`; `grep -rn tapEnable LauncherKit/Sources` hits `ClickTap.swift` only (nothing on the frame thread enables or disables the tap).
- [ ] The open questions hardware can answer are recorded in the plan: pressure events reaching a session tap, Look up suppressed, grants broadcast from System Settings, Debug and Release as separate TCC clients, and whether a firm tap commonly hits the landing race.
