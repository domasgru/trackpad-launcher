## Design

### Problem

Plan 006 adds a fifth tap and a second kind of gesture, the swipe, to an app whose whole shape is "one pure recognizer on the frame thread, one `@MainActor` model that owns every decision, adapters behind small ports, a thin shell". The fifth tap is one enum case (F13). The swipe is not: it is the first gesture that lasts, that outlives the thumb (R8, R9), that produces a stream rather than one event, and that must keep clicks blocked and scrolling suppressed for as long as it lasts (R13) with no 3 s cap and no timer (F8, `docs/architecture.md`). Today's recognizer spoils a tap on exactly the movement a swipe begins with (F9 ii), ends a two-finger rest at 400 ms that R3 says may still become a swipe (F9 i), and wipes every state the moment the anchor is lost (F9 iii). The event tap reads presses only and `scrollWheel` is banned (F17); suppression must ride the same per-frame flag as click blocking because the two clocks cannot be compared (F8), and momentum arrives after the fingers have lifted, when that flag is already false (F18). The frontmost app is a main-actor fact read through `NSWorkspace` (F1, F2); the switcher list's 80 pt icons take up to 220 ms to draw cold (F4) and must be ready before the swipe; a probe found main-actor hops from one thread arrive in order but the language does not promise it (F6), while libdispatch does. `Settings` gains fields and today's records must still decode (F22). The window must grow with the list and cap at the visible frame (F28), the Add app… menu is a second shape of the picker's data (F29), and every "never" is a token in `SourcePolicyTests` (F17). The design must settle O1–O10 against these facts without changing any rule of plans 001–004 that 006 does not amend.

### Usage (caller's view)

**README excerpt.** `Launcher` still owns every decision. The recognizer gains one more thing it can say about a frame: besides "a tap fired" it can say "a swipe began / moved by this many millimetres / ended / was cancelled", and its blocking flag is true for the whole of a swipe. Nothing about the switcher's row, selection or haptics lives on the frame thread: the model builds the row from the switcher list and the frontmost app the moment a swipe begins, maps travel to a selection and a highlight through a pure function, ticks on each selection change, and on the lift brings the selected app to the front. The switcher is model state, `launcher.switcher`, rendered by a non-activating glass panel in the shell exactly as the launcher window renders `launcher.rows`. Scroll suppression is one more verdict of the existing click filter behind the existing event tap: a finger scroll event is passed with its deltas zeroed whenever the same per-frame flag that blocks clicks is up, and its momentum follows its gesture. The switcher list is a third thing `Settings` persists, edited in the launcher window through three intents. Tests drive all of it synchronously through `World`: the in-memory hardware steps the real recognizer and delivers swipe phases inline; the recording system actions answer "frontmost app"; the switcher's row, selection and highlight are read straight off the model.

```swift
// TrackpadLauncher app target: unchanged. WorkspaceActions now also answers frontmostApp() and plays two
// haptic strengths; MenuBarShell now also presents the switcher. No new adapter, no new argument.
let launcher = Launcher(
    hardware: MultitouchTrackpads(), preferences: SystemTrackpadPreferences(),
    access: SystemAccessibilityPermission(), system: system, catalog: catalog,
    scanner: SystemAppScanner(catalog: catalog), store: SettingsStore(defaults: .standard))
let shell = MenuBarShell(launcher: launcher)   // owns the launcher panel, the switcher panel and both icon caches
launcher.start()
```

```swift
// LauncherCoreTests, the high seam. R3 + R4 + R5 + R6 + R7 + R8 in one scenario, synchronous.
@MainActor @Test func swipingTwoIconsRightTicksTwiceAndLiftingOpensSlack() {
    let world = World(apps: ["Safari", "Mail", "Slack", "Notes"])
    world.launcher.start()
    for name in ["Mail", "Slack", "Notes"] { world.launcher.addToSwitcher(.app(world.app(name))) }
    world.system.frontmost = world.app("Safari")                       // the fake's answer to frontmostApp()

    let frames = TouchScript(.macBook14).thumb(atMM: (10, 10))
        .land(fingers: 2).slide(byMM: (5, 0), over: .milliseconds(50))  // past 3 mm sideways: the swipe begins
        .slide(byMM: (24, 0), over: .milliseconds(200)).hold(.milliseconds(100))
        .liftFingers().frames
    world.hardware.touch(frames.dropLast(12), on: Trackpad.macBook14.id)   // everything up to the hold

    let switcher = try #require(world.launcher.switcher)
    #expect(switcher.row == [world.app("Safari"), world.app("Mail"), world.app("Slack"), world.app("Notes")])   // R4
    #expect(switcher.frontmost == 0 && switcher.selected == 2)            // R5 start, R6: 24 mm = two steps
    #expect(switcher.highlight == 2.0)                                    // the highlight sits on Slack
    #expect(world.hardware.ticks == [Trackpad.macBook14.id, Trackpad.macBook14.id])   // R7: one per icon crossed

    world.hardware.touch(frames.suffix(12), on: Trackpad.macBook14.id)    // the lift
    #expect(world.system.broughtToFront == [world.app("Slack")])          // R8
    #expect(world.hardware.feedback == [Trackpad.macBook14.id])           // the gesture haptic, once
    #expect(world.system.launchAnimations.isEmpty)                        // no launch animation on a swipe
    #expect(world.launcher.switcher == nil && !world.launcher.isWindowOpen)
}

// R8 "Staying on the frontmost app", R3 "Two-finger tap that drifts": the silent lift.
@MainActor @Test func liftingOnTheFrontmostAppClosesTheSwitcherAndDoesNothingElse() {
    let world = World(apps: ["Safari", "Mail"])
    world.launcher.start()
    world.launcher.addToSwitcher(.app(world.app("Mail")))
    world.system.frontmost = world.app("Safari")
    world.hardware.touch(TouchScript(.macBook14).thumb(atMM: (10, 10)).tap(fingers: 2, dragMM: 4).frames,
                         on: Trackpad.macBook14.id)
    #expect(world.system.broughtToFront.isEmpty && world.hardware.pulses.isEmpty && world.launcher.switcher == nil)
}

// R13 "Press during a late swipe is blocked": the flag stays up for the whole swipe, however old the thumb.
@MainActor @Test func aPressDuringASwipeBegunAfterTheWindowIsBlockedAndTheLiftOpensTheApp() {
    let world = World(apps: ["Safari", "Slack"], accessGranted: true)
    world.launcher.start()
    world.launcher.addToSwitcher(.app(world.app("Slack")))
    world.system.frontmost = world.app("Safari")
    let frames = TouchScript(.macBook14).thumb(atMM: (10, 10)).wait(.seconds(4))
        .land(fingers: 2).slide(byMM: (16, 0), over: .milliseconds(100))
        .press(for: .milliseconds(100)).liftFingers().frames
    world.hardware.touch(frames, on: Trackpad.macBook14.id)
    #expect(world.hardware.pressVerdicts == [.drop, .drop])
    #expect(world.system.broughtToFront == [world.app("Slack")])
}

// R23: a record saved by today's build still loads, and the new fields round-trip.
@MainActor @Test func aRecordWithoutASwitcherListLoadsWithAnEmptyOne() {
    let world = World(apps: ["Arc"])
    UserDefaults(suiteName: world.suiteName)!.set(Fixtures.plan002Record(two: world.app("Arc")), forKey: "settings")
    let relaunched = world.relaunch()
    #expect(relaunched.app(for: .two) == .present(world.app("Arc")) && relaunched.switcherList.isEmpty)
}
```

```swift
// The recognizer's own seam: R3 begin, R9 cancel, R13 flag, frame by frame.
@Test func aThirdFingerCancelsTheSwipeAndNothingFiresUntilEveryFingerHasLifted() {
    let frames = TouchScript(.macBook14).thumb(atMM: (10, 10))
        .land(fingers: 2).slide(byMM: (10, 0), over: .milliseconds(100))
        .land(fingers: 1).hold(.milliseconds(50)).liftFingers().tap(fingers: 1).frames
    var recognizer = GestureRecognizer(handMode: .right, surface: .macBook14)
    let events = frames.compactMap { recognizer.step($0).event }
    #expect(events.first == .swipe(.began) && events.contains(.swipe(.cancelled)))
    #expect(events.last == .fired(.one))                     // the tap after the clean slate still fires
}

@Test func blockingHoldsForTheWholeSwipeEvenAfterTheThumbLifts() {
    let frames = TouchScript(.macBook14).thumb(atMM: (10, 10)).wait(.seconds(4))
        .land(fingers: 2).slide(byMM: (10, 0), over: .milliseconds(100)).liftThumb()
        .hold(.milliseconds(100)).liftFingers().frames
    var recognizer = GestureRecognizer(handMode: .right, surface: .macBook14)
    let perFrame = frames.map { recognizer.step($0) }
    let swiping = perFrame.drop { $0.event != .swipe(.began) }.prefix { $0.event != .swipe(.ended) }
    #expect(swiping.allSatisfy(\.blocking))                  // R13, with the thumb gone halfway through
    #expect(perFrame.last?.blocking == false)                // R4 alone applies again
}
```

```swift
// The click filter's own seam: R12 + R14 as a pure table. The same flag the presses read.
@Test func aSuppressedScrollIsStilledWithItsMomentumAndAWheelMouseNeverIs() {
    var filter = ClickFilter()
    #expect(filter.decide(.wheel, trackpadBlocking: true) == .pass)                           // R12 wheel mouse
    #expect(filter.decide(.scroll(.began), trackpadBlocking: true) == .passAsStill)
    #expect(filter.decide(.scroll(.changed), trackpadBlocking: true) == .passAsStill)
    #expect(filter.decide(.scroll(.ended), trackpadBlocking: false) == .passAsStill)            // the fingers lifted
    #expect(filter.decide(.scroll(.momentumBegan), trackpadBlocking: false) == .passAsStill)    // R14 no coasting
    #expect(filter.decide(.scroll(.momentumEnded), trackpadBlocking: false) == .passAsStill)
    #expect(filter.decide(.scroll(.began), trackpadBlocking: false) == .pass)                   // a new gesture
    #expect(filter.decide(.scroll(.changed), trackpadBlocking: false) == .pass)
    #expect(filter.decide(.scroll(.ended), trackpadBlocking: false) == .pass)
    #expect(filter.decide(.scroll(.momentumBegan), trackpadBlocking: true) == .pass)            // R14 coasting from before
}
```

```swift
// LauncherUI: the switcher list section reads the model and sends three intents; the Add app… button is the
// picker's button in pull-down form over a second pure menu shape.
struct SwitcherListSection: View {
    let launcher: Launcher; let actions: LauncherActions; let listMaxHeight: CGFloat
    var body: some View {
        SwitcherIllustration(handMode: launcher.handMode); Text("Swipe to switch apps")
        if !launcher.switcherList.isEmpty {
            List {
                ForEach(launcher.switcherList) { row in SwitcherListRowView(row: row, icon: actions.cachedIcon) }
                    .onDelete { launcher.removeFromSwitcher(at: $0) }
                    .onMove { launcher.moveSwitcherApps(from: $0, to: $1) }      // R20 (see O9)
            }
            .frame(maxHeight: listMaxHeight)                                    // R22: the list scrolls, nothing else
        }
        AppMenuButton(.pullDown(title: "Add app…"),
                      menu: { launcher.installedApps.addMenu(listed: launcher.switcherList.ids) },   // R18
                      cachedIcon: actions.cachedIcon,
                      choose: { launcher.addToSwitcher($0) },
                      chooseOther: { actions.chooseOtherApp(.switcherList) })
    }
}

// MenuBarShell: one more Observations loop, the same shape as the window's.
observations.append(Task { [weak self] in
    for await switcher in Observations({ launcher.switcher }) { self?.switcherPanel.render(switcher) }
})
```

### Shape

**Data first.**

- *What a frame meant.* `Recognition { event: Event?; blocking: Bool }`. `Event` is `.fired(Gesture)` or `.swipe(SwipePhase)`, at most one per frame (a tap fires on the frame its last finger is gone; a swipe begins on a frame a finger is still down, so the two never coincide). `SwipePhase` is `.began`, `.moved(travelMM:)`, `.ended`, `.cancelled`. `travelMM` is the sideways displacement of the two fingers' midpoint since the begin frame, in trackpad millimetres (`Δx × widthMM`, F11), positive to the right in both hand modes because `SurfacePoint.x` is left-to-right regardless of hand (F11, R6). It is absolute, not a delta: a late or coalesced `moved` is harmless. `blocking` replaces `blocksClicks` and means "clicks blocked and trackpad scrolling suppressed": the thumb's 3 s window with another contact down (plan 002 R4), or the whole of a swipe (R13). `fired: Gesture?` stays as a derived convenience so today's tests read.
- *What the recognizer remembers.* `State` becomes `idle | armed(Anchor) | tapping(Anchor, Tap) | resting(Anchor, Tap) | spoiled(Anchor) | swiping(Swipe)`. The four tap states carry a required `Anchor` exactly as today; `Swipe` carries `anchor: Anchor?`, the two finger IDs, the midpoint x at begin and the last travel sent. That is the type saying what R8 and R9 say: a tap needs the thumb, a swipe does not, and a thumb that lifts, leaves or re-lands during a swipe only changes the swipe's optional anchor. `.resting` is "exactly two fingers past the tap limit": it can still become a swipe (R3 no time limit) and can never fire (plan 002 R2). `.spoiled` is unchanged and is also the state after a swipe ends or cancels while a thumb is anchored: it recovers only when the anchor is alone, which is R8/R9's "nothing further until every non-thumb finger has lifted"; with no thumb, the state after a swipe is `.idle`, where a resting finger is never adopted and a landing thumb beside it goes to `.spoiled` (F9, `how.md` §4.3), the same rule by a different route (per `model-the-domain`).
- *What crosses the hardware port.* `TrackpadEvent` gains one case, `.swipe(SwipeEvent)`, where `SwipeEvent { phase: SwipePhase; trackpad: TrackpadID }`, beside `.gesture(GestureEvent)` and `.trackpadsChanged`. One core initialiser, `TrackpadEvent(_ event: Recognition.Event, on: TrackpadID)`, is the only mapping and both adapters use it.
- *What the event tap sees.* `PointerEvent` gains `.scroll(ScrollPhase)` for finger-driven scrolling (pixel units: trackpad or Magic Mouse) and `.wheel` for a line-unit wheel mouse (F18 `isContinuous`). `ScrollPhase` is a flat enum of the system's two phase fields: `mayBegin, began, changed, ended, cancelled` while fingers are on the surface, `momentumBegan, momentumChanged, momentumEnded` afterwards, and `plain` when neither field is set. `PointerVerdict` gains `.passAsStill`: the event is delivered with every scroll delta zeroed. `CGEvent`, its fields and the raw phase values stay in `ClickTap` (F15, F17).
- *What the model shows.* `switcher: Switcher?`, nil when no swipe is up. `Switcher { row: [AppEntry]; frontmost: Int; travelMM: Double; trackpad: TrackpadID }` with `selected`, `highlight` and `overshootMM` derived from `travelMM` by `SwitcherGeometry`: no second field can disagree with the travel (per "derive instead of sync"). `switcherList: [SwitcherListRow]`, where `SwitcherListRow { assigned: AssignedApp; app: AppEntry? }` is the window's view of one listed app, `nil` meaning missing by the rule rows already use (F3). `rows` grows to five by `Gesture.allCases` (F13).
- *What is persisted.* `Settings { handMode; assignments: [Gesture: AssignedApp]; switcherList: [AssignedApp] }` with a hand-written decoder that treats `switcherList` as optional (F22, the `LaunchTuning` precedent). The first-launch fact is still the absence of a record (F23).
- *What the window needs.* `InstalledApps.addMenu(listed:) -> [PickerItem]` is the Add app… menu; `PickerItem.app(AppEntry, state: AppItemState)` where `AppItemState` is `plain | current | listed` (checked; checked and disabled), replacing the bare `checked:` flag. `Copy.gestureHint(for:)` and `Copy.accessibilityHint` are the two strings R15 and R24 pin, with the two marks as `●` and `◉` that the view swaps for its images.

**Load-bearing decisions.**

1. *One recognizer, one more branch where the drag rule was.* In `.tapping` and `.resting`, the frame that first shows a finger more than 3 mm from its landing point decides: with exactly two fingers down, exactly two touched since the clean slate, no delivered click, and the mover's displacement more sideways than vertical (`|Δx·W| > |Δy·H|`), the state becomes `.swiping` and the frame's event is `.swipe(.began)`; otherwise `.spoiled`, as today (R3). So the swipe begins exactly where plan 001's drag rule spoiled, and every tap rule for one, three, four and five fingers is untouched. The 400 ms check sends a two-finger tap to `.resting` instead of `.spoiled` (R3 "no time limit"; plan 002 R2 kept because `.resting` cannot fire). Anchor maintenance at the top of `step` sends every tap state to `.idle` on a lost anchor as today, and for `.swiping` only clears `swipe.anchor`; a thumb landing in the admit zone while `swipe.anchor` is nil becomes the new anchor with `landedAt = frame.time`, so after the swipe it opens a correct window (O1, R9 "Thumb lands again"). A swipe's exit conditions are exactly three and named in the pseudocode: the first lift of either finger ends it (R8), a delivered click or a landing contact outside the corner cancels it (R9), and `run` replaces the recognizer. `blocking` is `true` in `.swiping` and the plan 002 window rule otherwise (R13; F21: the existing flag, no new channel). No timer and no second clock (F8; per `model-the-domain`, `encode-lessons-in-structure`).
2. *Travel in millimetres crosses the port; the main actor maps it.* The recognizer knows nothing of the row (O2). `SwitcherGeometry` is three pure functions over `(travelMM, start, count)`: `position` = `start + travel / 12` clamped to `0...count-1`, `selection` = `position` rounded to nearest, `overshootMM` = the travel beyond an end, signed, else 0. That is R6 in nine lines, testable without a frame, and the recognizer's interface stays one method (per `boundary-discipline`, pure policy inside).
3. *Delivery is the documented FIFO path.* `DeviceSession.deliver` becomes `DispatchQueue.main.async { MainActor.assumeIsolated { onEvent?(event) } }`, the pattern `SystemAppScanner.handleChange` already uses. The probe found unstructured `Task`s arrive in order too (F6), but libdispatch documents FIFO for a serial queue and the swap costs nothing (O3). Each `moved` carries absolute travel, so even a hypothetical reorder of two `moved`s is a one-frame glitch, never a wrong selection; `began` before `moved` before `ended` is what the queue guarantees. The in-memory adapter still calls `onEvent` inline (F7). No coalescing: the model's work per `moved` is a pure function and one property write, and SwiftUI coalesces observation per run-loop turn.
4. *The switcher is model state; the shell renders it.* `Launcher` owns `switcher` and is its only writer (O5, F24: "the shell renders the model's state"). On `.swipe(.began)` it guards `activity.isActive` and `switcher == nil`, locates every switcher-list app fresh through `catalog.locate` (the rule taps use at fire time, F3), asks `system.frontmostApp()`, and builds the row with `SwitcherRow.make(list:frontmost:)`: list order, missing apps left out, the frontmost prepended when absent, nil when the row is empty or holds only the frontmost (R4, R5, R11). A nil frontmost, which the adapter also returns for Trackpad Launcher itself (F2, O6), means "absent": nothing is prepended and the selection starts on the leftmost icon. On `.moved` it stores the travel and plays `.tick` when `selected` changed (R7). On `.ended` it fronts the selected app with the gesture haptic and closes the window, or does nothing when the selection is the frontmost index (R8); on `.cancelled` it clears (R9). `reconcile()` clears the switcher before `run`, because the recognizer it replaces can never end it (per `make-operations-idempotent`). Events for a trackpad other than the switcher's are ignored while one is up. The launch overlay stays an effect because it has no state; the switcher has state tests must read, so it is state (F24, F26).
5. *The frontmost app is one read on `SystemActions`.* `frontmostApp() -> AppEntry?` parses `NSWorkspace.shared.frontmostApplication` at the boundary (bundle ID, bundle URL, localized name; F1), nil when absent, when it lacks either, or when it is this process. A port of its own would be a one-method seam over the same `NSWorkspace` the adapter already wraps (per `boundary-discipline`; no shallow port).
6. *Scroll suppression is one more verdict of the click filter, through the same flag.* `ClickFilter.decide(.scroll(phase), trackpadBlocking:)`: `.wheel` always passes (R12, F18 `isContinuous == 0`); a finger event with the flag up is `.passAsStill`, with it down `.pass`; `began` resets one bit of memory, `began`/`changed` under the flag set it, and every momentum event reads it: suppressed iff any moving event of its gesture was suppressed (O4, R14). That rule survives the race between the lift frame (which drops the flag) and the last `changed` or the `ended` event, which no clock can order (F8), and it makes "late swipe" (R13) correct: a gesture that began unsuppressed is stilled from the frame the swipe begins. "Suppress" is zeroed deltas, not a drop: apps then see a complete `began…ended` and momentum bracket in every case, including a gesture stilled partway through, which R13 makes an ordinary case; and nothing coasts because the momentum deltas are zero (F18: the fields round-trip). Drop would leave an app mid-gesture whenever suppression starts after `began`. `forgetHeldPresses()` becomes `forgetInFlight()` and also clears the scroll bit (under-blocking, the safe direction). Without the permission there is no tap and nothing is read (F20).
7. *The gate moves one token.* `scrollWheel` goes from `banned` to `Confined(onlyIn: "ClickTap.swift")`; `ScrollWheel` stays banned (no shipped source needs it, and the case-sensitive overlap check is satisfied). `PointerEventTests` pins bit 22 in the mask, parses `.scroll`/`.wheel` from synthetic events built with `CGEvent(scrollWheelEvent2Source:…)` and the F18 fields, drops `.scrollWheel` from `ignoresEverythingElse`, and checks `.passAsStill` zeroes six delta fields and keeps the type and phase (F17).
8. *Icons are ready before the swipe.* `SwitcherIcons` in `LauncherUI` is `AppIcons` at 80 pt (2x and 1x, `[URL: Rendered]`, stamped, drawn off the main actor), fed from an `Observations` loop over `launcher.switcherList`'s present apps and from the window-open pass (F5). The frontmost app is unknown until the swipe begins; its icon comes from `NSRunningApplication.icon`, which drew in 0.1 ms in both probe runs (F4 b), falling back to a draw on the spot as `LaunchOverlay.bitmap(for:scale:)` does for a moved app. The switcher panel is warmed up at shell init like the overlay's (F26, F32).
9. *The panel is the overlay's, with glass and never key.* `SwitcherPanel` copies `LaunchOverlay.makePanel`'s configuration (borderless, non-activating, `ignoresMouseEvents`, `.screenSaver`, `canJoinAllSpaces + fullScreenAuxiliary + stationary + ignoresCycle`, `hidesOnDeactivate = false`, `animationBehavior = .none`) and hosts an `NSGlassEffectView` like `LauncherPanel` but with `canBecomeKey` false (R10 "never take focus"). It is centred on the display under `NSEvent.mouseLocation` by the `NSMouseInRect` rule `LaunchFlight.display(for:among:)` uses. Appearance is `orderFrontRegardless()` with the row already laid out; disappearance is `orderOut` after a 150 ms opacity keyframe whose completion closes it, or at once under Reduce motion (R10, F27). The highlight is a glass capsule positioned at `highlight × 100 pt`; it tracks without animation while the fingers move and plays one spring when `overshootMM` first leaves zero (the "slightly past, springs back" of R6), none under Reduce motion.
10. *The window.* The fifth row is `Gesture.five` flowing through `makeRows` and `GestureIllustration("gesture-5")` (F13, O10). The switcher section is a `List` of `switcherList` rows (hover reveals a remove button, the context menu offers Remove, `onMove` reorders; R19, R20, O9), with the hand-mode toggle after it. `LauncherPanel.fitToContent` caps the height at the visible frame minus 16 pt and the shell hands the view a `WindowLimits.maxHeight` it observes; the view measures its own and the list's natural heights and gives the list `maxHeight − (own − list)`, so only the list scrolls (R22, F28). `MenuBarShell` refits on `switcherList.count` changes. Add app… is `AppMenuButton` in pull-down form over `addMenu(listed:)`, built in `menuNeedsUpdate` from values in memory with `cachedIcon` (F29, R18). Other… goes through `chooseOtherApp(.switcherList)`, the same `NSOpenPanel` path with a `PickerTarget` instead of a `Gesture`.

**Depth.**

| Module | Public surface | What it hides |
|---|---|---|
| `GestureRecognizer` | `init`, `step` → `Recognition` (2 fields; `Event` has 2 cases, `SwipePhase` 4) | R1, R3, R8, R9's frame half, R13's flag: six states, the drag-or-swipe fork, resting, the optional anchor and its re-landing, midpoint travel in mm, exit conditions |
| `SwitcherGeometry` + `SwitcherRow.make` | 4 pure functions | R4, R5, R6, R11: row assembly, 12 mm / 6 mm, hard stops, overshoot |
| `ClickFilter` | `decide`, `holding`, `forgetInFlight` (one new `PointerEvent` case pair, one new verdict) | R5 as before plus R12–R14: wheel exemption, per-event stilling, momentum memory across the lift |
| `TrackpadHardware` | 4 members (`playFeedback` gains a kind; `TrackpadEvent` gains a case) | The tap's new mask, scroll parsing and zeroing, the FIFO hop, two actuation strengths |
| `SystemActions` | +1 read | `NSRunningApplication`, the self-exclusion |
| `Launcher` | +2 observed properties (`switcher`, `switcherList`), +3 intents | Row building at begin, the tick, end and cancel effects, the reconcile cancel, dedupe and order of the list, the tolerant record |
| `InstalledApps` | +1 method | The second menu shape with disabled state |

Framework types never cross a port: `CGEvent`, `CGScrollPhase`, `NSRunningApplication`, `NSPanel` stay in adapters and views.

**Concurrency** (one writer per field).

- *Frame thread:* steps the recognizer, writes its session's `blocking`, enqueues the frame's event on the main queue. ~100 Hz while a swipe is in progress, which is input-driven work, not a per-display-frame loop (F27).
- *Tap thread:* reads the flags, decides under the filter lock; scroll events add 100–250 Hz of wake-ups while anyone scrolls with the tap armed (F19, accepted).
- *Main actor:* `Launcher` writes `switcher`; the shell and `SwitcherView` read it; `SwitcherIcons` merges off-main renders on main as `AppIcons` does. The frontmost read, the row build and the tick happen on main at begin and per `moved`.

**Requirement trace and seams.**

| R | Carried by | Verified at |
|---|---|---|
| R1 | `Gesture.five`; `init?(fingerCount:)` nil above 5 | Recognizer seam: `thumbThenNFingerTapFiresThatGestureOnce` over 1...5; `fiveFingerTapFiresNothing` and `fiveFingersInARollingTapFireNothing` become "fires `.five`"; a six-finger script → nothing. `World`: Slack not Spotify |
| R2 | `Gesture.allCases` → `makeRows`; `gesture-5.svg` (O10) | `World`: five rows, fifth assignment fronts on a five-finger tap; `PersistenceTests` `count: 5`. Illustration and mirroring: manual |
| R3 | `.tapping`/`.resting` → `.swiping` fork; `.resting` on the 400 ms check; `.spoiled` for vertical | Recognizer seam: 5 mm sideways → `.began`; rest 2 s then slide → `.began`; 10 mm down then 20 mm right → no `.began`; one finger, three fingers → none; `tap(fingers: 2)` → `.fired(.two)`; fingers before thumb → none; the drift scenarios → `.began`,`.ended` with no `.fired` |
| R4, R5, R11 | `SwitcherRow.make(list:frontmost:)`; the begin guard | Pure: each R4/R5/R11 row scenario as a table. `World`: Figma in the Trash left out; empty list and only-frontmost → `switcher == nil`; `tapToClick` on → no frames run |
| R6 | `SwitcherGeometry`; `Switcher.selected/highlight/overshootMM` | Pure: 24 mm → +2; 5 mm → same icon, `highlight` 0.42; 7 mm → next; 24 then −12 → +1; past the end → clamped, `overshootMM` > 0; left hand → same sign (travel is x-axis) |
| R7 | `Launcher` on `.moved`: tick when `selected` changed | `World`: 36 mm → `ticks.count == 3`; 5 mm → none |
| R8 | `Launcher` on `.ended`; `.swiping` ends on the first lift | `World`: Slack fronted, one gesture pulse, no animation, window closed; one finger lifts first; whole hand together; thumb lifted then 24 mm; frontmost selected → nothing. Recognizer seam: `.ended` on the first lift frame and nothing after |
| R9 | `.swiping` cancel on `.click` or a landing outside the corner; `swipe.anchor` optional | Recognizer seam: thumb out, thumb re-lands (later blocking from the new `landedAt`), third finger → `.cancelled`, `.click` → `.cancelled`, `.blocked` → continues. `World`: unblocked click (`granted: false`) → nothing fronted; blocked press → `[.drop, .drop]` and fronted |
| R10 | `SwitcherPanel`, `SwitcherView`, `SwitcherIcons` | Manual: look, glass, 80 pt / 20 pt, centring on the pointer's display, full-screen Safari, light/dark, Reduce motion, appear and disappear timing, focus stays in Notes |
| R12 | `ClickFilter.decide(.scroll/.wheel)`; `blocking` | Filter seam: the table above. `World`: `hardware.scroll(.began)` under the window → `.passAsStill`; after 4 s → `.pass`; thumb lifted → `.pass`; `hardware.wheel()` → `.pass`; `granted: false` → no verdicts and the switcher works. Real scrolling in Safari: manual |
| R13 | `blocking == true` in `.swiping` | Recognizer seam: per-frame flags across a late swipe and across a thumb lift. `World`: late-swipe press `[.drop, .drop]`; scroll verdicts `.passAsStill` from `.began` of the swipe on |
| R14 | The scroll memory bit | Filter seam: flick under the window → momentum stilled; momentum of an unsuppressed gesture passes with the flag up |
| R15, R24 | `Copy.accessibilityHint`, `Copy.gestureHint(for:)` | Core: exact strings per hand mode. Rendered: manual |
| R16, R21 | `SwitcherListSection`, `SwitcherIllustration` | Manual layout; `World`: empty `switcherList` on first launch |
| R17 | `switcherList` rows via `catalog.locate` in `resolveRows` | `World`: order equals the next row; trash Figma, open → `app == nil`; restore, reopen → present |
| R18 | `addMenu(listed:)`; `addToSwitcher`; `chooseOtherApp(.switcherList)` | Core: menu projection `["Arc", "✓ Mail (listed)", …, "Other…"]`, no None. `World`: append; Other… from Downloads; Other… on a listed app → unchanged; Arc on a tap and in the list |
| R19, R20 | `removeFromSwitcher`, `moveSwitcherApps` | `World`: list order after each. Hover button, context menu, dragging: manual (O9) |
| R22 | `WindowLimits.maxHeight`; `fitToContent` cap; refit on count | Manual on a 13" display with 30 apps |
| R23 | `Settings.switcherList`, `Gesture.five`, tolerant `init(from:)` | `PersistenceTests`: relaunch; an old record (`Fixtures.plan002Record`) loads; round trip of the new shape |

**Test handles.**

| Thing | Handle |
|---|---|
| Every clock (400 ms, 3 s, "no time limit") | `TouchFrame.time`; `TouchScript.wait/hold` |
| A swipe's frames | `TouchScript.land(fingers:atMM:)`, `slide(byMM:over:)`, `hold(_:)`, `liftFingers(_:)`, `press(for:)`, `liftThumb()`, a second `thumb(atMM:)` to re-land; `HandFrames` for anything else |
| The frontmost app | `RecordingSystemActions.frontmost: AppEntry?` |
| The switcher's visible state | `launcher.switcher` (`row`, `frontmost`, `selected`, `highlight`, `overshootMM`) |
| Haptic kinds | `InMemoryTrackpads.pulses: [Pulse]`; `feedback` (gesture pulses) and `ticks` derived |
| The swipe stream | `Recognition.event` per frame; `InMemoryTrackpads.touch` delivers inline; `inject(_:)` now takes a `TrackpadEvent` |
| Scroll events | `ClickFilter.decide(.scroll/.wheel)` pure; `InMemoryTrackpads.scroll(_:) -> PointerVerdict` and `wheel()` against the previous frame's flags; synthetic `CGEvent`s in `PointerEventTests` |
| The old settings record | `Fixtures.plan002Record(two:)`: a plist of the plan 002 shape written through `PropertyListEncoder` |
| A reconcile mid-swipe | `preferences.set` between two `touch` calls → `switcher == nil` |

**Deliberately not done.** No timer, deadline or coalescing. No swipe id or sequence number (FIFO delivery makes it unnecessary). No port for the switcher and no port for the frontmost app. No recognizer knowledge of the row. No launch animation on a swipe. No device attribution of scroll events beyond `isContinuous`. No cap on the list, no sliding row. No change to any tap constant.

#### Module map

```
LauncherCore     GestureRules (dragThresholdMM doubles as the swipe threshold) · Recognition (+ Event, SwipePhase) ·
                 GestureRecognizer (+ resting, swiping) · Gesture (+ five) · SwipeEvent · TrackpadEvent (+ swipe) ·
                 PointerEvent (+ scroll, wheel) · ScrollPhase · PointerVerdict (+ passAsStill) · ClickFilter (+ scroll bit) ·
                 Switcher · SwitcherGeometry · SwitcherRow · SwitcherListRow · Feedback · Copy ·
                 Settings (+ switcherList, tolerant decoder) · InstalledApps (+ addMenu) · PickerItem (+ AppItemState) ·
                 ports: TrackpadHardware (playFeedback kind), SystemActions (+ frontmostApp) · Launcher (+ switcher,
                 switcherList, three intents, begin/move/end/cancel, reconcile cancel)
LauncherPlatform DeviceSession (deliver any event, FIFO hop) · MultitouchTrackpads (two actuations) · ClickTap (scroll in
                 the mask, parse, zeroing) · WorkspaceActions (frontmostApp)
LauncherUI       MenuBarShell (switcher loop, icons loop, refit on list) · SwitcherPanel · SwitcherView · SwitcherIcons ·
                 LauncherView (fifth row, SwitcherListSection, hint from Copy) · AppMenuButton (picker + pull-down) ·
                 LauncherPanel (height cap) · WindowLimits · LauncherActions (PickerTarget)
Tests            TouchScript (five primitives) · InMemoryTrackpads (events, pulses, scroll) · RecordingSystemActions
                 (frontmost) · Fixtures (plan002Record) · SourcePolicyTests (scrollWheel confined) · PointerEventTests
Docs             domain-model (new terms, five amended entries) · architecture (Accessibility sentence, hop sentence)
```

#### LauncherCore: recognition

```swift
import Foundation

/// What one frame meant on one trackpad.
public struct Recognition: Equatable, Sendable {
    public enum Event: Equatable, Sendable {
        /// At most once per tap, on the frame where its last finger is gone (plan 002 R3).
        case fired(Gesture)
        /// The swipe changed on this frame (R3, R6, R8, R9).
        case swipe(SwipePhase)
    }
    /// At most one per frame: a tap fires on a frame its last finger is gone, a swipe begins on a frame a finger moved.
    public let event: Event?
    /// This trackpad's half of click blocking, which now also suppresses trackpad scrolling (R12): a thumb this
    /// recognizer saw land less than 3 s ago is still anchored and another contact is down, or a swipe is in
    /// progress whatever the thumb does (R13). Whether anything is really blocked also needs the filter armed.
    public let blocking: Bool
    /// Convenience for callers and tests that only care about taps.
    public var fired: Gesture? { if case .fired(let g) = event { g } else { nil } }
    public init(event: Event?, blocking: Bool) { fatalError("not implemented") }
}

/// The swipe as the frame thread sees it. Travel is the sideways displacement of the two fingers' midpoint since
/// the begin frame, in trackpad millimetres, positive to the right in both hand modes (R6). Absolute, not a delta.
public enum SwipePhase: Equatable, Sendable {
    case began
    case moved(travelMM: Double)
    /// The first of the two fingers lifted (R8).
    case ended
    /// A delivered click or a finger landing outside the anchor corner (R9).
    case cancelled
}

/// The tap-with-anchored-thumb and swipe rules for ONE trackpad, as a pure state machine. Feed every frame in order.
public struct GestureRecognizer: Sendable {
    public init(handMode: HandMode, surface: SurfaceSize) { fatalError("not implemented") }

    public mutating func step(_ frame: TouchFrame) -> Recognition {
        // TODO
        // isFirstFrame / before / down / reused / lifted / landed: unchanged (F10)
        // defer { previouslyDown = Set(down.keys) }
        //
        // 1. Anchor maintenance. If state.anchor lifted, was reused, or left corner.holds:
        //      .swiping(var s): s.anchor = nil; state = .swiping(s)        // the thumb plays no part (R8, R9)
        //      every other state: state = .idle                             // unchanged
        // 2. switch state
        //    .idle, .armed: unchanged (a landed contact in `admits` anchors; landed non-anchor fingers start a Tap)
        //    .tapping(a, var tap):
        //      tap.down.removeValues(forKeys: lifted)
        //      if frame.press == .click → .spoiled(a)
        //      else if let mover = tap.firstFingerPastThreshold(down, surface):          // the old drag rule
        //          if tap.isSwipeCandidate && mover.isSideways → begin swipe (below)
        //          else → .spoiled(a)                                                   // vertical, 1 or 3+ fingers
        //      else if frame.time - tap.start > GestureRules.maxTapDuration
        //          → tap.isSwipeCandidate ? .resting(a, tap) : .spoiled(a)             // R3 no time limit
        //      else if tap.down.isEmpty → fired = Gesture(fingerCount: tap.touched.count); re-arm or new Tap (unchanged)
        //      else join landed fingers (unchanged)
        //    .resting(a, var tap):                                                      // two fingers past 400 ms
        //      if frame.press == .click, or any lifted ∈ tap.down, or landed has a non-anchor finger → .spoiled(a)
        //      else if let mover = tap.firstFingerPastThreshold(...) → mover.isSideways ? begin swipe : .spoiled(a)
        //      else → .resting(a, tap)
        //    .spoiled(a): unchanged (recovers to .armed when the anchor is the only contact)
        //    .swiping(var s):
        //      if frame.press == .click                                   → finish(.cancelled)
        //      else if lifted ∩ s.fingers ≠ ∅                             → finish(.ended)        // first lift wins (R8)
        //      else if landed.contains { $0.id ∉ s.fingers && $0.id != s.anchor?.id && !corner.admits($0.position) }
        //                                                                 → finish(.cancelled)    // third finger (R9)
        //      else:
        //          if s.anchor == nil, let thumb = landed.first(where: corner.admits)
        //              s.anchor = Anchor(id: thumb.id, landedAt: frame.time)        // R9 "Thumb lands again"
        //          let travel = (midX(down[s.fingers.0], down[s.fingers.1]) - s.originMidX) * surface.widthMM
        //          if travel != s.travelMM { s.travelMM = travel; event = .swipe(.moved(travelMM: travel)) }
        //          state = .swiping(s)
        //      finish(phase): event = .swipe(phase); state = s.anchor.map(State.spoiled) ?? .idle
        //          // with a thumb: .spoiled recovers only when it is alone; without: a resting finger is never
        //          // adopted and a landing thumb beside it spoils. Both are "nothing until every finger lifts".
        //    begin swipe (from .tapping or .resting with Tap `tap`, anchor `a`):
        //          let (f1, f2) = tap.down.keys; state = .swiping(Swipe(fingers: (f1, f2), originMidX: midX(down[f1], down[f2]),
        //                                                               anchor: a, travelMM: 0)); event = .swipe(.began)
        // 3. blocking = state.isSwiping || (plan 002 window rule from state.anchor, unchanged)
        fatalError("not implemented")
    }

    private struct Anchor: Sendable { let id: TouchID; let landedAt: FrameTime? }   // unchanged

    private struct Tap: Sendable {
        let start: FrameTime
        var down: [TouchID: SurfacePoint]
        private(set) var touched: Set<TouchID>
        /// Exactly two fingers down and no other finger has touched since the clean slate (R3).
        var isSwipeCandidate: Bool { down.count == 2 && touched.count == 2 }
        /// The first down finger farther than `dragThresholdMM` from where it landed, with its displacement in mm.
        func firstFingerPastThreshold(_ down: [TouchID: Touch], _ surface: SurfaceSize) -> Mover? { fatalError("not implemented") }
        init(start: FrameTime, landing: [Touch]) { fatalError("not implemented") }
        mutating func land(_ touch: Touch) { fatalError("not implemented") }
    }

    private struct Mover: Sendable {
        let dxMM: Double, dyMM: Double
        /// More sideways than up or down (R3).
        var isSideways: Bool { abs(dxMM) > abs(dyMM) }
    }

    /// A swipe in progress. The anchor is bookkeeping only: nil once the thumb lifts or leaves, set again when a
    /// thumb lands in the corner, and handed to `.spoiled` when the swipe ends so taps and the blocking window
    /// continue from the right thumb.
    private struct Swipe: Sendable {
        let fingers: (TouchID, TouchID)
        let originMidX: Double
        var anchor: Anchor?
        var travelMM: Double
    }

    private enum State: Sendable {
        case idle
        case armed(Anchor)
        case tapping(Anchor, Tap)
        /// Two fingers resting past the tap limit: may still become a swipe, never a tap (R3, plan 002 R2).
        case resting(Anchor, Tap)
        case spoiled(Anchor)
        case swiping(Swipe)
        var anchor: Anchor? { fatalError("not implemented") }        // .swiping → swipe.anchor
        var isSwiping: Bool { fatalError("not implemented") }
    }

    private let corner: AnchorCorner
    private let surface: SurfaceSize
    private var state: State = .idle
    private var previouslyDown: Set<TouchID>?
}

/// One of the five launcher gestures, named by finger count.
public enum Gesture: Int, CaseIterable, Codable, CodingKeyRepresentable, Sendable {
    case one = 1, two, three, four, five
    /// nil outside 1...5: a six-finger tap is not a gesture (R1).
    public init?(fingerCount: Int) { self.init(rawValue: fingerCount) }
    public var fingerCount: Int { rawValue }
}

/// A swipe phase on a specific trackpad (the tick and the gesture haptic play on that one).
public struct SwipeEvent: Equatable, Sendable {
    public let phase: SwipePhase
    public let trackpad: TrackpadID
}

public enum TrackpadEvent: Sendable {
    case gesture(GestureEvent)
    case swipe(SwipeEvent)
    case trackpadsChanged
    /// The one mapping from what a recognizer said to what the port carries. Both hardware adapters use it.
    public init(_ event: Recognition.Event, on trackpad: TrackpadID) { fatalError("not implemented") }
}
```

#### LauncherCore: the switcher (pure)

```swift
/// The switcher on screen, from the first sideways movement to the lift or the cancel. Written only by `Launcher`.
public struct Switcher: Equatable, Sendable {
    /// Left to right, fixed for the swipe (R4).
    public let row: [AppEntry]
    /// Index of the frontmost app's icon, where the selection starts (R5); the lift on it is a silent no-op (R8).
    public let frontmost: Int
    /// Sideways midpoint travel since the swipe began, in trackpad millimetres (R6).
    public internal(set) var travelMM: Double
    public let trackpad: TrackpadID

    public var selected: Int { SwitcherGeometry.selection(travelMM: travelMM, start: frontmost, count: row.count) }
    /// Continuous highlight position in icon units: 0 is the first icon's centre, 1 the second's.
    public var highlight: Double { SwitcherGeometry.position(travelMM: travelMM, start: frontmost, count: row.count) }
    /// Travel beyond the row's ends, signed; 0 inside. The view plays its spring when this leaves zero (R6).
    public var overshootMM: Double { SwitcherGeometry.overshootMM(travelMM: travelMM, start: frontmost, count: row.count) }
    public var selectedApp: AppEntry { row[selected] }
}

/// R6 as arithmetic. Icons are `stepMM` of travel apart; the selection is the nearest icon.
public enum SwitcherGeometry {
    public static let stepMM = 12.0
    /// `start + travel / step`, clamped to the row. Between two icons it sits between them in proportion.
    public static func position(travelMM: Double, start: Int, count: Int) -> Double { fatalError("not implemented") }
    /// `position` rounded to the nearest icon: changes 6 mm in, then every 12 mm, reversible, never past an end.
    public static func selection(travelMM: Double, start: Int, count: Int) -> Int { fatalError("not implemented") }
    /// The travel the fingers went past the first or last icon, negative on the left; 0 while inside.
    public static func overshootMM(travelMM: Double, start: Int, count: Int) -> Double { fatalError("not implemented") }
}

/// R4, R5 and R11 as one function.
public enum SwitcherRow {
    /// `list` is the switcher list's present apps in list order. The frontmost app, when not among them, is prepended;
    /// nil when it is unknown (O6). Returns nil when the row would be empty or hold only the frontmost app (R11).
    public static func make(list: [AppEntry], frontmost: AppEntry?) -> (row: [AppEntry], start: Int)? {
        // TODO: index = list.firstIndex { $0.bundleID == frontmost?.bundleID }
        //       (row, start) = index.map { (list, $0) } ?? (frontmost.map { [$0] + list } ?? list, 0)
        //       guard !row.isEmpty, !(row.count == 1 && frontmost != nil) else { return nil }   // R11
        fatalError("not implemented")
    }
}

/// One line of the launcher window's switcher section (R17). `app` nil = missing (no copy outside the Trash).
public struct SwitcherListRow: Identifiable, Equatable, Sendable {
    public let assigned: AssignedApp
    public let app: AppEntry?
    public var id: BundleID { assigned.bundleID }
}

/// The two haptic strengths (R7, R8).
public enum Feedback: Equatable, Sendable {
    /// Plays when an app opens.
    case gesture
    /// Lighter; plays when the switcher's selection changes.
    case tick
}
```

#### LauncherCore: the click filter

```swift
/// Everything the click tap is ever told about, parsed. The tap's mask admits nothing else.
public enum PointerEvent: Equatable, Sendable {
    case press(PressID)
    case release(PressID)
    case drag(button: Int)
    case pressure
    /// Finger-driven scrolling (pixel units): a trackpad or a Magic Mouse, which the system reports alike.
    case scroll(ScrollPhase)
    /// Line-unit scrolling from a wheel mouse. Never suppressed (R12).
    case wheel
}

/// The system's gesture and momentum phases, flattened: a scroll event carries at most one of the two.
public enum ScrollPhase: Equatable, Sendable {
    case mayBegin, began, changed, ended, cancelled
    case momentumBegan, momentumChanged, momentumEnded
    /// Neither field set.
    case plain
    /// `began`, `changed` or `plain`: the events that move a page.
    var moves: Bool { fatalError("not implemented") }
    var isMomentum: Bool { fatalError("not implemented") }
}

public enum PointerVerdict: Equatable, Sendable {
    case pass
    case drop
    case passAsMove
    /// Delivered with every scroll delta zeroed: apps see the gesture's phase bracket, the page does not move.
    case passAsStill
}

/// Click blocking and scroll suppression for one event stream, as a pure state machine. One per tap, fed in order.
public struct ClickFilter: Sendable {
    public enum Holding: Equatable, Sendable { case nothing, withheld, passed }
    public init() {}

    public mutating func decide(_ event: PointerEvent, trackpadBlocking: Bool) -> PointerVerdict {
        // TODO: presses, releases, drags, pressure unchanged.
        // .wheel: return .pass
        // .scroll(let phase):
        //   if phase.isMomentum { if phase == .momentumEnded { defer { scrollSuppressed = false } }
        //                         return scrollSuppressed ? .passAsStill : .pass }           // R14: follows its gesture
        //   if phase == .began { scrollSuppressed = false }                                   // a new gesture
        //   guard trackpadBlocking else { return .pass }                                       // R12: at once, both ways
        //   if phase.moves { scrollSuppressed = true }
        //   return .passAsStill
        fatalError("not implemented")
    }

    public var holding: Holding { fatalError("not implemented") }   // presses only, unchanged

    /// The system disabled the tap: releases and scroll events may have passed meanwhile. Forget every held press
    /// and the scroll gesture in flight (its momentum then passes: under-blocking, the safe direction).
    public mutating func forgetInFlight() { fatalError("not implemented") }

    private var held: [Int: Held] = [:]
    /// Any moving event of the current finger scroll was suppressed, so its momentum is too. Momentum arrives after
    /// the fingers lifted, when `trackpadBlocking` is already false; this bit is what R14 reads instead.
    private var scrollSuppressed = false
}
```

#### LauncherCore: the model, persistence, menu and copy

```swift
/// `fire` and `endSwipe` are the only paths that pulse, front or close the window from a gesture.
@MainActor @Observable
public final class Launcher {
    public private(set) var rows: [GestureRow] = []                 // five, by Gesture.allCases
    /// The window's switcher section, in switcher order, with each app located (R17). Re-resolved with `rows`.
    public private(set) var switcherList: [SwitcherListRow] = []
    /// The switcher on screen; nil when no swipe is up. Written here and nowhere else.
    public private(set) var switcher: Switcher?
    // installedApps, isWindowOpen, handMode, activity, isAccessibilityGranted: unchanged

    public func start() {
        // hardware.onEvent = { event in
        //     switch event {
        //     case .gesture(let fired): fire(fired)
        //     case .swipe(let swipe): handle(swipe)
        //     case .trackpadsChanged: reconcile()
        //     } }
        fatalError("not implemented")
    }

    // MARK: Switcher list intents (R18–R20). Each saves and re-resolves, like setAssignment.
    /// Appends; an app already listed (by bundle ID) is left where it is. `.unassigned` is not an item of this menu.
    public func addToSwitcher(_ choice: AppChoice) { fatalError("not implemented") }
    public func removeFromSwitcher(at offsets: IndexSet) { fatalError("not implemented") }
    public func removeFromSwitcher(_ id: BundleID) { fatalError("not implemented") }
    public func moveSwitcherApps(from source: IndexSet, to destination: Int) { fatalError("not implemented") }

    private func handle(_ swipe: SwipeEvent) {
        // TODO
        // switch swipe.phase {
        // case .began:
        //     guard activity.isActive, switcher == nil else { return }                       // R11 inactive; one at a time
        //     let present = settings.switcherList.compactMap(catalog.locate)                  // fresh, like fire (F3)
        //     guard let (row, start) = SwitcherRow.make(list: present, frontmost: system.frontmostApp()) else { return } // R11
        //     switcher = Switcher(row: row, frontmost: start, travelMM: 0, trackpad: swipe.trackpad)
        // case .moved(let travel):
        //     guard var s = switcher, s.trackpad == swipe.trackpad else { return }
        //     let before = s.selected; s.travelMM = travel; switcher = s
        //     if s.selected != before { hardware.playFeedback(.tick, on: s.trackpad) }        // R7
        // case .ended:
        //     guard let s = switcher, s.trackpad == swipe.trackpad else { return }
        //     switcher = nil
        //     guard s.selected != s.frontmost else { return }                                  // R8 silent no-op
        //     hardware.playFeedback(.gesture, on: s.trackpad); system.bringToFront(s.selectedApp); window = .closed
        // case .cancelled:
        //     if switcher?.trackpad == swipe.trackpad { switcher = nil }                       // R9
        // }
        fatalError("not implemented")
    }

    private func reconcile() {
        // switcher = nil   // the recognizers run() replaces can never end a swipe (idempotent convergence)
        // … unchanged: connected, preferences, grant, hardware.run(…, blockClicks: active && granted)
        fatalError("not implemented")
    }

    private func resolveRows() {
        // rows = makeRows(); switcherList = settings.switcherList.map { SwitcherListRow(assigned: $0, app: catalog.locate($0)) }
        // system.prepareLaunchAnimations(for: present row apps)   // taps only: a swipe plays no animation
        fatalError("not implemented")
    }
}

/// Everything persisted besides the implicit "launched before".
public struct Settings: Codable, Equatable, Sendable {
    public var handMode: HandMode = .right
    public var assignments: [Gesture: AssignedApp] = [:]
    /// The switcher list, in switcher order. One entry per bundle ID.
    public var switcherList: [AssignedApp] = []
    public init() {}
    /// Keys added after the first release are optional, so a record saved by an older build still loads (F22).
    public init(from decoder: any Decoder) throws {
        // let c = try decoder.container(keyedBy: CodingKeys.self)
        // handMode = try c.decode(…); assignments = try c.decode(…)
        // switcherList = try c.decodeIfPresent([AssignedApp].self, forKey: .switcherList) ?? []
        fatalError("not implemented")
    }
}

/// One line of an app menu.
public enum PickerItem: Equatable, Sendable {
    case app(AppEntry, state: AppItemState)
    case divider
    case other
    case unassigned
}

public enum AppItemState: Equatable, Sendable {
    case plain
    /// Checked: the picker's current app.
    case current
    /// Checked and disabled: already in the switcher list (R18).
    case listed
}

extension InstalledApps {
    /// An app picker's menu, as before, with the row's present app `.current`.
    public func pickerMenu(checking app: RowApp) -> [PickerItem] { fatalError("not implemented") }
    /// The Add app… menu: recent, divider, others, divider, Other…; no None; `listed` apps are `.listed` (R18).
    public func addMenu(listed: Set<BundleID>) -> [PickerItem] { fatalError("not implemented") }
}

/// The strings the window quotes verbatim, kept in core so they are tested as values (R15, R24).
public enum Copy {
    /// "● Hold thumb on top-left corner, ◉ tap with 1, 2, 3, 4 or 5 fingers anywhere to launch selected app, or
    /// swipe left or right with 2 fingers to switch apps". `●` and `◉` are the marks the view draws as images.
    public static func gestureHint(for handMode: HandMode) -> String { fatalError("not implemented") }
    public static let accessibilityHint =
        "Clicks and scrolling aren't blocked during gestures. Allow Accessibility access to block them."
}

// Ports: two signatures change, one member is added.
@MainActor public protocol TrackpadHardware: AnyObject {
    var onEvent: (@MainActor (TrackpadEvent) -> Void)? { get set }
    func connected() -> [Trackpad]
    func run(_ trackpads: [Trackpad], handMode: HandMode, blockClicks: Bool)
    /// One haptic pulse of the given strength on that trackpad. No-op if it is gone.
    func playFeedback(_ kind: Feedback, on trackpad: TrackpadID)
}

@MainActor public protocol SystemActions: AnyObject {
    func bringToFront(_ app: AppEntry)
    func registerLoginItem()
    func prepareLaunchAnimations(for apps: [AppEntry])
    func playLaunchAnimation(for app: AppEntry)
    /// The active app right now, parsed into an entry; nil when none, when it has no bundle ID or location, or when
    /// it is Trackpad Launcher itself (which never activates except around the Other… chooser, F2).
    func frontmostApp() -> AppEntry?
}
```

#### LauncherPlatform

```swift
final class DeviceSession: Sendable {
    private let deliver: @Sendable (TrackpadEvent) -> Void
    /// Frame thread. Writes the flag every frame; enqueues at most one event per frame.
    func receive(_ frame: TouchFrame) {
        // let recognition = recognizer.withLock { $0.step(frame) }
        // blocking.withLock { $0 = recognition.blocking }
        // if let event = recognition.event { deliver(TrackpadEvent(event, on: trackpad)) }
        fatalError("not implemented")
    }
}

extension MultitouchTrackpads {
    // In run(): deliver: { [weak self] event in
    //     // The main queue is FIFO by contract (F6: the Task hop was observed in order; this one is documented).
    //     DispatchQueue.main.async { MainActor.assumeIsolated { self?.onEvent?(event) } } }
    public func playFeedback(_ kind: Feedback, on trackpad: TrackpadID) { fatalError("not implemented") }
    /// Chosen by feel: 3 weak, 4 medium, 6 strong (F14). The tick starts at 3; a feel check may move it to 4.
    static func actuation(for kind: Feedback) -> Int32 { fatalError("not implemented") }   // .gesture → 6, .tick → 3
}

extension PointerEvent {
    /// The tap's whole vocabulary: buttons, drags, pressure, and scroll (type 22). No keyboard, no plain move.
    static let tapTypes: [CGEventType] = [/* as today */ .scrollWheel]
    init?(_ type: CGEventType, _ event: CGEvent) {
        // case CGEventType.scrollWheel.rawValue:
        //     guard event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 else { self = .wheel; return }   // F18
        //     self = .scroll(ScrollPhase(momentum: CGMomentumScrollPhase(rawValue: UInt32(event.getIntegerValueField(.scrollWheelEventMomentumPhase))),
        //                                phase: CGScrollPhase(rawValue: UInt32(event.getIntegerValueField(.scrollWheelEventScrollPhase)))))
        fatalError("not implemented")
    }
}

extension PointerVerdict {
    func apply(to event: CGEvent) -> Unmanaged<CGEvent>? {
        // case .passAsStill: zero DeltaAxis1/2, PointDeltaAxis1/2 (integer) and FixedPtDeltaAxis1/2 (double); pass
        fatalError("not implemented")
    }
}

extension WorkspaceActions {
    public func frontmostApp() -> AppEntry? {
        // guard let app = NSWorkspace.shared.frontmostApplication, app != .current,
        //       let id = app.bundleIdentifier, let url = app.bundleURL else { return nil }
        // return AppEntry(bundleID: BundleID(rawValue: id), name: app.localizedName ?? url.deletingPathExtension().lastPathComponent, url: url)
        fatalError("not implemented")
    }
}
```

#### LauncherUI

```swift
/// Owns the switcher window. `render(nil)` hides within 200 ms; `render(switcher)` shows or updates it.
final class SwitcherPresenter {
    private let panel: SwitcherPanel            // warmed up at init, like LaunchOverlay (F32)
    private let icons: SwitcherIcons
    init(launcher: Launcher) { fatalError("not implemented") }   // hosts SwitcherView(launcher:icons:) once
    func render(_ switcher: Switcher?) {
        // nil → fade out 150 ms (no fade under Reduce motion) and orderOut from the completion
        // first non-nil → size to the row (count × 80 + (count − 1) × 20 + padding), centre on the pointer's display
        //                 (NSMouseInRect rule, nearest otherwise), icons.ensure(frontmost: switcher.row[switcher.frontmost]),
        //                 orderFrontRegardless(); later values re-render through observation
        fatalError("not implemented")
    }
}

/// LaunchOverlay.makePanel's configuration plus NSGlassEffectView; never key, never activating, click-through.
final class SwitcherPanel: NSPanel { override var canBecomeKey: Bool { false } }

/// One HStack of 80 pt icons 20 pt apart over a glass highlight 92 pt square at `highlight × 100 pt`, the selected
/// icon scaled 1.1, its name below. The highlight tracks without animation; a spring plays once when `overshootMM`
/// leaves zero; nothing animates under Reduce motion.
struct SwitcherView: View { let launcher: Launcher; let icons: SwitcherIcons }

/// AppIcons at 80 pt: `[URL: Rendered]` stamped by Info.plist date and appearance, rendered off the main actor from
/// `launcher.switcherList`'s present apps (an Observations loop and the window-open pass). `ensure(frontmost:)` draws a
/// missing frontmost icon on the spot from NSRunningApplication.icon (F4 b), else NSWorkspace.icon(forFile:).
final class SwitcherIcons { }

/// The picker's NSPopUpButton in two forms over one coordinator: `.popUp(current: RowApp)` shows the row's app and
/// builds `pickerMenu(checking:)`; `.pullDown(title:)` shows the title and builds the `menu` closure's items, with
/// `.listed` items checked and disabled.
struct AppMenuButton: NSViewRepresentable { }

/// Where an Other… choice goes.
enum PickerTarget { case gesture(Gesture), switcherList }

/// Written by the shell on refit: the tallest the window may be. The view gives the list what is left (R22).
@Observable final class WindowLimits { var maxHeight: CGFloat = .infinity }

extension LauncherPanel {
    /// Sizes to the content's fitting size, which already honours `WindowLimits`; the top edge stays put.
    func fitToContent(centeredOn: CGFloat, topEdge: CGFloat, within screenFrame: NSRect) { fatalError("not implemented") }
}
// MenuBarShell adds: the switcher loop (Usage), an Observations loop over launcher.switcherList feeding SwitcherIcons
// and refit(), and chooseOtherApp(_ target: PickerTarget) routing to setAssignment or addToSwitcher.
```

#### Tests

```swift
extension TouchScript {
    /// Lands `n` fingers at the cursor, 8 mm apart, and leaves them down.
    func land(fingers n: Int, atMM p: (x: Double, y: Double) = (62, 45)) -> TouchScript { fatalError("not implemented") }
    /// Moves every down non-thumb finger by (dx, dy) mm, linearly over `d`.
    func slide(byMM d: (x: Double, y: Double), over: Duration) -> TouchScript { fatalError("not implemented") }
    /// Fingers stay where they are.
    func hold(_ d: Duration) -> TouchScript { fatalError("not implemented") }
    /// Lifts `count` down fingers (nil = all) on this frame.
    func liftFingers(_ count: Int? = nil) -> TouchScript { fatalError("not implemented") }
    /// A physical press from the cursor for `d` (a `.click` press range, as `tap(click:)` makes).
    func press(for d: Duration) -> TouchScript { fatalError("not implemented") }
}

@MainActor final class InMemoryTrackpads: TrackpadHardware {
    struct Pulse: Equatable { let kind: Feedback; let trackpad: TrackpadID }
    private(set) var pulses: [Pulse] = []
    var feedback: [TrackpadID] { pulses.filter { $0.kind == .gesture }.map(\.trackpad) }   // today's assertions keep reading
    var ticks: [TrackpadID] { pulses.filter { $0.kind == .tick }.map(\.trackpad) }
    private(set) var scrollVerdicts: [PointerVerdict] = []
    /// touch(_:on:): per frame as today, then `onEvent?(TrackpadEvent(event, on: id))` for the frame's event.
    /// A scroll event reaching the fake tap now, decided on the flags the last frame left (nil-filter → no verdict).
    @discardableResult func scroll(_ phase: ScrollPhase) -> PointerVerdict? { fatalError("not implemented") }
    @discardableResult func wheel() -> PointerVerdict? { fatalError("not implemented") }
    func inject(_ event: TrackpadEvent) { onEvent?(event) }
}

@MainActor final class RecordingSystemActions: SystemActions {
    /// What `frontmostApp()` answers. nil models "no frontmost app" and "Trackpad Launcher itself".
    var frontmost: AppEntry?
}

enum Fixtures {
    /// A binary plist of the plan 002 `Settings` shape (handMode + assignments 1...4), as today's build saves it.
    static func plan002Record(two: AppEntry) -> Data { fatalError("not implemented") }
}
```

```swift
// SourcePolicyTests: one move, one amended label. ScrollWheel (capital S) stays banned.
static let banned: [Entry] = [ /* … "scrollWheel" removed … */ Entry(token: "ScrollWheel", rule: "R12 scroll read only by the one tap") ]
static let confined: [Confined] = [ /* … */ Confined(token: "scrollWheel", onlyIn: "ClickTap.swift", rule: "R12 scroll read only by the one tap") ]
// PointerEventTests: mask bits [1,2,3,4,6,7,22,25,26,27,34]; `.scrollWheel` leaves ignoresEverythingElse; parses of
// synthetic scroll events per F18 field values (phase, momentum, isContinuous) → .scroll(…) / .wheel; passAsStill
// reads back six zero deltas and the same type and phase.
```

**Existing tests this amends** (`how.md` "Where the planned changes land"): `fiveFingerTapFiresNothing`, `fiveFingersInARollingTapFireNothing` (now fire `.five`; a six-finger variant replaces them), `thumbThenNFingerTapFiresThatGestureOnce` (1...5), `aFirmTapOpensItsAppAndTheWholePressNeverReachesApps` (five apps), `PersistenceTests` (`count: 5`), `draggingFingersIsNotATapAndTheNextTapStillFires` (still passes; renamed to say the drag is a swipe), every `.blocksClicks` read (`.blocking`), `forgettingHeldPressesLetsALostReleasePassAndClearsHolding` (`forgetInFlight`), `RecentAppsTests.menu` projection (`.app(_, state:)`), `ignoresEverythingElse` and the mask test. `twoFingersHeldFiveHundredMillisecondsFireNothing`, `liftingTheThumbEndsBlockingAtOnce` and `aThumbSlidingOutOfTheCornerStopsBlocking` keep passing unchanged.

**Docs.** `docs/domain-model.md`: new *5-finger gesture* (folded into *Gesture*: "one of the five"), *Swipe*, *Switcher*, *Switcher list*, *Frontmost app*, *Light tick*; amended *Gesture*, *Tap* (a two-finger tap that moves past 3 mm sideways is a swipe), *Launcher window* (five rows, the switcher section), *Feedback* (two strengths), *Click blocking* and *Blocking window* (scrolling suppressed under the same rule; both held for the whole of a swipe). `docs/architecture.md`: Privacy "uses it only to block trackpad clicks during gestures" becomes "only to block clicks and suppress trackpad scrolling during gestures"; Concurrency "only completed gestures hop to the main actor" becomes "only recognised events hop to the main actor: fired taps, and a swipe's begin, travel, end and cancel, on the main queue in order". Both are cross-cutting rules, so the architecture file changes.

### Synthesis decision

### Tradeoffs accepted

- We accept a six-state recognizer in which one state holds an optional anchor, in exchange for the type itself saying that a tap needs the thumb and a swipe does not, with no flag beside the state.
- We accept that a swipe-wide block has no 3 s cap and that a stuck swipe (a frame stream ending with fingers down and no empty frame, plan 002's open question) would block clicks and scrolling until the next touch or `run`. In exchange R13 holds for any length of swipe; the exit conditions are three named lines, and `reconcile` clears the switcher.
- We accept ~100 main-actor hops a second while a swipe is in progress, each a pure function and one property write, in exchange for no coalescing state in the adapter and a highlight that follows the fingers frame for frame.
- We accept locating every switcher-list app on the main actor at swipe begin (one Info.plist read each, warm from the last `resolveRows`), in exchange for a row that is correct at the moment it is shown rather than at the last window open.
- We accept that momentum of a scroll which began inside the window and outlived it does not coast. In exchange a flick inside the window never coasts, whichever of the lift frame and the last scroll event arrives first.
- We accept passing suppressed scroll events with zero deltas rather than dropping them, so an app may briefly show overlay scrollers on a stilled `began`. In exchange every app sees a well-formed gesture bracket even when suppression starts or stops partway through.
- We accept that the tap wakes for every scroll event in the session while armed (F19), in exchange for one tap and one filter.
- We accept a second copy of the overlay's twelve-line panel configuration in `LauncherUI`, which cannot import `LauncherPlatform`, in exchange for keeping the switcher where model state is rendered.
- We accept a one-method read on `SystemActions` instead of a port of its own, in exchange for no shallow seam.
- We accept that the frontmost app's icon may be drawn at begin (0.1 ms observed through `NSRunningApplication.icon`, 25 ms once for another running app, F4) rather than prepared, since it cannot be known earlier.
- We accept a `List` for the switcher rows inside the glass card, styled plain, because `onMove` needs it and it is the scrolling region R22 wants.

### Alternatives considered

- **A sibling swipe recognizer on the frame thread, fed the same frames.** Two machines would both own the anchor and the 3 mm rule and would have to agree on "a drifting two-finger tap is a swipe, not a spoiled tap" every frame. Exposes a coordination protocol to the frame path and hides nothing. Rejected: two modules, one decision.
- **The recognizer told the row length and emitting selection indices.** Smaller model code, but the recognizer would need a main-actor value on the frame thread and R6 could only be tested through frames. Rejected on seam placement.
- **The switcher as an effect behind `SystemActions` (`showSwitcher`, `moveHighlight`, `hideSwitcher`), played by `LauncherPlatform` like the launch overlay.** Reuses `LaunchOverlay.makePanel`, but puts three port methods on one visual, hides the switcher's state from the model's tests behind a recording fake, and still needs the pure geometry in core. Rejected on depth; the overlay precedent is for stateless effects.
- **Dropping suppressed scroll events.** One fewer verdict and apps see nothing at all for a fully suppressed gesture, but a gesture stilled after its `began` passed (the late swipe, R13) would leave the app without an `ended`, and momentum could not be cut without a second mechanism. Rejected.
- **Momentum following the verdict of the gesture's `ended` event, or its last moving event.** Simpler to state, but the `ended` and the last `changed` race the lift frame that drops the flag (F8, F18), so a flick inside the window could coast. Rejected for the "any moving event suppressed" rule.
- **Keeping the `Task { @MainActor }` hop on the probe's evidence, or adding a swipe id so reordering is harmless.** The first rests on behaviour the language does not document; the second adds model state for a guarantee the main queue already gives. Rejected for `DispatchQueue.main.async`.
- **A separate `FrontmostApp` port.** One method, two adapters, over the `NSWorkspace` the actions adapter already wraps. Rejected as a hypothetical seam.
- **Scrolling the whole card when the window is too tall.** Simpler layout, but R22 requires the toggle, hint and Quit to stay reachable without scrolling. Rejected.

### Open questions and risks

- When no frontmost app can be read, or it is Trackpad Launcher itself (Other… chooser open), the design shows the list with the selection on its leftmost icon and no extra icon; a lift there opens that app. Is that the wanted behaviour, or should the swipe do nothing until an app is frontmost?
- Does SwiftUI `List`/`onMove` drag reordering work inside the non-activating key `LauncherPanel` while the app is inactive (O9)? If not, which fallback: a custom drag with `draggable`/`dropDestination`, or Move up / Move down in the context menu?
- Is the light tick actuation 3 or 4 (F14 "3 weak, 4 medium")? Only the trackpad can say.
- Does a zero-delta `began` make overlay scrollers flash in Safari or AppKit scroll views, and is that acceptable against the alternative of a dropped bracket? Manual R12/R13 check.
- Does `.glassEffect` render inside a `.screenSaver`-level, non-key, click-through panel, and does the glass highlight read well over the glass panel in light and dark? Manual R10 check; the fallback is a translucent material capsule.
- A momentum tail of a scroll that began inside the window and continued past it is suppressed by the memory rule. Acceptable?
- The frontmost icon path rests on two probe runs of `NSRunningApplication.icon` (F4). If a frontmost app's first draw is slow, the switcher appears up to ~25 ms late once per app per launch. Acceptable, or should `SwitcherIcons` also pre-draw the icons of all running regular apps on start and on `didActivateApplication`?
- A reconcile mid-swipe (hot-plug, wake, preference or trust change) cancels the switcher silently and the remaining fingers do nothing until they lift. Fine?
- `scrollWheel` must not appear in any shipped file but `ClickTap.swift`, comments included; `ScrollWheel` nowhere. The implementation must spell the field names only there and say "scroll" elsewhere.
- Magic Mouse scrolling is unobserved (F18); it is assumed `isContinuous == 1` and suppressed like a trackpad's, as the plan accepts. A Magic Mouse's momentum tail follows the same rule.
- Does the frame stream always end with an empty frame after the last lift? With a swipe-wide block this unanswered plan 002 question now has a visible failure (a switcher that stays). Worth the 001 frame-layout gate's check before S1 ships.
- An old build reading a record with a `5` key in `assignments` or a `switcherList` key fails to decode and loads defaults; downgrade is out of scope, but is it worth a note in the release?

### Next implementation step

Test-first at the recognizer seam: add `TouchScript.land/slide/hold/liftFingers/press`, then grow `GestureRecognizer.State` with `.resting` and `.swiping` and `Recognition` with `event` and `blocking`, driving the R3, R8, R9 and R13 frame scenarios before any of the model, tap or window work.
