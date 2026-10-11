## Design

### Problem

Plan 006 adds a fifth tap gesture, a two-finger swipe that drives an on-screen switcher, a switcher list edited in the launcher window, and scroll suppression in the existing event tap. The fifth tap is one enum case: `Gesture(fingerCount:)` returning nil is the only thing that silences five fingers today (F13). The swipe is the first gesture that lasts, that outlives the thumb, and that produces a stream instead of one event. It breaks three assumptions the recognizer was built on: every non-idle state carries the anchor and dies with it (F9 iii); a two-finger rest ends at 400 ms (F9 i); a movement past 3 mm spoils the tap (F9 ii). It must keep the one per-trackpad flag true for its whole length, however long and whether or not the thumb stays (F9 iv, F21), stream about 100 Hz of travel to the main actor without a reordering hazard (F6, F7), and use no timer and no second clock (F8, F27). Scroll suppression rides on that same flag, read when each event arrives, and needs one piece of memory per scroll gesture because momentum arrives after the fingers have lifted (F18). It also has to pass a source gate that bans the very API it uses: the token moves from banned to confined, never weakened (F17). The frontmost app is a main-actor fact read through `NSWorkspace` (F1, F2); the list's 80 pt icons take up to 220 ms to draw cold (F4) and must be ready before the swipe; a record saved by today's build must still decode (F22, F23); the window must grow with the list and cap at the visible frame (F28, F36). Constraints carried over: one `@MainActor @Observable` `Launcher` owns every decision and the shell renders its state (F24); every port has exactly two adapters and framework types never cross one (F25); recognition stays on the frame thread and the in-memory hardware delivers synchronously (F7); every field has one writer; `LauncherCore` imports Foundation and Observation only.

### Usage (caller's view)

**README excerpt.** The recognizer still owns everything that happens on the frame thread. Per frame it returns `Recognition { event, blocksClicks }`: `event` is a fired tap (one to five fingers) or a swipe phase, `began`, `moved(travelMM:)`, `ended` or `cancelled`; travel is the sideways movement of the two fingers' midpoint since the swipe began, in trackpad millimetres, positive to the right in both hand modes. `blocksClicks` is true for the whole of a swipe. The hardware adapter delivers events to the main actor in frame order and never from a session a later `run` replaced. `Launcher` turns a swipe into one observable value, `switcher: Switcher?`: the row fixed at begin, the home index where the frontmost app sits, and the travel; the selection, the highlight's position and its rubber band are pure functions of that value. Each icon crossed plays a light tick; at the end the model brings the selected app to the front unless the selection is still the frontmost app. The shell draws the switcher from `switcher` and nothing else. Scroll suppression happens in the same tap, on the same flag, with a pure `ScrollFilter` beside `ClickFilter`. The switcher list is a `SwitcherList` value inside `Settings`, edited through three intents. Tests drive all of it synchronously through `World`.

```swift
// TrackpadLauncher app target: the composition root does not change. MenuBarShell owns the switcher's presenter;
// WorkspaceActions answers the one new question (the frontmost app).
let launcher = Launcher(
    hardware: MultitouchTrackpads(), preferences: SystemTrackpadPreferences(),
    access: SystemAccessibilityPermission(), system: WorkspaceActions(), catalog: catalog,
    scanner: SystemAppScanner(catalog: catalog), store: SettingsStore(defaults: .standard))
let shell = MenuBarShell(launcher: launcher)
launcher.start()
```

```swift
// LauncherCoreTests, the high seam. R4, R5, R6, R7 while the fingers are down; R8 at the lift. Synchronous throughout.
@MainActor @Test func liftingOpensTheSelectionWithTheGestureHapticAndNoLaunchAnimation() {
    let world = World(apps: ["Safari", "Mail", "Slack", "Notes"])
    world.launcher.start()
    for name in ["Mail", "Slack", "Notes"] { world.launcher.addToSwitcher(.app(world.app(name))) }
    world.makeFrontmost("Safari")

    var hand = TouchScript(.macBook14).thumb(atMM: (10, 10)).land(fingers: 2)
        .slide(byMM: (3.5, 0))                       // past 3 mm, sideways: the swipe begins, travel 0
        .slide(byMM: (24, 0))                        // two icons right
    world.play(hand)
    #expect(world.launcher.switcher?.row.map(\.name) == ["Safari", "Mail", "Slack", "Notes"])
    #expect(world.launcher.switcher?.selectedApp.name == "Slack")
    #expect(world.hardware.lightTicks.count == 2)

    hand = hand.lift()
    world.play(hand)                                 // delivers only the frames not delivered yet
    #expect(world.system.broughtToFront == [world.app("Slack")])
    #expect(world.hardware.feedback == [Trackpad.macBook14.id])   // the gesture haptic, once
    #expect(world.system.launchAnimations.isEmpty)
    #expect(world.launcher.switcher == nil)
}

// R8 "Staying on the frontmost app": silent, and the window stays as it was.
@MainActor @Test func liftingOnTheFrontmostAppDoesNothingButCloseTheSwitcher() {
    let world = World.switcherWorld()                // Safari frontmost; Mail, Slack, Notes listed; started
    world.launcher.openWindow()
    world.swipe(3.5, 4)                              // 4 mm: nearer Safari than Mail
    #expect(world.system.broughtToFront.isEmpty && world.hardware.pulses.isEmpty)
    #expect(world.launcher.isWindowOpen)
}

// R12, R13, R14 at the high seam: the fake tap decides scroll events on the flags the frames left.
@MainActor @Test func aLateSwipeLetsItsFirstMillimetresScrollThenStillsTheRestAndTheMomentum() {
    let world = World.switcherWorld(accessGranted: true)
    var hand = TouchScript(.macBook14).thumb(atMM: (10, 10)).wait(.seconds(4)).land(fingers: 2).slide(byMM: (2, 0))
    world.play(hand)
    #expect(world.hardware.scroll(.fingers(.began)) == .pass)        // window over, no swipe yet: the page may move
    hand = hand.slide(byMM: (10, 0))
    world.play(hand)
    #expect(world.hardware.scroll(.fingers(.changed)) == .passStill)  // switcher up: nothing moves, the app's bracket stays whole
    hand = hand.press().slide(byMM: (12, 0)).lift()                  // R13: a press during a late swipe is blocked
    world.play(hand)
    #expect(world.hardware.pressVerdicts == [.drop, .drop])
    #expect(world.hardware.scroll(.momentum(.began)) == .passStill)   // R14: nothing coasts
    #expect(world.system.broughtToFront.count == 1)
}

// R23: a record saved by today's build still loads, and the new fields round-trip.
@MainActor @Test func aRecordWithoutASwitcherListLoadsWithAnEmptyOne() {
    let world = World(apps: ["Arc"])
    UserDefaults(suiteName: world.suiteName)!.set(Fixtures.recordSavedByPlan002(two: world.app("Arc")), forKey: "settings")
    let relaunched = world.relaunch()
    #expect(relaunched.app(for: .two) == .present(world.app("Arc")) && relaunched.switcherRows.isEmpty)
}
```

```swift
// The recognizer's own seam: R8, R9 and R13 frame by frame. The thumb lifts, then lands again, mid-swipe.
@Test func theThumbPlaysNoPartOnceASwipeHasBegunAndBlockingHoldsThroughout() {
    let frames = TouchScript(.macBook14).thumb(atMM: (10, 10)).land(fingers: 2)
        .slide(byMM: (5, 0)).liftThumb().slide(byMM: (24, 0)).thumb(atMM: (12, 10)).lift().frames
    var recognizer = GestureRecognizer(handMode: .right, surface: .macBook14)
    let steps = frames.map { recognizer.step($0) }
    let phases = steps.compactMap(\.swipe)
    #expect(phases.first == .began && phases.last == .ended && !phases.contains(.cancelled))
    #expect(steps.drop { $0.swipe != .began }.prefix { $0.swipe != .ended }.allSatisfy(\.blocksClicks))
}

// Pure policy: R6's nearest-icon rule, the hard stops and the rubber band's bound. No adapter involved.
@Test(arguments: [(travel: 5.0, selected: 0), (6, 1), (7, 1), (24, 2), (-30, 0), (60, 3)])
func theSelectionIsTheNearestIconAndNeverPassesAnEnd(travel: Double, selected: Int) {
    var switcher = Switcher(listed: [mail, slack, notes], frontmost: safari, trackpad: Trackpad.macBook14.id)!
    switcher.travelMM = travel
    #expect(switcher.selected == selected)
    #expect(abs(switcher.stretch) < 0.2)             // switcherMaxStretch: never a fifth of an icon past an end
}

// The scroll filter's own seam: R12–R14 as a table.
@Test func aScrollIsSuppressedFromItsFirstBlockedEventThroughItsMomentum() {
    var filter = ScrollFilter()
    #expect(filter.decide(.fingers(.mayBegin), trackpadBlocking: true) == .drop)   // apps never see this gesture
    #expect(filter.decide(.fingers(.changed), trackpadBlocking: false) == .drop)   // the window closed meanwhile: still whole
    #expect(filter.decide(.fingers(.ended), trackpadBlocking: false) == .drop)
    #expect(filter.decide(.momentum(.began), trackpadBlocking: false) == .drop)    // nothing coasts
    #expect(filter.decide(.fingers(.began), trackpadBlocking: false) == .pass)     // the next scroll works at once
    #expect(filter.decide(.fingers(.ended), trackpadBlocking: false) == .pass)
    #expect(filter.decide(.momentum(.changed), trackpadBlocking: true) == .pass)   // coasting from before is not interrupted
    #expect(filter.decide(.wheel, trackpadBlocking: true) == .pass)                // a wheel mouse, never
}
```

```swift
// LauncherUI: the presenter renders the model's value and holds nothing the model holds.
for await shown in Observations({ launcher.switcher }) { self?.render(shown) }

// LauncherUI.LauncherView: the section sits between the gesture rows and the hand toggle; each edit is one intent.
ForEach(launcher.rows) { row in GestureRowView(row: row, launcher: launcher, actions: actions) }
SwitcherSection(launcher: launcher, actions: actions)      // illustration + title, rows, Add app…
HandModeToggle(launcher: launcher).padding(.top, 16)

AppMenuButton(
    .pullDown(title: "Add app…"),
    menu: { launcher.installedApps.addMenu(listing: Set(launcher.switcherRows.map(\.id))) },
    cachedIcon: actions.cachedIcon, icon: actions.icon,
    choose: { $0.map { launcher.addToSwitcher($0) } },
    chooseOther: { actions.chooseOtherApp { launcher.addToSwitcher(.appBundle(at: $0)) } })
```

### Shape

**Data first.**

- *What a frame meant.* `Recognition { event: Event?; blocksClicks: Bool }`, where `Recognition.Event` is `.fired(Gesture)` or `.swipe(SwipePhase)`. A frame yields at most one event, because a tap fires on the frame its last finger is gone and a swipe begins on a frame a finger is still down; one optional sum instead of two optionals whose valid combinations a comment would have to explain (per `type-system-discipline`). `fired` and `swipe` are derived accessors, so every existing `fired(_:)` test reads as before. `blocksClicks` keeps its name: scroll suppression is defined in terms of click blocking (the glossary's *Click blocking*), and the flag is still that one decision.
- *What crosses the hardware port.* `TrackpadEvent` gains `.swipe(SwipeEvent)`, where `SwipeEvent` is a `SwipePhase` plus the `TrackpadID`. The payload is plain values: travel is a `Double` in millimetres, absolute since begin (a coalesced or late `moved` is harmless), no `CGPoint` and no frame time. One core initialiser, `TrackpadEvent(_ event: Recognition.Event, on: TrackpadID)`, is the only mapping and both adapters use it. *Ordering guarantee:* events reach `onEvent` on the main actor in the order each trackpad's frames produced them, and never from a session that a later `run` replaced.
- *What the recognizer remembers.* `State` gains `.resting(Anchor, Pair)`, two fingers still down past 400 ms, no longer a tap but still able to become a swipe, and `.swiping(Swipe)`, where `Swipe` carries the `Pair`, the midpoint where it began, the last travel it reported, and `thumb: Anchor?`. The four tap states keep a required `Anchor`; the thumb is optional only in a swipe, because a swipe outlives it. `Pair` is built as exactly two `Finger`s (id plus landing origin): constructed, not checked, so "exactly two" cannot drift.
- *What the model shows.* `Launcher.switcher: Switcher?` is non-nil exactly while a switcher is on screen. `Switcher` holds the `row`, the `home` index of the frontmost app, `travelMM` and the trackpad. Its row always has at least two icons and always holds the frontmost app at `home`; its failable initialiser is the only constructor, so a switcher that R11 forbids cannot exist. `selected`, `position` (where the highlight rests, in icons) and `stretch` (the bounded rubber band) are derived, never stored. `switcherRows: [SwitcherRow]` is the window's list: each row is the stored `AssignedApp` plus `present: AppEntry?`, nil meaning missing by the rule gesture rows already use (F3).
- *What persists.* `Settings.switcherList: SwitcherList`, a value whose only mutations are `append` (ignores a bundle ID already listed), `remove`, and `move(_:to:)` (clamps the index). It is encoded as a plain array and drops duplicates when decoded. `Settings` gets a hand-written `init(from:)` that reads the new key with `decodeIfPresent` (F22).
- *What the tap sees.* `TapEvent` is `.pointer(PointerEvent)` or `.scroll(ScrollEvent)`: the one parse of a `CGEvent`, inside `ClickTap`. `ScrollEvent` has four cases: `.wheel` (`isContinuous == 0`), `.fingers(Phase)`, `.momentum(Momentum)`, `.unphased`. `ScrollVerdict` is `.pass`, `.drop` or `.passStill` (deltas zeroed in place). `ClickFilter`, `PointerEvent` and `PointerVerdict` do not change.
- *What the window needs.* `PickerItem.app(AppEntry, state: AppItemState)` with `AppItemState` `plain | current | listed` (checked; checked and disabled) replaces the bare `checked:` flag, so checked and disabled are one dimension of one item. `InstalledApps.addMenu(listing:)` is the Add app… menu. `Copy.gestureHint(for:)` and `Copy.accessibilityHint` are the two strings R15 and R24 pin, kept in core so they are tested as values; the view swaps the `●` and `◉` characters for its images. `AppChoice` loses `.unassigned`: `setAssignment(_ choice: AppChoice?, for:)` reads nil as None, matching `assignments`' own "absent = unassigned", and `addToSwitcher(_ choice: AppChoice)` has no case to ignore.
- *Haptics.* `Haptic` is `.gesture` or `.lightTick`; `playFeedback(_:on:)` takes one.

**Load-bearing decisions.**

1. *One recognizer owns the finger session; the swipe is two more states of it (O1; F9, F10, F11).* A tap, a resting pair and a swipe are three readings of the same non-thumb fingers since the last moment none was down. They must agree on `touched`, on the landing origins and on the flag, so a second state machine beside this one would be two owners of one decision (per `model-the-domain`). The rules:
   - *Begin.* The drag check in `.tapping` becomes the swipe's entry. When the farthest-moved finger passes 3 mm, the tap becomes `.swiping` if swipes are on, the tap is a `Pair` (exactly two touched, both down, none joining on this frame) and that finger's displacement is more sideways than vertical (`|dx| > |dy|` in mm); otherwise it is spoiled as today. The drag check runs before the 400 ms check, so a slow pair that moves on the frame it crosses 400 ms still begins (R3 "no time limit").
   - *No time limit (R3).* The 400 ms rule no longer spoils a `Pair`; it moves it to `.resting`. `.resting` never fires a tap, which keeps plan 002 R2 (`twoFingersHeldFiveHundredMillisecondsFireNothing`). It spoils on a delivered click, on either finger lifting, or on any other non-thumb contact landing; it becomes `.swiping` on a sideways first move past 3 mm and is spoiled by a vertical one.
   - *Thumb before fingers (R3).* Holds by construction: a tap only starts from `.armed`; fingers already down when the thumb lands put the recognizer in `.spoiled`, which never begins a swipe.
   - *During a swipe the thumb plays no part (R8, R9).* The top-of-step anchor check covers only the anchored states. `.swiping` keeps its own `thumb: Anchor?`: it becomes nil when it lifts (a reused id counts) or leaves `holds`; while it is nil, a contact landing in `admits` becomes the thumb with `landedAt = frame.time`; a contact already down is never adopted (F10's `.idle` rule). The thumb is handled before the exits, so a thumb landing on the exit frame is the anchor afterwards.
   - *Exits, all named, in this order:* a `.click` press → `cancelled`; either pair finger lifting → `ended` (the first lift wins; R8); a contact landing outside `admits` that is not the thumb → `cancelled` (R9). A `.blocked` press changes nothing. Every exit goes to `thumb.map(.spoiled) ?? .idle`: with a thumb, `.spoiled` recovers only when the thumb is alone; without one, `.idle` never adopts a resting contact and a thumb landing beside resting fingers goes to `.spoiled`. Both are "nothing further until every non-thumb finger has lifted". `run` ends any swipe because it replaces the recognizer; `reconcile()` clears `switcher` for the same reason.
   - *Blocking after the swipe.* Plan 002 R4 alone decides, from the current thumb's `landedAt`: a thumb that re-landed mid-swipe opens its own fresh 3-second window; the original thumb keeps its original one.
2. *The flag stays the only channel (F21; `why.md` Change).* `blocksClicks` is `true` in `.swiping`, whatever the anchor or the clock says, and follows the unchanged R4 expression in every other state. The tap reads it for presses and now for scrolls. Nothing new crosses between threads (per "single source of truth per invariant").
3. *Swipes are recognised only while the switcher list is not empty (R11).* `TrackpadHardware.run` gains `swipes: Bool` and `reconcile()` passes `!settings.switcherList.isEmpty`. With swipes off the recognizer behaves exactly as today plus five fingers: a pair's drag spoils, a resting pair spoils at 400 ms. Without this gate, every user with an empty list (every upgrading user) would find an anchored thumb plus a sideways two-finger scroll suppressed for its whole length, past the 3 s window, while R11 says such a movement "MUST do nothing". The list's emptiness flips only through the three edit intents, which reconcile only on a flip. What the frame thread cannot know, the model ends: when a `began` yields no switcher (the list holds only missing apps or only the frontmost app, or no frontmost app can be read), `swipe(.began)` calls `reconcile()`, the one operation that replaces recognizers. The fresh recognizer sees the thumb and the resting fingers already down on its first frame and goes to `.spoiled` with no window (their landing time is unknown), so clicks and the next scroll work again at once and the remaining fingers do nothing until they lift: R11's "do nothing" holds with no main-to-frame channel, and the block lasts only from the begin frame until main handles the event. A scroll in progress at that moment is not stilled to its end: `run` replaces the tap and its filters, so the gesture's next event reaches a fresh `ScrollFilter` with the flag down and passes, resumed after a brief stop (inside the 3 s window it resumes without the `began` the dropped gesture never showed apps, the headless gesture the disabled-tap recovery already accepts). The empty list keeps the gate rather than this fallback because the fallback restarts the devices and the tap, which every upgrading user would otherwise meet on every anchored sideways scroll.
4. *Travel crosses the port and the selection is decided on main (O2; F11).* The recognizer knows millimetres and nothing about rows. The row depends on the frontmost app and on the catalog, main-actor facts, so the selection belongs to the pure `Switcher` in core: `selected = clamp(home + round(travel / 12 mm))`, rounding half away from zero, so it changes at ±6 mm and then every 12 mm, reversibly; `position = clamp(home + travel / 12 mm)`; `stretch` is the signed excess past an end passed through a saturating function bounded below 0.2 icons. Right is +x on `SurfacePoint` in both hand modes, so R6's direction rule needs no code. The model plays `|selected after − selected before|` light ticks per `moved` (R7 "one per icon crossed", even when one frame crosses two).
5. *Delivery is the main queue, gated by run generation (O3; F6, F7).* `MultitouchTrackpads` hops with `DispatchQueue.main.async { MainActor.assumeIsolated { … } }`, the path libdispatch documents as FIFO and the one `SystemAppScanner` already uses, so events arrive in frame order without resting on the observed but undocumented order of unstructured tasks. Each session's deliver closure captures the `run` generation that made it; on main, an event whose generation is stale is dropped. This closes the existing "a session fetched just before `run` can still deliver" gap for taps too, and for a `began` it is not a nicety: a stale `began` arriving after `reconcile()` cleared `switcher` would open a switcher that no recognizer can ever end. The in-memory adapter keeps calling `onEvent` inline (F7) and does not model the gate.
6. *The frontmost app is read once, at begin, through `SystemActions` (O6; F1, F2, F3).* `frontmostApp() -> URL?` returns the active app's bundle location, or nil when there is none or when it is Trackpad Launcher itself. The model parses it with `catalog.entry(at:)`, the one rule that builds an `AppEntry` from disk, as Other… already does; identity is the bundle ID. Nil or self means no switcher, and the swipe is ended through `reconcile()` as in decision 3: a `Switcher` has no meaning without a home, and starting anywhere else would make a lift without moving open an app. F1 shows a frontmost app always exists in practice; F2 shows self is possible only while the Other… chooser is up. It is a query on the workspace port beside `bringToFront`, its natural pair; a one-method port would be a hypothetical seam.
7. *The row is built fresh at begin, cheaply.* `settings.switcherList.apps.compactMap(catalog.locate)` on the main actor, as `fire` locates fresh at fire time (F3). `AppCatalog.locate` changes to consult `registeredCopies` only when `lastKnownURL` misses (today it runs the LaunchServices query for every app before looking): the common case becomes one Info.plist read per listed app, tens of microseconds warm, and `fire` gets the same saving. Same semantics, since the two lookups were already ordered.
8. *The switcher is model state rendered by `LauncherUI`, with AppKit and Core Animation (O5; F24, F26, F27, F32).* The model owns which apps are shown, which one is selected, when the switcher shows, and every effect; a test reads `launcher.switcher` with no fake. `SwitcherPresenter`, owned by `MenuBarShell`, iterates `Observations({ launcher.switcher })`, which coalesces to the latest value per main-actor turn, a natural back-pressure at ~100 Hz. Its `SwitcherPanel` uses the launch overlay's configuration (F26: borderless, `.nonactivatingPanel`, `ignoresMouseEvents`, `.screenSaver` level, `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`, `hidesOnDeactivate = false`, `animationBehavior = .none`, never key) around an `NSGlassEffectView` in a rounded clip as `LauncherPanel` does, holding a layer-backed host for the 80 pt icon layers, a glass highlight view 92 pt square, and a name label. It is created once at shell init (F32's 27 ms). *On open:* size the panel from the icon count (deterministic: `count × 80 + (count − 1) × 20` plus padding), centre it on the display under `NSEvent.mouseLocation` by the `NSMouseInRect` rule `LaunchFlight` uses (nearest display otherwise), `orderFrontRegardless`. *Per update, with actions disabled:* highlight x = `position × 100 pt`, so it follows the fingers one to one; the selected icon layer at 1.12× with the name below. *When `stretch` changes and is not zero:* add an additive `CASpringAnimation` on the highlight layer's `position.x`, keyed so each one replaces the last, from `stretch × 100 pt` to 0. While the push extends, the highlight tracks the saturated overshoot; when the fingers stop, the last spring settles it on the end icon: "moved only slightly past, and springs back" with no code of ours per display frame. *On close:* opacity to 0 over 150 ms, `orderOut` from the completion unless a new switcher opened meanwhile. *Reduce motion:* no spring (the highlight rests on the end icon), no scale animation, no fade.
9. *Icons are ready before the swipe (F4, F5).* `AppIcons` gains a `side` parameter; the presenter holds an 80 pt instance. It re-renders the list's present apps off the main actor whenever `switcherRows` changes and when `NSApp.effectiveAppearance` changes (KVO, a push; macOS 26 icons have dark variants). A frontmost app outside the list is looked up through `NSRunningApplication.icon`, 0.1 ms in both probe runs. A cache miss for a listed app falls back to drawing on the spot, as `LaunchOverlay.bitmap(for:)` does.
10. *Haptics take a kind (O8; F14).* `.gesture` maps to actuation 6 (unchanged) and `.lightTick` to 3, the "weak" one the existing comment names; tuned by feel. The model plays the gesture haptic only when an app is brought to front.
11. *Scrolls are suppressed per scroll gesture, in the one tap, by a filter of their own (O4; F8, F15–F20).* `ClickTap` adds `.scrollWheel` (22) to its mask and keeps a `Mutex<ScrollFilter>` beside its `Mutex<ClickFilter>`; both read the same `anyTrackpadBlocksClicks()` before taking their own lock, one at a time. The press filter does not change: one policy per filter. *The memory is the treatment of the scroll gesture in progress, momentum included:* a gesture first seen at an opening event (`mayBegin` or `began`) while blocking is `dropped`, so apps never see any of it; a gesture that was passing and meets blocking mid-way becomes `stilled`, its remaining events passed with every delta zeroed (axes 1–3 in lines, fixed point and points), so the app's began-to-ended bracket closes and nothing moves; a `passed` gesture's momentum is never touched (R14 "coasting from before"); the treatment never relaxes inside a gesture, the scroll analogue of plan 002 R5's whole press. This is what survives the race the single flag cannot order: a `changed` or `ended` arriving after the lift frame has cleared the flag is still part of a gesture already decided, so nothing leaks after a swipe (R13 "before, during or after"). *Exemptions and resets:* `.wheel` always passes (R12); `.unphased` is decided per event on the flag; momentum with no known gesture passes; on `tapDisabledBy…` the filter forgets the gesture in progress, as `forgetHeldPresses()` does. Without access there is no tap, so nothing is suppressed (F20). Zeroing is an in-place rewrite like `passAsMove`; nothing is posted.
12. *The gate moves the token; it does not weaken it (F17).* `scrollWheel` leaves `banned` and becomes `Confined(token: "scrollWheel", onlyIn: "ClickTap.swift")`; `ScrollWheel` stays banned with its rule relabelled, which passes the case-sensitive overlap check. Every scroll field name lives in that one file; core comments say "scroll event".
13. *Persistence is tolerant by construction (F22, F23).* A missing `switcherList` key decodes as empty; `handMode` and `assignments` decode as today; the first-launch rule (no record means first launch) and "undecodable loads as defaults" are unchanged; an old record's `assignments` decode into the five-case `Gesture`.
14. *The window reuses the picker machinery (O7, O9; F28–F31, F36).* *The Add menu* is a pure shape: `addMenu(listing:)` returns the recent apps, a divider, the others, a divider, then Other…, with no None; a listed app is `.app(entry, state: .listed)`. `AppPicker` becomes `AppMenuButton` in two forms over one coordinator: `.popUp(current:)` shows the row's app and builds `pickerMenu(checking:)`, `.pullDown(title:)` shows the title and builds the `menu` closure's items in `menuNeedsUpdate` from values in memory with `cachedIcon`; `.listed` items are checked and disabled. *Other…:* `LauncherActions.chooseOtherApp` takes its completion, `(URL) -> Void`, so one chooser serves rows and the list. *Reorder:* a `DragGesture` on each row; rows have a fixed pitch, the dragged row follows the pointer, the drop index is `start + round(dy / pitch)` and the model clamps it. This needs no drag session or pasteboard, so it does not depend on drag-and-drop inside a non-activating panel (O9 unprobed) and the rows stay inside a `ScrollView` that sizes to its content. *Remove:* an `.onHover` trailing button and `.contextMenu { Remove }`. *The height cap (R22):* the list is a `ScrollView` with `.layoutPriority(-1)`; the root keeps `fixedSize` horizontally only; `fitToContent` caps the panel's height at the visible frame minus 16 pt, and SwiftUI's own layout takes the whole deficit out of the list alone (F36, probed). *Refits:* `MenuBarShell` also refits when `switcherRows.count` changes.

**Depth.**

| Module | Public surface | What it hides |
|---|---|---|
| `GestureRecognizer` | `init(handMode:surface:swipes:)`, `step` → `Recognition` (2 stored fields) | Taps of 1–5 fingers; the swipe's entry (pair, sideways, 3 mm, no time limit); vertical inertness; thumb independence and re-anchoring; three named exits; travel in mm; the swipe-wide block |
| `Switcher` | failable `init`, `travelMM`; `row`, `home`, `selected`, `selectedApp`, `selectsFrontmost`, `position`, `stretch` | R4's row rule, R5's start, R6's nearest icon, 12 mm, hard stops and the bounded rubber band, R11's "nothing to switch to" |
| `SwitcherList` | `apps`, `isEmpty`, `append`, `remove`, `move`, `Codable` | No duplicates ever, clamped moves, array coding with dedupe on decode |
| `ScrollFilter` | `init`, `decide`, `forgetGesture` | Per-gesture treatment (dropped, stilled, passed), momentum inheritance, the wheel exemption, unknown coasting, the never-relax rule |
| `TrackpadHardware` | `run` gains `swipes`; `playFeedback` gains a kind | Plus: the FIFO hop, the stale-session gate, scroll parsing, zeroing, the actuation table |
| `SystemActions` | gains `frontmostApp()` | `NSWorkspace`, `NSRunningApplication`, excluding itself |
| `Launcher` | gains `switcher`, `switcherRows`, 3 intents | Plus: row building at begin, R11, ticks, end effects, closing the switcher on reconcile, reconciling when the list's emptiness flips |
| `InstalledApps` | gains `addMenu(listing:)` | The second menu shape with its disabled state |

The public surface grows by: one sum type on `step`'s result; one case on `TrackpadEvent` and one initialiser; one argument on `run`; one argument on `playFeedback`; one query on `SystemActions`; two observed properties and three intents on `Launcher`; one method on `InstalledApps`; the `Copy` values. A frame reaches a highlight on screen through `GestureRecognizer`, `MultitouchTrackpads`, `Launcher`/`Switcher`, `SwitcherPresenter`: three modules. `switcher` has one writer.

**Concurrency** (one writer per field).

- *Frame thread:* the recognizer as today. Each session's `blocking` flag is written before `deliver`, so the swipe-wide block is in effect before main knows a swipe began. ~100 Hz while a swipe moves: input-driven work, not a per-display-frame loop (F27).
- *Tap thread:* the `ClickFilter` and `ScrollFilter` mutexes, each written only there, taken one at a time after the flag read; scroll events add ~100–250 Hz of wake-ups while anyone scrolls with the tap armed (F19, accepted).
- *Main:* `Launcher.switcher` is written only by `swipe(_:)` and by `reconcile()`. `MultitouchTrackpads.runs` is written only by `run`. Every field the presenter's layers touch is main-only; the 80 pt `AppIcons` merges off-main renders on main as the 16 pt one does.

#### Module map

```
LauncherCore     (Foundation, Observation)   Gesture (+ five) · Recognition (+ Event, SwipePhase) · SwipeEvent ·
                                              GestureRecognizer (+ resting, swiping, Pair, Swipe, swipes flag) ·
                                              GestureRules (+ switcherStepMM, switcherMaxStretch) ·
                                              Switcher · SwitcherList · SwitcherRow · Settings (+ switcherList, tolerant init) ·
                                              AppChoice (no .unassigned) · PickerItem (state: AppItemState) · InstalledApps.addMenu ·
                                              AppCatalog.locate (lazy registered copies) · Copy ·
                                              ScrollEvent · ScrollVerdict · ScrollFilter · ClickFilter (unchanged) ·
                                              ports: TrackpadEvent (+ swipe, init), Haptic, TrackpadHardware (run + swipes,
                                              playFeedback(kind)), SystemActions (+ frontmostApp) · Launcher (+ switcher,
                                              switcherRows, list intents, swipe handling, reconcile cancel)
LauncherPlatform                              MultitouchTrackpads (main-queue hop, run generation, actuation per Haptic) ·
                                              DeviceSession (delivers TrackpadEvent) · ClickTap (TapEvent, scroll in the mask,
                                              ScrollFilter, ScrollEvent parsing, ScrollVerdict.apply zeroing) · WorkspaceActions (+ frontmostApp)
LauncherUI                                    SwitcherPresenter + SwitcherPanel (AppKit/CA, glass) · AppIcons (side) · SwitcherSection ·
                                              SwitcherListRow · AppMenuButton (popUp + pullDown) · LauncherView (5 rows, section,
                                              Copy) · LauncherPanel.fitToContent (height cap) · MenuBarShell (presenter, refit on
                                              list count, appearance KVO) · LauncherActions.chooseOtherApp(then:)
TrackpadLauncher app target                   unchanged · assets/gesture-5.svg, assets/swipe.svg (drawn during implementation, O10)
Tests                                         LauncherCoreTests: recognizer, Switcher, SwitcherList, ScrollFilter, addMenu, Copy,
                                              World seam, SourcePolicyTests; InMemoryTrackpads (swipe delivery, pulses, scroll),
                                              RecordingSystemActions (frontmost), TouchScript (land, slide, lift, press, thumb
                                              re-land), World (play, swipe, makeFrontmost, switcherWorld), Fixtures
                                              (recordSavedByPlan002) · LauncherPlatformTests: TapEvent parse, mask, zeroing
```

#### LauncherCore: recognition

```swift
/// One of the five tap gestures, named by finger count.
public enum Gesture: Int, CaseIterable, Codable, CodingKeyRepresentable, Sendable {
    case one = 1, two, three, four, five
    /// nil outside 1...5: a six-finger tap is not a gesture (R1).
    public init?(fingerCount: Int) { self.init(rawValue: fingerCount) }
    public var fingerCount: Int { rawValue }
}

/// A swipe's progress as the frame thread reports it.
public enum SwipePhase: Equatable, Sendable {
    /// Two fingers under an anchored thumb moved sideways past 3 mm. Travel is 0 here.
    case began
    /// Sideways movement of the two fingers' midpoint since `began`, in trackpad millimetres, positive to the right in
    /// both hand modes. Absolute, not a delta. Sent only when it changed.
    case moved(travelMM: Double)
    /// The first of the two fingers lifted: open the selection (R8).
    case ended
    /// A finger landed outside the anchor corner, or a press reached apps: open nothing (R9).
    case cancelled
}

/// A swipe phase on a specific trackpad (its haptics play there; its switcher belongs to it).
public struct SwipeEvent: Equatable, Sendable {
    public let phase: SwipePhase
    public let trackpad: TrackpadID
}

/// What one frame meant on one trackpad.
public struct Recognition: Equatable, Sendable {
    /// What one frame produced, if anything. A frame never both fires a tap and moves a swipe.
    public enum Event: Equatable, Sendable {
        case fired(Gesture)
        case swipe(SwipePhase)
    }
    public let event: Event?
    /// This trackpad's half of click blocking, which also suppresses trackpad scrolling (R12): true for the whole of
    /// a swipe (R13); otherwise a thumb this recognizer saw land less than 3 s ago is still anchored and another
    /// contact is down. Whether anything is really blocked also needs the filters armed.
    public let blocksClicks: Bool

    public var fired: Gesture? { if case .fired(let gesture)? = event { gesture } else { nil } }
    public var swipe: SwipePhase? { if case .swipe(let phase)? = event { phase } else { nil } }
}

package enum GestureRules {
    // … unchanged …
    /// Icons are this far apart in finger travel; the selection is the nearest icon (R6).
    static let switcherStepMM = 12.0
    /// The most the highlight's rubber band shows past an end, in icons (R6 "only slightly past it").
    static let switcherMaxStretch = 0.2
}

public struct GestureRecognizer: Sendable {
    /// `swipes`: false while the switcher list is empty; a pair's drag then spoils like any drag (R11).
    public init(handMode: HandMode, surface: SurfaceSize, swipes: Bool = true) { fatalError("not implemented") }

    public mutating func step(_ frame: TouchFrame) -> Recognition {
        // Per-frame sets exactly as today: isFirstFrame, before, down, reused, lifted, landed; defer previouslyDown.
        //
        // 1. Anchor check as today, but only for the anchored states (state.anchor is nil for .idle and .swiping):
        //      anchor lifted (reused counts) or outside holds → .idle
        //
        // 2. switch state
        //    .idle, .armed, .spoiled: unchanged.
        //
        //    .tapping(anchor, var tap):
        //      drop lifted ids from tap.down; joining = landed minus the anchor
        //      pair = swipes ? Pair(tap, joining: joining) : nil
        //      if frame.press == .click                                   → .spoiled(anchor)
        //      else if let move = Self.drag(of: tap.fingers, in: down)    // the farthest finger, if past 3 mm
        //          pair != nil && move.isSideways                         → begin(pair, anchor)
        //          otherwise                                              → .spoiled(anchor)
        //      else if frame.time - tap.start > maxTapDuration            → pair.map { .resting(anchor, $0) } ?? .spoiled(anchor)
        //      else if tap.down.isEmpty                                   → event = Gesture(fingerCount: tap.touched.count).map(.fired);
        //                                                                   re-arm or start the next Tap, as today
        //      else join `joining`, as today
        //
        //    .resting(anchor, pair):                                      // fires nothing, ever
        //      if frame.press == .click, a pair finger lifted, or any non-anchor contact landed → .spoiled(anchor)
        //      else if let move = Self.drag(of: pair.fingers, in: down)   → move.isSideways ? begin(pair, anchor) : .spoiled(anchor)
        //
        //    .swiping(var swipe):                                         // the thumb plays no part
        //      if let thumb = swipe.thumb, lifted.contains(thumb.id) || !(down[thumb.id].map { corner.holds($0.position) } ?? false)
        //          swipe.thumb = nil
        //      if swipe.thumb == nil, let thumb = landed.first(where: { corner.admits($0.position) })
        //          swipe.thumb = Anchor(id: thumb.id, landedAt: frame.time)   // R9 "Thumb lands again"; already-down contacts never
        //      after = swipe.thumb.map(State.spoiled) ?? .idle            // "nothing further until every non-thumb finger has lifted"
        //      if frame.press == .click                                   → state = after; event = .swipe(.cancelled)   (.blocked: nothing)
        //      else if swipe.pair.contains(any of lifted)                 → state = after; event = .swipe(.ended)       (the first lift wins)
        //      else if landed.contains { $0.id != swipe.thumb?.id && !corner.admits($0.position) }
        //                                                                 → state = after; event = .swipe(.cancelled)   (a finger outside the corner)
        //      else travel = (swipe.pair.midX(in: down) − swipe.startMidX) × surface.widthMM
        //           if travel != swipe.travelMM { swipe.travelMM = travel; event = .swipe(.moved(travelMM: travel)) }
        //           state = .swiping(swipe)
        //
        //    begin(pair, anchor): state = .swiping(Swipe(pair: pair, startMidX: pair.midX(in: down), thumb: anchor)); event = .swipe(.began)
        //
        // 3. blocksClicks = state is .swiping ? true : today's expression over state.anchor (unchanged)
        fatalError("not implemented")
    }

    private struct Finger: Sendable {
        let id: TouchID
        let origin: SurfacePoint
    }

    /// Exactly two fingers: the only shape a swipe has.
    private struct Pair: Sendable {
        let first: Finger
        let second: Finger
        /// The tap as a pair: exactly two fingers touched since the last moment none was down, both still down,
        /// and none joins on this frame.
        init?(_ tap: Tap, joining: [Touch]) { fatalError("not implemented") }
        var fingers: [Finger] { [first, second] }
        func contains(_ id: TouchID) -> Bool { first.id == id || second.id == id }
        /// Normalised x of the midpoint of the two fingers' current positions.
        func midX(in down: [TouchID: Touch]) -> Double { fatalError("not implemented") }
    }

    private struct Swipe: Sendable {
        let pair: Pair
        let startMidX: Double
        var travelMM: Double = 0
        /// The thumb as it is now. Only what happens after the swipe reads it.
        var thumb: Anchor?
    }

    /// A finger's displacement in millimetres from its landing point.
    private struct Move: Sendable {
        let dxMM: Double
        let dyMM: Double
        /// More sideways than up or down (R3).
        var isSideways: Bool { abs(dxMM) > abs(dyMM) }
    }

    /// The farthest-moved finger's displacement, when it is more than `dragThresholdMM`. Deterministic: the maximum.
    private static func drag(of fingers: [Finger], in down: [TouchID: Touch], on surface: SurfaceSize) -> Move? {
        fatalError("not implemented")
    }

    private enum State: Sendable {
        case idle
        case armed(Anchor)
        case tapping(Anchor, Tap)
        /// Two fingers still down past the tap limit: no longer a tap, still able to become a swipe (R3: no time limit).
        case resting(Anchor, Pair)
        case spoiled(Anchor)
        case swiping(Swipe)

        /// The anchor the top-of-step check maintains. A swipe keeps its own optional thumb instead.
        var anchor: Anchor? { fatalError("not implemented") }
    }
    // Anchor, Tap (+ `var fingers: [Finger]`), corner, surface, state, previouslyDown as today; `private let swipes: Bool`.
}
```

#### LauncherCore: the switcher, the list, settings, menus, copy

```swift
/// The switcher during one swipe. The row is fixed when the swipe begins; everything else follows the travel.
public struct Switcher: Equatable, Sendable {
    /// Left to right: the frontmost app first when the list lacks it, then the list's present apps in list order.
    /// Always at least two icons.
    public let row: [AppEntry]
    /// The frontmost app's index: the selection at travel 0 (R5).
    public let home: Int
    /// Sideways midpoint travel since the swipe began, in trackpad millimetres (R6). Written only by `Launcher` (and tests).
    public package(set) var travelMM: Double = 0
    public let trackpad: TrackpadID

    /// nil when the row would hold nothing besides the frontmost app (R11). `listed`: the list's present apps, in order.
    package init?(listed: [AppEntry], frontmost: AppEntry, trackpad: TrackpadID) {
        // row = listed holds frontmost.bundleID ? listed : [frontmost] + listed
        // home = index of frontmost.bundleID in row; guard row.count >= 2
        fatalError("not implemented")
    }

    /// The nearest icon, never past an end: home + round(travel / 12 mm), half away from zero, clamped. Changes at
    /// ±6 mm, then every 12 mm, in either direction.
    public var selected: Int { fatalError("not implemented") }
    public var selectedApp: AppEntry { row[selected] }
    /// Lifting here is a silent no-op (R8).
    public var selectsFrontmost: Bool { selected == home }
    /// Where the highlight rests, in icons: home + travel / 12 mm, clamped to the row. Between two icons it sits
    /// between them in proportion (R6).
    public var position: Double { fatalError("not implemented") }
    /// The rubber band past an end, in icons, signed, bounded below `switcherMaxStretch`:
    /// sign(excess) × max × (1 − 1 / (1 + |excess| / max)), where excess = unclamped position − position. 0 inside the row.
    public var stretch: Double { fatalError("not implemented") }
}

/// The user-ordered apps the switcher shows. No bundle ID appears twice.
public struct SwitcherList: Codable, Equatable, Sendable {
    public private(set) var apps: [AssignedApp] = []
    public var isEmpty: Bool { apps.isEmpty }
    public init() {}
    /// Appends at the end; an app already listed (same bundle ID) leaves the list unchanged (R18).
    package mutating func append(_ app: AssignedApp) { fatalError("not implemented") }
    package mutating func remove(_ id: BundleID) { fatalError("not implemented") }
    /// Moves the app to `index`, clamped into the list; an app not listed leaves it unchanged (R20).
    package mutating func move(_ id: BundleID, to index: Int) { fatalError("not implemented") }
    /// A plain array; a duplicate bundle ID keeps its first copy.
    public init(from decoder: any Decoder) throws { fatalError("not implemented") }
    public func encode(to encoder: any Encoder) throws { fatalError("not implemented") }
}

/// A switcher list row as the launcher window shows it.
public struct SwitcherRow: Identifiable, Equatable, Sendable {
    public let assigned: AssignedApp
    /// nil: missing, shown greyed as "<assigned.name>  not found"; recovers when a copy exists again (R17).
    public let present: AppEntry?
    public var id: BundleID { assigned.bundleID }
}

public struct Settings: Codable, Equatable, Sendable {
    public var handMode: HandMode = .right
    public var assignments: [Gesture: AssignedApp] = [:]
    public var switcherList = SwitcherList()
    public init() {}
    /// Keys from the first release decode as before; a key added later decodes as absent → default, so a record
    /// saved by an older build keeps its assignments (F22). Encoding stays synthesized.
    public init(from decoder: any Decoder) throws {
        // handMode = decode; assignments = decode; switcherList = decodeIfPresent ?? SwitcherList()
        fatalError("not implemented")
    }
}

/// An app the user chose: from a menu, or any bundle on disk through Other…. None is `nil` at `setAssignment`.
public enum AppChoice: Sendable {
    case app(AppEntry)
    /// Parsed by `AppCatalog.entry(at:)`, ignored if not an app with a bundle ID.
    case appBundle(at: URL)
}

/// One line of an app menu.
public enum PickerItem: Equatable, Sendable {
    case app(AppEntry, state: AppItemState)
    case divider
    /// Other…
    case other
    /// None.
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
    /// An app picker's menu, as before; the row's present app is `.current`.
    public func pickerMenu(checking app: RowApp) -> [PickerItem] { fatalError("not implemented") }
    /// The switcher's Add app… menu: recent, divider, others, divider, Other…; no None. Listed apps are `.listed`.
    public func addMenu(listing listed: Set<BundleID>) -> [PickerItem] { fatalError("not implemented") }
}

extension AppCatalog {
    /// As today, but `registeredCopies` is consulted only when `lastKnownURL` misses: one Info.plist read in the common case.
    public func locate(_ app: AssignedApp) -> AppEntry? { fatalError("not implemented") }
}

/// The strings the window quotes verbatim, kept in core so they are tested as values (R15, R24).
public enum Copy {
    /// "● Hold thumb on top-left corner, ◉ tap with 1, 2, 3, 4 or 5 fingers anywhere to launch selected app, or
    /// swipe left or right with 2 fingers to switch apps"; "top-right" in left-hand mode. `●` and `◉` are the two
    /// marks the view draws as its template images.
    public static func gestureHint(for handMode: HandMode) -> String { fatalError("not implemented") }
    public static let accessibilityHint =
        "Clicks and scrolling aren't blocked during gestures. Allow Accessibility access to block them."
}
```

#### LauncherCore: scroll suppression

```swift
/// A scroll event as suppression needs it. Parsed in the tap; no event-system type crosses.
public enum ScrollEvent: Equatable, Sendable {
    /// Line-based, no phases: a scroll wheel. Never suppressed (R12).
    case wheel
    /// Fingers on a surface: a trackpad or a Magic Mouse, which the system reports alike.
    case fingers(Phase)
    /// Coasting after the fingers lifted.
    case momentum(Momentum)
    /// Continuous without phases: decided alone, on the flag.
    case unphased

    public enum Phase: Equatable, Sendable { case mayBegin, began, changed, ended, cancelled }
    public enum Momentum: Equatable, Sendable { case began, changed, ended }
}

public enum ScrollVerdict: Equatable, Sendable {
    case pass
    case drop
    /// Delivered with every delta zeroed: the app's gesture ends cleanly and nothing moves.
    case passStill
}

/// Scroll suppression for one event stream, as a pure state machine. Like `ClickFilter`, it knows no clock and no
/// device; `trackpadBlocking` is the same merged flag, read when the event arrives. One per tap, fed in order.
public struct ScrollFilter: Sendable {
    public init() {}

    public mutating func decide(_ event: ScrollEvent, trackpadBlocking: Bool) -> ScrollVerdict {
        // .wheel → .pass;  .unphased → blocking ? .drop : .pass
        // .fingers(phase):
        //   stage .touching(t)          → t' = (t == .passed && blocking) ? .stilled : t      (never relaxes)
        //   stage nil or .coasting      → a new gesture: t' = !blocking ? .passed
        //                                                : phase opens (mayBegin, began) ? .dropped : .stilled
        //                                 (a gesture first seen mid-way was already seen by apps: only stilling keeps it whole)
        //   stage = phase closes (ended, cancelled) ? .coasting(t') : .touching(t')
        //   return t'.verdict
        // .momentum(m):
        //   stage .coasting(t) or .touching(t) → t.verdict, and stage = nil after .ended   (momentum inherits; never escalates: R14)
        //   stage nil                          → .pass                                      (unknown coasting is never interrupted)
        fatalError("not implemented")
    }

    /// The system disabled the tap; events may have passed unseen. Forget the gesture in progress (under-blocking).
    public mutating func forgetGesture() { stage = nil }

    private enum Treatment: Sendable { case passed, dropped, stilled }   // .verdict: .pass, .drop, .passStill
    private enum Stage: Sendable { case touching(Treatment), coasting(Treatment) }
    private var stage: Stage?
}
```

#### LauncherCore: ports and the model

```swift
public enum TrackpadEvent: Sendable {
    case gesture(GestureEvent)
    case swipe(SwipeEvent)
    /// Attached, detached, or the Mac woke.
    case trackpadsChanged
    /// The one mapping from what a recognizer said to what the port carries. Both hardware adapters use it.
    public init(_ event: Recognition.Event, on trackpad: TrackpadID) { fatalError("not implemented") }
}

/// The two haptics: the gesture haptic when an app comes to the front, and the lighter tick per selection change.
public enum Haptic: Sendable { case gesture, lightTick }

@MainActor public protocol TrackpadHardware: AnyObject {
    /// On the main actor, in the order each trackpad's frames produced them. Never for a session a later `run` replaced.
    var onEvent: (@MainActor (TrackpadEvent) -> Void)? { get set }
    func connected() -> [Trackpad]
    /// As today, plus `swipes`: whether each fresh recognizer recognises swipes. Ends any swipe in progress.
    func run(_ trackpads: [Trackpad], handMode: HandMode, blockClicks: Bool, swipes: Bool)
    /// One pulse of that kind on that trackpad. No-op if it is gone.
    func playFeedback(_ haptic: Haptic, on trackpad: TrackpadID)
}

/// The workspace: effects the core decides and macOS performs, and the one fact the core reads back from it.
@MainActor public protocol SystemActions: AnyObject {
    // bringToFront, registerLoginItem, prepareLaunchAnimations, playLaunchAnimation: unchanged
    /// The active app's bundle location, read now. nil when there is none, it has no bundle, or it is Trackpad
    /// Launcher itself (which never activates except around the Other… chooser, F2).
    func frontmostApp() -> URL?
}

@MainActor @Observable public final class Launcher {
    public private(set) var rows: [GestureRow] = []                 // five, by Gesture.allCases
    /// The switcher list as the window shows it, in switcher order. Resolved with `rows`.
    public private(set) var switcherRows: [SwitcherRow] = []
    /// Non-nil exactly while a swipe shows the switcher. Written only by `swipe(_:)` and `reconcile()`.
    public private(set) var switcher: Switcher?
    // … everything else as today …

    /// App picker. nil = None.
    public func setAssignment(_ choice: AppChoice?, for gesture: Gesture) { fatalError("not implemented") }
    /// Add app… and its Other…: appends; an app already listed is left where it is (R18).
    public func addToSwitcher(_ choice: AppChoice) { fatalError("not implemented") }
    public func removeFromSwitcher(_ app: BundleID) { fatalError("not implemented") }
    /// Drag to reorder: `index` is where the row lands, clamped into the list (R20).
    public func moveInSwitcher(_ app: BundleID, to index: Int) { fatalError("not implemented") }

    // init: rows = makeRows(); switcherRows = makeSwitcherRows() — no effects, as today, so a relaunched model reads both.
    // start(): onEvent gains `case .swipe(let event): swipe(event)`.

    /// The one place a swipe becomes effects.
    private func swipe(_ event: SwipeEvent) {
        // .began:     guard switcher == nil, activity.isActive
        //             frontmost = system.frontmostApp().flatMap(catalog.entry(at:))                      — nil or self: no home (O6)
        //             listed = settings.switcherList.apps.compactMap(catalog.locate)                    — missing apps left out (R4)
        //             switcher = frontmost.flatMap { Switcher(listed: listed, frontmost: $0, trackpad: event.trackpad) }   — nil: R11
        //             if switcher == nil { reconcile() }   — nothing to show: end the swipe from main, so nothing stays blocked (R11);
        //                                                    the same re-entry as `.trackpadsChanged` → reconcile() inside onEvent today
        // .moved(t):  guard var open = switcher, open.trackpad == event.trackpad
        //             before = open.selected; open.travelMM = t; switcher = open
        //             |open.selected − before| × hardware.playFeedback(.lightTick, on: event.trackpad)   (R7)
        // .ended:     guard let open = switcher, open.trackpad == event.trackpad; switcher = nil
        //             guard !open.selectsFrontmost                                                        (R8: silent)
        //             hardware.playFeedback(.gesture, on:); system.bringToFront(open.selectedApp); window = .closed
        //             — no launch animation
        // .cancelled: if switcher?.trackpad == event.trackpad { switcher = nil }                        (R9)
        fatalError("not implemented")
    }

    // reconcile(): switcher = nil; … hardware.run(active ? connected : [], handMode:, blockClicks: active && granted,
    //                                             swipes: !settings.switcherList.isEmpty)
    // fire(_:): playFeedback(.gesture, on:) — otherwise unchanged
    // resolveRows(): also switcherRows = settings.switcherList.apps.map { SwitcherRow(assigned: $0, present: catalog.locate($0)) };
    //                prepareLaunchAnimations still for the rows' present apps only (a swipe plays no animation)
    // list intents: edit settings.switcherList, save, resolveRows(), and reconcile() only when isEmpty flipped
}
```

#### LauncherPlatform

```swift
// MultitouchTrackpads
private var runs = 0                                   // main only; run bumps it first
// in run, per session:
let generation = runs
deliver: { [weak self] event in
    DispatchQueue.main.async {                          // documented FIFO from this frame thread
        MainActor.assumeIsolated {
            guard let self, self.runs == generation else { return }   // a later run replaced this session
            self.onEvent?(event)
        }
    }
}
public func playFeedback(_ haptic: Haptic, on trackpad: TrackpadID) { fatalError("not implemented") }
/// Chosen by feel: 3 weak, 4 medium, 6 strong (F14). The tick starts at 3; the feel check may move it to 4.
static func actuation(for haptic: Haptic) -> Int32 { fatalError("not implemented") }   // .gesture → 6, .lightTick → 3

// DeviceSession: `deliver: @Sendable (TrackpadEvent) -> Void`; receive writes `blocking` first, then
//   `if let event = recognition.event { deliver(TrackpadEvent(event, on: trackpad)) }`

// ClickTap.swift (the only file that may say scrollWheel)
/// Everything the tap is told about, parsed. `PointerEvent` keeps its vocabulary: a press and what belongs to it.
enum TapEvent: Equatable {
    case pointer(PointerEvent)
    case scroll(ScrollEvent)
    /// Buttons, drags, pressure (34) and scroll (22). A test parses one synthetic event of every listed type.
    static let tapTypes: [CGEventType] = [/* today's ten */ .scrollWheel]
    static var tapMask: CGEventMask { fatalError("not implemented") }
    init?(_ type: CGEventType, _ event: CGEvent) { fatalError("not implemented") }
}
extension ScrollEvent {
    /// isContinuous 0 → .wheel; scrollPhase ≠ 0 → .fingers; momentumPhase ≠ 0 → .momentum; else .unphased (F18).
    init(_ event: CGEvent) { fatalError("not implemented") }
}
extension ScrollVerdict {
    /// `.passStill` zeroes DeltaAxis1–3, FixedPtDeltaAxis1–3 and PointDeltaAxis1–3 in place and passes the event.
    func apply(to event: CGEvent) -> Unmanaged<CGEvent>? { fatalError("not implemented") }
}
// handle: tapDisabled → forgetHeldPresses() and forgetGesture(), re-enable; else parse TapEvent (nil → pass);
//   blocking = anyTrackpadBlocksClicks(); then the matching filter under its own lock, and that verdict's apply.

// WorkspaceActions
public func frontmostApp() -> URL? {
    // NSWorkspace.shared.frontmostApplication, unless its pid is ours; its bundleURL
    fatalError("not implemented")
}
```

#### LauncherUI

```swift
/// Renders `launcher.switcher` and holds nothing the model holds. Owned by MenuBarShell.
final class SwitcherPresenter {
    init(launcher: Launcher) {
        // panel = SwitcherPanel() — created now, so a swipe never pays the first window's cost (F32)
        // icons = AppIcons(side: 80)
        // Observations({ launcher.switcher }) → render(_:)
        // Observations({ launcher.switcherRows }) and NSApp effectiveAppearance KVO → icons.renderOffMainActor(present apps)
        fatalError("not implemented")
    }

    /// nil → hide: opacity to 0 over 150 ms, orderOut from the completion unless shown again (Reduce motion: at once).
    /// Newly non-nil → lay out the row's icon layers (80 pt, 20 pt apart), size from the icon count, centre on the
    /// pointer's display (NSMouseInRect rule, nearest otherwise), orderFrontRegardless.
    /// Always, with actions disabled → highlight x = position × 100 pt; selected icon 1.12× with its name below;
    /// stretch changed and ≠ 0 → additive CASpringAnimation on the highlight's position.x from stretch × 100 pt to 0,
    /// keyed so it replaces the last (none under Reduce motion).
    private func render(_ switcher: Switcher?) { fatalError("not implemented") }
}

/// The launch overlay's configuration (F26) around an NSGlassEffectView in a rounded clip (as LauncherPanel), holding
/// 80 pt icon layers 20 pt apart, a glass highlight view 92 pt square, and the name label. Never key, never
/// activating, click-through.
final class SwitcherPanel: NSPanel { override var canBecomeKey: Bool { false } }

// AppIcons(side: CGFloat = 16): today's cache, parameterised; the presenter holds an 80 pt one. Its lookup for the
//   switcher: cached → the running app's icon (the frontmost, F4) → drawn on the spot.
// SwitcherSection: illustration "swipe" mirrored in left hand, "Swipe to switch apps", the rows in a ScrollView with
//   layoutPriority(-1), AppMenuButton(.pullDown(title: "Add app…")) (R16, R21).
// SwitcherListRow: 16 pt icon + name, or greyed "<name>  not found" with the dashed-app symbol; .onHover → trailing
//   remove button; .contextMenu { Remove }; DragGesture → the row follows the pointer, on end
//   moveInSwitcher(id, to: start + round(dy / pitch)) (R17, R19, R20).
// AppMenuButton: the picker's NSPopUpButton in two forms over one coordinator. `.popUp(current: RowApp)` shows the
//   row's app and builds pickerMenu(checking:); `.pullDown(title:)` shows the title and builds the `menu` closure's
//   items. `.app(_, state:)`: .current selected, .listed checked and disabled. choose: (AppChoice?) -> Void, nil = None.
// LauncherActions.chooseOtherApp: (@escaping (URL) -> Void) -> Void — close, activate, NSOpenPanel, completion, reopen.
// LauncherView: rows (five), SwitcherSection, HandModeToggle, Divider, hint from Copy.gestureHint(for:), notices
//   (Copy.accessibilityHint), Quit; root fixedSize(horizontal: true, vertical: false) (R22, F36).
// LauncherPanel.fitToContent: height = min(fittingSize.height, visible.height − 16); y from the top edge (R22).
// MenuBarShell: owns SwitcherPresenter; refit also on switcherRows.count; iconTargets include the list's present apps.
```

#### Tests: fixtures and the gate

```swift
extension TouchScript {
    /// Lands `n` fingers 8 mm apart from `p`; they stay down until `lift`.
    func land(fingers n: Int = 2, atMM p: (x: Double, y: Double) = (62, 45)) -> TouchScript { fatalError("not implemented") }
    /// Moves every non-thumb finger that is down by `d` over `over` (100 ms by default).
    func slide(byMM d: (x: Double, y: Double), over: Duration = .milliseconds(100)) -> TouchScript { fatalError("not implemented") }
    /// Lifts the down fingers: all of them, or only the first landed. Ends a press in progress.
    func lift(_ which: Lift = .all) -> TouchScript { fatalError("not implemented") }   // enum Lift { case all, first }
    /// A press held from now until the next lift.
    func press() -> TouchScript { fatalError("not implemented") }
    // thumb(atMM:) after liftThumb() lands the thumb again (a new contact, same id, .landing); liftThumb lifts the
    // thumb that is down now. `wait` with fingers down is a hold.
}

extension World {
    /// What the next swipe reads as frontmost; nil models "none" or Trackpad Launcher itself.
    func makeFrontmost(_ name: String?) { fatalError("not implemented") }
    /// Delivers the frames of `script` newer than any delivered on that trackpad, so scroll events can interleave.
    func play(_ script: TouchScript, on trackpad: Trackpad = .macBook14) { fatalError("not implemented") }
    /// A World with Safari, Mail, Slack and Notes installed, Mail, Slack and Notes listed in that order, Safari frontmost, started.
    static func switcherWorld(accessGranted: Bool = false) -> World { fatalError("not implemented") }
    /// Thumb at (10, 10), two fingers down, each slide in turn (mm, positive right), then the fingers lift unless `lift` is
    /// false. Returns its script so a row can continue it with `play`.
    @discardableResult
    func swipe(_ slidesMM: Double..., lift: Bool = true, on trackpad: Trackpad = .macBook14) -> TouchScript { fatalError("not implemented") }
}

// InMemoryTrackpads: run(_:handMode:blockClicks:swipes:) builds recognizers with `swipes`, arms ClickFilter and
//   ScrollFilter together; touch delivers the frame's event through TrackpadEvent(_:on:) inline; playFeedback records
//   `pulses: [Pulse { haptic, trackpad }]`, with `feedback` (gesture pulses, so today's assertions keep reading) and
//   `lightTicks` derived; `scroll(_ event: ScrollEvent) -> ScrollVerdict?` decides on the merged flags the last frames
//   left (nil when no tap is armed) and records `scrollVerdicts`; inject(_ event: TrackpadEvent) delivers regardless of
//   `running` (the real adapter's generation gate has no in-process seam).
// RecordingSystemActions: `var frontmost: URL?`; frontmostApp() returns it.
// Fixtures.recordSavedByPlan002(handMode: HandMode = .right, two: AppEntry? = nil) -> Data: a binary plist of today's
//   `Settings` shape (handMode + assignments 1...4), written through a test-local struct, as today's build saves it.

// SourcePolicyTests
//   banned:   − Entry(token: "scrollWheel", rule: "R6 never scrolling")
//             ~ Entry(token: "ScrollWheel", rule: "006 R12 scroll events only by their Swift names, in the tap")
//   confined: + Confined(token: "scrollWheel", onlyIn: "ClickTap.swift", rule: "006 R12 scroll suppression in the one tap")
//   The kept-token pin and the overlap check are unchanged; they pass as is.
// PointerEventTests → TapEventTests: mask bits [1,2,3,4,6,7,22,25,26,27,34]; everyMaskedTypeParses over TapEvent;
//   `.scrollWheel` leaves ignoresEverythingElse; synthetic scroll events (CGEvent(scrollWheelEvent2Source:…) plus
//   setIntegerValueField for phase, momentum, isContinuous: F18) parse to .wheel / .fingers / .momentum / .unphased;
//   passStill reads back nine zero deltas and the same type and phases.
```

**Requirement trace and seams.**

| R | Carried by | Verified at |
|---|---|---|
| R1 | `Gesture.five`; `init?(fingerCount:)` nil above 5 | Recognizer: five → `.five`, rolling five → `.five`, six → nothing (amends `fiveFingerTapFiresNothing`, `fiveFingersInARollingTapFireNothing`). World: Slack, not Spotify; haptic and animation |
| R2 | `Gesture.allCases` rows; `gesture-5.svg` | World: five rows, all `.unassigned` (amends `PersistenceTests` counts); fifth assignment fronts on a five-finger tap. Illustration and mirroring: manual |
| R3 | `.tapping` drag check → `.swiping`; `.resting`; `Pair`; `Move.isSideways`; `swipes` | Recognizer: 5 mm sideways → `.began`; 2 s rest then sideways → `.began`; 10 mm down then 20 mm right → no phase; one or three fingers → none; fingers before thumb → none; two-finger tap under 3 mm → `.two`; drifting three-finger tap → `.began` then `.cancelled`; drifting two-finger tap → `.began` then `.ended`. World: no haptic, nothing fronted |
| R4 | `Switcher.init?` row rule; `catalog.locate` at begin | Switcher (pure): frontmost in or out of the list. World: Figma trashed → left out |
| R5 | `Switcher.home` | Switcher (pure); World: `selectedApp` at begin |
| R6 | `selected`, `position`, `stretch`; travel is +x on `SurfacePoint` | Switcher (pure): 5, 6, 7, 24, 24 then −12, +30 at the end, stretch bound. Recognizer: travel values on `.macBook14` and `.magicTrackpad`, left hand → same sign. Spring and look: manual |
| R7 | ticks per `|Δselected|`; `Haptic.lightTick` | World: 36 mm → 3 `lightTicks`; 5 mm → 0. Feel against the gesture haptic: manual |
| R8 | `.ended` at the first pair lift; `Launcher.swipe(.ended)` | Recognizer: one finger lifts → `.ended`, later frames silent until all lift. World: Slack fronted, `feedback` once, no animation, window closed; frontmost selected → nothing, window stays; thumb lifted → still fronted |
| R9 | Exits `.click`, foreign landing; `.blocked` ignored; optional thumb | Recognizer: thumb slides out, re-lands → `.ended`; third finger → `.cancelled`; `.click` → `.cancelled`; `.blocked` → continues. World: no access + press → nothing fronted; access + press → `[.drop, .drop]`, fronted |
| R10 | `SwitcherPresenter`, `SwitcherPanel` (F26 configuration), `AppIcons(side: 80)` | World: `switcher` non-nil while up, nil at end or cancel. Glass, sizes, display, full screen, focus, dark mode, Reduce motion, ≤ 200 ms, no perceptible delay: manual |
| R11 | `Switcher.init?` nil; `run(swipes:)`; `reconcile()` on a null row; `activity` guard; frontmost nil → none | World: empty list → no `.began` and no blocking after 4 s; only frontmost, only missing, or no frontmost → `switcher == nil` and a press after the begin passes (the recognizers were replaced); Tap to click on → nothing |
| R12 | `ScrollFilter` on the R4 flag; `.wheel`; no tap without access | ScrollFilter table. World `scroll`: within 3 s → `.drop`; after 4 s → `.pass`; thumb lifted → `.pass`; wheel → `.pass`; no access → nil and the switcher works. Real pages and a real wheel: manual |
| R13 | `blocksClicks` true in `.swiping` | Recognizer: true from `.began` to `.ended`, thumb or no thumb, after 4 s. World: late swipe press → `[.drop, .drop]`; late swipe scroll → `.pass` then `.passStill` |
| R14 | Treatment inherited by momentum, never escalated | ScrollFilter table; World: flick in the window → momentum `.drop`; coasting then thumb lands → `.pass` |
| R15 | `Copy.accessibilityHint` | Core: the exact string. Rendered: manual |
| R16 | `SwitcherSection`, `swipe.svg`, order in `LauncherView` | Manual (layout, mirroring, light and dark) |
| R17 | `switcherRows` resolved with `rows`; `present == nil` = missing | World: order matches the switcher row; trash → `present == nil`; restore and `openWindow` → present |
| R18 | `addToSwitcher`; `SwitcherList.append`; `addMenu(listing:)`; `.listed` | Pure menu projection: `✓ Mail (listed)`, no `None`. World: append Notes; Other… from Downloads; Other… a listed app → unchanged; an app on a tap and in the list → added |
| R19 | `removeFromSwitcher` | World: list after removal. Hover and context menu: manual |
| R20 | `moveInSwitcher`; `SwitcherList.move` | World: Notes to 0 → Notes, Mail, Slack; the next switcher uses it. Dragging in the panel: manual |
| R21 | `ForEach` over an empty `switcherRows` | World: fresh install → `switcherRows.isEmpty`. Look: manual |
| R22 | List `ScrollView` + `fitToContent` height cap; refit on count | Manual (30 apps on a 13" display); F36 probed the mechanism |
| R23 | `Settings.switcherList`, tolerant `init(from:)`, `SwitcherList` coding | World: relaunch keeps five-finger Slack and Notes, Mail; `Fixtures.recordSavedByPlan002` loads with its assignments and an empty list |
| R24 | `Copy.gestureHint(for:)` | Core: the exact string per hand mode. Rendered: manual |

**Test handles.**

| Thing | Handle |
|---|---|
| The clock behind 400 ms, 3 s and "no time limit" | `TouchFrame.time`; `TouchScript.wait` |
| The swipe event stream | `Recognition.event` per frame (`steps.compactMap(\.swipe)`); `InMemoryTrackpads.touch` delivers it inline |
| A swipe by script | `TouchScript.land`, `slide`, `lift(.first)`, `press`, `liftThumb`, and `thumb` again; `World.play` for increments; `HandFrames` for anything else |
| The frontmost app | `RecordingSystemActions.frontmost`, `World.makeFrontmost(_:)`, nil for none or self |
| The switcher's visible state | `launcher.switcher` (row, home, selected, position, stretch) |
| The haptic kind and order | `InMemoryTrackpads.pulses`; `feedback` and `lightTicks` derived |
| Scroll events | `InMemoryTrackpads.scroll(_:)` on the frames' flags; `ScrollFilter` directly; synthetic `CGEvent`s in LauncherPlatformTests |
| What suppression does to an event | `ScrollVerdict.apply(to:)`: `.drop` → nil; `.passStill` → all nine delta fields read 0 and the phases are unchanged |
| A reconcile mid-swipe | `preferences.set` between two `play` calls → `switcher == nil`, the remaining fingers do nothing until they lift |
| The old settings record | `Fixtures.recordSavedByPlan002` as a binary plist into the suite |
| Presses during a swipe | `TouchScript.press()` → `pressVerdicts` |

**Existing tests this plan amends** (only the ones `how.md` names): `fiveFingerTapFiresNothing` and `fiveFingersInARollingTapFireNothing` now expect `.five`, with a six-finger row replacing the "nothing" case; `thumbThenNFingerTapFiresThatGestureOnce` and `aFirmTapOpensItsAppAndTheWholePressNeverReachesApps` run over 1...5; the `PersistenceTests` row counts go to 5 and `assignmentsAndHandModeSurviveARelaunch` assigns and expects five names (it compares `rows.map(\.app)` against the names it zipped with `Gesture.allCases`); `PointerEventTests` covers mask bit 22, no longer lists `.scrollWheel` under `ignoresEverythingElse`, and `everyMaskedTypeParses` parses `TapEvent`; the `RecentAppsTests.menu` projection reads `.app(_, state:)`; `.unassigned` call sites in `setAssignment` become `nil`. A two-finger sideways drag is now a swipe, but it fires no tap, so `draggingFingersIsNotATapAndTheNextTapStillFires` still reads `[.two]`. `twoFingersHeldFiveHundredMillisecondsFireNothing`, `liftingTheThumbEndsBlockingAtOnce` and `aThumbSlidingOutOfTheCornerStopsBlocking` pass unchanged.

**Docs.**

- `docs/domain-model.md`: *Gesture* (five tap gestures); *Tap* (a two-finger tap that slides sideways past 3 mm becomes a swipe); *Launcher window* (five rows, the switcher section, the toggle, the hint, Quit); *Feedback* (the *gesture haptic* and the *light tick*; the silent lift on the frontmost app); *Click blocking* (trackpad and Magic Mouse scrolling suppressed under the same rule and for the whole of a swipe; the momentum of a suppressed scroll too; pointer movement and wheel mice never; a mouse click during a swipe is blocked for the swipe's length); *Blocking window* (held open for the whole of a swipe); *Accessibility hint* (names scrolling); new entries *5-finger gesture*, *Swipe*, *Switcher*, *Switcher list*, *Frontmost app*, *Light tick*.
- `docs/architecture.md`, three cross-cutting sentences: Concurrency, "only completed gestures hop to the main actor" becomes "only recognised events hop: a fired tap, and a swipe's begin, moves and end, in frame order on the main queue, never from a replaced session"; the main-actor icon-drawing exceptions gain the switcher's frontmost icon (drawn at swipe begin from the running app's loaded representations) and its draw-on-cache-miss fallback; Privacy, Accessibility is used "only to block trackpad clicks and suppress trackpad scrolling during gestures", with the scroll-event API confined to the tap's file like the tap itself. The tap's thread now wakes for scroll events while armed.
- `docs/product-overview.md`, the three changes the Solution names: five tap gestures plus the swipe; the haptic rule's one exception (a swipe released on the frontmost app is silent); the sound effect stays deferred.
- Plan text, done in this plan's Solution: the amendments paragraph names plan 002 R9 (scroll events are now read, and those of a suppressed scroll changed) and plan 001 R11's "drag or scroll" bullet (scoped to taps). The glossary, the architecture sentences and the product overview edits are in the working tree with this design and are committed with the slice that makes them true.

**Deliberately not done.** No timer, deadline or display link. No main-to-frame channel: the recognizer is never told the row. No device attribution of scrolls beyond `isContinuous`. No posting, and no synthesising of momentum or `ended` events: zeroing happens in place. No switcher row wider than the screen. No grace period at the lift. No launch animation on a swipe. No `NSRunningApplication` crosses a port. No pasteboard drag for reordering. No cap on the list. No change to `ClickFilter`, `PointerEvent` or `PointerVerdict`.

### Synthesis decision

**Base: candidate 1** (the Opus runner). Both candidates converged on the backbone: the swipe as two more states of the one recognizer with an optional thumb only in `.swiping`, begun exactly where the drag rule spoiled, with `blocksClicks` true throughout and the exits named; travel in millimetres across the port and the selection decided on main; the main-queue hop; the switcher as model state; a tolerant `Settings` decoder; the `scrollWheel` token confined to `ClickTap.swift`. That convergence is shipped as is. They diverged on the invariant-bearing edges, and candidate 1 was right on each: the `swipes` gate (without it every upgrading user with an empty list loses sideways scrolling for the whole of an anchored slide, against R11 and R12); the run-generation gate (a stale `began` after `reconcile()` would otherwise leave a switcher nobody can close); the per-gesture, never-relaxing scroll treatment (candidate 2's per-event rule leaks a `changed` that races the lift frame, against R13's "after"); a `Pair` constructed as exactly two with "none joining on this frame" and a deterministic farthest-finger mover (candidate 2 iterated a dictionary and missed a third finger landing on the begin frame); the `Switcher` whose only constructor encodes R4, R5 and R11, with ticks per icon crossed; the frontmost app parsed through the one existing catalog rule; AppKit and Core Animation rendering per the architecture's animation rule; an R22 mechanism with no feedback loop (F36 probed it after fan-out: `fittingSize` reports the full height and a capped frame is absorbed by the `ScrollView` alone, so candidate 2's `WindowLimits` observable written from `refit()` is unnecessary and its `List` cannot size the window); a reorder that does not depend on O9.

**Cross-judge:** recommended candidate 1 as the base, 16 to 9 on the rubric (C1 3/2, C2 2/1, C3 3/1, C4 3/2, C5 2/1, C6 3/2); my own scoring was 15 to 12 with the same ordering on every criterion. It found no misdescription of the existing code in either candidate and no red flag in candidate 1 beyond the acknowledged panel-configuration copy. Agreement confirms the pick.

**Grafted from candidate 2:** `Copy.gestureHint(for:)` and `Copy.accessibilityHint` as core values (candidate 1 left both strings in the view, the one rubric defect the judge and I both found); `TrackpadEvent.init(_:on:)` as the single mapping both adapters use; `InMemoryTrackpads.pulses` as one ordered record with `feedback` and `lightTicks` derived; `PickerItem.app(_, state: AppItemState)` instead of a sibling `.listed` case, so checked and disabled are one dimension of one item; `AppMenuButton` in two forms over one coordinator instead of a shared populate function plus a second button; `Recognition.Event` as a nested type with the existing `.fired` vocabulary; the plan-002 record fixture by name; its open questions and handles that candidate 1 lacked (glass in a `.screenSaver`, non-key, click-through panel and glass on glass; Magic Mouse unobserved; a reconcile mid-swipe).

**Changed in the base during synthesis:** the rubber band's high-water mark and `switcherPushStepMM` are dropped: `stretch` is a pure saturating function of the raw excess, and the presenter re-adds a keyed additive spring on each change, which gives the same feel (tracks while pushing, settles when the push stops) with no stored state; the claim that `inject` after a reconcile is ignored is dropped (the gate lives only in the real adapter, as the judge noted); `AppCatalog.locate` consults registered copies lazily (the judge measured a LaunchServices query per listed app at swipe begin); `ClickFilter`'s doc comment no longer claims to be everything the tap is told; the docs section gains the architecture's icon-drawing exceptions, the product overview, the glossary's mouse-click sentence and the plan-text gaps.

**Rejected from candidate 2, with reasons:** scroll suppression folded into `ClickFilter` with a per-event rule (the lift race; and `passAsMove` would be meaningless for scrolls, `passAsStill` for presses); `frontmostApp() -> AppEntry?` built in the adapter from `localizedName` (a second `AppEntry` parse rule beside `catalog.entry(at:)`); `SwitcherIcons` (a second copy of `AppIcons`' cache policy; a `side` parameter suffices); `SwitcherRow.make` returning a tuple plus `SwitcherGeometry` statics forwarded by `Switcher` (two public surfaces for one rule); a nil frontmost shown with the selection on the leftmost icon (its own pseudocode then made the lift there silent, and a one-app list with no frontmost would show a switcher that can open nothing); `List` with `onMove` and the `WindowLimits` cap (O9 unprobed; F36); renaming `blocksClicks` to `blocking` (churn across tests; the glossary still defines scroll suppression in terms of click blocking); `PickerTarget` (a completion closure needs no enum); `IndexSet` intents (only `List` needed them); SwiftUI content for the switcher (its springs and scale animations are not Core Animation keyframes, the architecture's rule). **Rejected from the judge's suggestions:** gating swipes on "at least one present app" rather than a non-empty list: the gate would then flip in `resolveRows`, which runs on every window open, and a reconcile there would reset recognizers mid-gesture. **Changed after the test planner's report:** its finding that R11's "MUST do nothing" contradicted the accepted over-blocking for a list of only missing apps or only the frontmost app is closed in the design, since a `began` that yields no switcher now ends the swipe through `reconcile()` (decision 3) and nothing stays blocked; its finding that the run-generation gate has no seam is answered with the manual hot-plug check rather than a ticket type whose only logic is an integer comparison (the in-memory adapter already drops a replaced session's frames at `touch`); its R12 "at once" finding stays the first open question, for the requirement owner.

### Tradeoffs accepted

- We accept that a scroll gesture suppressed at any point stays suppressed until its fingers lift and its momentum ends, even if the 3 s window closes mid-gesture. In exchange, no app ever sees a broken began-to-ended bracket, nothing leaks when a `changed` races the lift frame, and momentum follows its gesture with no clock. We read R12's "work again at once" as "the next scroll works at once", the scroll analogue of plan 002 R5's whole press.
- We accept two suppression mechanics, dropping (gesture never seen) and zeroed pass-through (gesture already seen), in exchange for apps seeing either nothing of a suppressed gesture (no overlay-scroller flash) or a complete, motionless one (no stuck elastic state). The probe verified zeroing only on a locally built event.
- We accept that a thumb landing in the corner while two fingers are already scrolling stills the rest of that scroll, because R12 says "exactly the conditions that block clicks" and a thumb landing with fingers down opens a window.
- We accept one main-queue hop per changed frame while a swipe moves (~100 Hz), plus a layer update per main turn, in exchange for the selection, ticks and effects staying pure and in the model. The work is input-driven and stops when the fingers stop.
- We accept swipes switched off while the switcher list is empty (one more `run` argument, and a reconcile when emptiness flips), in exchange for users who never fill the list keeping today's scrolling past the 3 s window.
- We accept that a swipe with nothing to show (a list of only missing apps or only the frontmost app, or no frontmost app) ends through `reconcile()`, which restarts the devices and the tap, in exchange for R11's "do nothing" holding with no main-to-frame channel. A scroll in progress at that moment stops for the time main takes to handle the `began` and resumes through the replaced tap's fresh filter; inside the 3 s window it resumes without the `began` apps never saw, the headless gesture the disabled-tap recovery already accepts. For the rest of that hand the resting thumb has no window, so a press within 3 s of its real landing passes: R11 wins over plan 002 R4 there.
- We accept that mouse clicks during a swipe are blocked for the swipe's length, not 3 s, by the same indistinguishability plan 002 accepted.
- We accept one scroll memory for every pointing device: interleaved streams from a Magic Mouse and a trackpad share one filter, since the system reports them alike (non-goal).
- We accept that the switcher panel repeats the launch overlay's ten-line panel configuration in `LauncherUI`, because `LauncherUI` does not depend on `LauncherPlatform`. The recipe is cited, not shared.
- We accept that rendering the switcher in AppKit and Core Animation is more imperative than SwiftUI, in exchange for springs and fades played by the render server with no code of ours per display frame, as in the launch overlay.
- We accept `catalog.locate` for every listed app on the main actor at swipe begin (one Info.plist read each after the lazy-lookup change), in exchange for a row that is correct at the moment it is shown rather than at the last window open.
- We accept that the frontmost app's icon may be drawn at begin (0.1 ms observed through `NSRunningApplication.icon`, 25 ms once for another running app, F4) rather than prepared, since it cannot be known earlier.
- We accept that `AppChoice` loses `.unassigned` (five call sites change) in exchange for intents that are total over their input.
- We accept a light tick per icon crossed even when one frame crosses two (they merge on the actuator), in exchange for counts that match R7.
- We accept that the tap wakes for every scroll event in the session while armed (F19), in exchange for one tap and no second permission.

### Alternatives considered

- **A separate `SwipeRecognizer` beside `GestureRecognizer` on the frame thread.** Exposes nothing new to callers, but each recognizer would need the other's facts (which fingers belong to the tap, whether 400 ms ends a pair, which owns the flag): two writers of `blocking` or a merge, and a protocol between two state machines. Rejected: two owners of one finger session, the reason plan 002 rejected a second owner of the blocking decision.
- **The recognizer told the row length and emitting the selection (O2).** Exposes a main-to-frame channel mid-gesture, because the row depends on the frontmost app and the catalog; the 12 mm rule could only be tested through frames. Hides hops on moves that do not change the selection, which the highlight needs anyway (R6). Rejected.
- **The switcher as an effect behind `SystemActions` (`show`, `update`, `hide`) played by `LauncherPlatform` (O5).** Three methods mirroring model state, callers coordinating several calls per swipe, state split between the model and the adapter, tests reading a recording fake instead of the model. Hides nothing the model-state shape does not. Rejected as shallow; the overlay precedent is for stateless effects.
- **SwiftUI for the switcher's content.** Declarative, with `glassEffect` and environment Reduce motion, and less code. But its springs and scale animations are not Core Animation keyframes, the architecture's animation rule, and the overlay precedent is Core Animation. Kept for the window, not used for the switcher.
- **Delivery by `Task { @MainActor }` (observed order), or a coalescing mailbox, or self-describing events (O3).** The first rests on undocumented ordering (F6); the second needs a field written by two threads; the third cannot make an `ended` that overtakes its `began` harmless without a remembered set of swipe IDs. The documented FIFO queue plus a generation gate is the simplest correct choice.
- **Suppress by dropping only (O4).** Simplest, but when suppression starts mid-gesture (a late swipe, or a thumb landing mid-scroll) apps keep an open scroll gesture with no `ended`. **Suppress by zeroing only.** Brackets always close, but a gesture blocked from its first event shows apps an empty gesture (overlay scrollers flash), and per-event decisions relax at the lift and leak. The per-gesture treatment combines the two failure-free halves.
- **Scroll suppression inside `ClickFilter` as more `PointerEvent` cases.** One lock and one `decide`, but two unrelated policies in one filter: `passAsMove` means nothing for a scroll, `passAsStill` nothing for a press, and every scroll change touches the click filter. A sibling filter with its own vocabulary keeps the click filter untouched.
- **Recognise swipes regardless of the list.** Simpler `run`, but it suppresses scrolling for every user who never uses the switcher (R11 "do nothing"). **Gate on "at least one present app".** More precise, but the value changes in `resolveRows`, which runs on every window open; reconciling there resets recognizers mid-gesture.
- **`frontmostApp()` returning an `AppEntry` built in the adapter.** Parses at the boundary, but with a second name rule (`localizedName`) beside `catalog.entry(at:)`; two entries for one app could differ. The URL plus the one catalog parse keeps one rule.
- **`List` with `.onMove`, or `.draggable` and `.dropDestination`, for reordering (O9).** Both depend on unprobed drag behaviour in a non-activating key panel; `List` brings its own chrome into the glass card and does not size to its content under `fittingSize` (F36). A `DragGesture` over fixed-pitch rows needs neither.
- **A SwiftUI `ViewThatFits` or an observable height cap for R22 (O7).** `ViewThatFits` picks by fitting the proposal, which `fittingSize` makes unbounded; an observable cap written in `refit` races SwiftUI's asynchronous update and reads a stale `fittingSize`. Capping the panel frame and letting one flexible child absorb the deficit uses SwiftUI's layout as designed (F36).

### Open questions and risks

- Is "a scroll suppressed at any point stays suppressed until its fingers lift" acceptable for R12's "scrolling MUST work again at once"? The alternative, resuming mid-gesture, shows apps `changed` events without a `began` for a dropped gesture, and leaks deltas at the lift of a late swipe. How far the drop-at-open rule reaches past the 3 s window also depends on whether `mayBegin` arrives when fingers land or ~17 ms before `began` (F18 sequences 3 and 4 do not settle it).
- R12 read literally stills an in-progress two-finger scroll when a thumb lands in the corner. Should a thumb that lands while two fingers are already scrolling open no scroll suppression (as R14 already protects momentum)?
- Is gating swipes on a non-empty switcher list, and ending a swipe that shows nothing through `reconcile()`, the intended reading of R11? The residuals: a horizontal scroll in progress when such a swipe begins stops for the time main takes to reconcile and resumes, headless (no `began`) when it was inside the 3 s window; and for the rest of that hand clicks pass even inside the thumb's original 3 s, since the replaced recognizer gives a resting thumb no window.
- When the frontmost app cannot be read (or is Trackpad Launcher itself, only while Other… is open), the swipe shows nothing. Is that right, or should the switcher open with the selection on the first icon?
- R6 measures travel from where the swipe began, so with fingers moving together the first selection change comes about 9 mm after the fingers landed (3 mm to begin, then 6 mm). Should travel instead count from the landing midpoint?
- Does actuation 3 feel right as the light tick next to 6? The meaning of `actuatorActuate`'s other arguments is unknown (`how.md`).
- Does `NSGlassEffectView` render inside a `.screenSaver`-level, non-key, click-through panel, and does a glass highlight read well over a glass panel in light and dark? Manual R10 check; the fallback is a translucent material capsule.
- Does the saturating rubber band with a re-added spring per change feel right, and does the 1.12× selected icon read as "slightly larger" at 80 pt? Feel checks on hardware.
- What should happen when two fingers lift in the same frame that a third lands? This design ends the swipe (opening the selection); a delivered click wins over both (cancel).
- A swipe on a second trackpad while the first one's switcher is up is ignored on screen but still blocks on its own pad. Acceptable?
- A reconcile mid-swipe (hot-plug, wake, preference or trust change) cancels the switcher silently and the remaining fingers do nothing until they lift. Fine?
- Downgrade: an older build reading a record with a `5` key or a `switcherList` key fails to decode and loads defaults. Worth a release note?
- *Risk:* zeroed deltas were verified only as a field round trip on a local event (F18). An app that computes scrolling from data outside the nine delta fields would still move; the fallback is mapping `stilled` to `.drop`, a one-line change.
- *Risk:* the `mayBegin`-before-the-flag race. If the system's scroll recognizer emits `mayBegin` before our frame sets the flag, a gesture we would have dropped is stilled instead: overlay scrollers flash, and nothing moves.
- *Risk:* a swipe's block has no cap. Its exits are a lift, a foreign landing, a delivered click, or a `run`. A swipe could stick only if the pad never sent the empty frame after the last lift, the same assumption tap firing already relies on (plan 002's open question); with a swipe-wide block that failure would now be visible as a switcher that stays. Worth checking on hardware before the first slice ships.
- *Risk:* F4's fast frontmost icon rests on two observations; a cold `NSRunningApplication.icon` for a rarely used app may cost ~25 ms on the first swipe from it. The time from `began` to the panel on screen with N icon layers laid out is unprobed; the panel is warmed, the layout is not.
- *Risk:* Magic Mouse scrolling was never observed (F18); it is assumed `isContinuous == 1` and suppressed like a trackpad's, as the plan accepts. The wheel-mouse exemption rests on a synthetic event.
- *Risk:* a touch during momentum. If the system keeps emitting a dropped gesture's momentum events after a new gesture's `mayBegin` (F18 did not observe this interleaving), `ScrollFilter` would treat them as the new gesture's and they could move the page. A probe row (touch during a coast) belongs in the S4 hardware checks before the filter's rule is trusted on that case.
- *Risk:* F35's unmerged `feature/005` branch adds a switch to the launcher window, and its merge will meet this layout.
- *Risk:* `scrollWheel` must not appear in any shipped file but `ClickTap.swift`, comments included; the implementation must spell the field names only there and say "scroll" elsewhere.

### Next implementation step

Add the `TouchScript` swipe primitives (`land`, `slide`, `lift(.first)`, `press`, thumb re-landing). Then grow `GestureRecognizer` test-first with `Gesture.five`, `.resting`, `.swiping` and `Recognition.event`, against R1, R3, R8, R9 and R13 at the recognizer seam.

