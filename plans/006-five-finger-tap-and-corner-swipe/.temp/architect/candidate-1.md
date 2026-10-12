## Design

### Problem

Plan 006 adds a fifth tap gesture, a two-finger swipe that drives an on-screen switcher, a switcher list edited in the launcher window, and scroll suppression in the existing event tap. The fifth tap is nearly free: `Gesture(fingerCount:)` returning nil is the only thing that silences five fingers today (F13). The swipe is the hard part. It breaks three assumptions the recognizer was built on:

- every non-idle state carries the anchor and dies with it (F9 iii);
- a two-finger rest ends at 400 ms (F9 i);
- a movement past 3 mm spoils the tap (F9 ii).

On top of that, the swipe must:

- keep the one per-trackpad flag true for its whole length, however long it lasts and whether or not the thumb stays (F9 iv, F21);
- stream about 100 Hz of travel to the main actor, which decides the row, the selection and the haptics, without a reordering hazard (F6, F7);
- use no timer and no second clock (F8, F27).

Scroll suppression rides on that same flag, read when each event arrives. It needs one piece of memory per scroll gesture, because momentum arrives after the fingers have lifted (F18). It also has to get past a source gate that bans the very API it uses: the token must move from banned to confined, and the gate must not be weakened (F17).

Constraints carried over:

- One `@MainActor @Observable` `Launcher` owns every decision, and the shell renders its state (F24).
- Every port has exactly two adapters, and framework types never cross a port (F25).
- Recognition stays on the frame thread, and the in-memory hardware delivers synchronously (F7).
- Every field has one writer, and `run` resets everything by construction.
- A record saved by today's build must still load (F22, F23).
- `LauncherCore` imports only Foundation and Observation.

### Usage (caller's view)

**README excerpt.**
- **Recognition.** The recognizer still owns everything that happens on the frame thread. Per frame it now returns `Recognition { event, blocksClicks }`, where `event` is a fired tap (one to five fingers) or a swipe phase: `began`, `moved(travelMM:)`, `ended` or `cancelled`. Travel is measured from where the swipe began, as the sideways movement of the two fingers' midpoint, in trackpad millimetres, positive to the right.
- **Delivery.** The hardware adapter delivers these events to the main actor in frame order and drops any event from a session that a later `run` replaced.
- **The model.** `Launcher` turns a swipe into one observable value, `switcher: Switcher?`, which holds:
  - the row, fixed when the swipe begins;
  - the home index, which is where the frontmost app sits;
  - the travel.

  The selection, the highlight's resting position and its rubber band are all pure functions of that value. Each icon crossed plays a light tick. At the end, the model brings the selected app to the front, unless the selection is still the frontmost app.
- **Rendering.** The shell draws the switcher from `switcher` and from nothing else.
- **Scroll suppression.** It happens in the same tap, on the same flag, with a pure `ScrollFilter` beside `ClickFilter`.
- **The switcher list.** It is a `SwitcherList` value inside `Settings`, edited through three intents.
- **Tests.** They drive all of it synchronously through `World`.

```swift
// TrackpadLauncher app target: the composition root does not change. MenuBarShell owns the switcher's presenter, and
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
    let world = World.switcherWorld()                      // Safari frontmost; Mail, Slack, Notes listed
    world.launcher.openWindow()
    world.swipe(3.5, 4)                              // 4 mm: nearer Safari than Mail
    #expect(world.system.broughtToFront.isEmpty && world.hardware.feedback.isEmpty)
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

// Pure policy: R6's nearest-icon rule, the hard stops and the rubber band's bound; R7's count. No adapter involved.
@Test(arguments: [(travel: 5.0, selected: 0), (7, 1), (24, 2), (-30, 0), (60, 3)])
func theSelectionIsTheNearestIconAndNeverPassesAnEnd(travel: Double, selected: Int) {
    var switcher = Switcher(listed: [mail, slack, notes], frontmost: safari, trackpad: Trackpad.macBook14.id)!
    _ = switcher.move(to: travel)
    #expect(switcher.selected == selected)
    #expect(abs(switcher.stretch) < 0.2)             // never more than a fifth of an icon past an end
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

AddAppButton(
    installedApps: launcher.installedApps, listed: Set(launcher.switcherRows.map(\.id)),
    cachedIcon: actions.cachedIcon,
    add: { launcher.addToSwitcher(.app($0)) },
    chooseOther: { actions.chooseOtherApp { launcher.addToSwitcher(.appBundle(at: $0)) } })
```

### Shape

**Data first.**

- *What a frame meant.* `Recognition { event: Recognized?; blocksClicks: Bool }` has two cases:
  - `Recognized.tap(Gesture)`: a fired tap;
  - `Recognized.swipe(SwipePhase)`: one phase of a swipe.

  A frame yields at most one event, because no frame can both fire a tap and move a swipe. That is why `event` is one optional sum instead of two optionals whose valid combinations a comment would have to explain (per `type-system-discipline`). `fired` and `swipe` are derived accessors, so every existing `fired(_:)` test reads as before.
- *What crosses the hardware port.* `TrackpadEvent` gains `.swipe(SwipeEvent)`, where `SwipeEvent` is a `SwipePhase` plus the `TrackpadID`. The payload is plain values: travel is a `Double` in millimetres, and the event carries no `CGPoint` and no frame time.
  - *Ordering guarantee.* Events reach `onEvent` on the main actor in the order each trackpad's frames produced them, and never from a session that a later `run` replaced.
- *What the recognizer remembers.* `State` gains two cases:
  - `.resting(Anchor, Pair)`: two fingers still down past 400 ms. This is no longer a tap, but it can still become a swipe.
  - `.swiping(Swipe)`: `Swipe` carries the `Pair`, the midpoint where it began, the last travel it reported, and `thumb: Anchor?`. The thumb is optional only here, because a swipe outlives it.

  `Pair` is built as exactly two `Finger`s, each an id plus an origin. It is constructed, not checked, so "exactly two" cannot drift (per `type-system-discipline`).
- *What the model shows.* `Launcher.switcher: Switcher?` is non-nil exactly while a switcher is on screen.
  - `Switcher` holds the `row`, the `home` index of the frontmost app, the `travelMM`, and a push high-water mark. Its row always has at least two icons and always holds the frontmost app at `home`. Its failable initialiser is the only constructor, so a switcher that R11 forbids cannot exist.
  - `selected`, `position` (where the highlight rests, in icons) and `stretch` (the bounded rubber band) are derived, never stored (per "derive instead of sync").
  - `switcherRows: [SwitcherRow]` is the window's list. Each row is the stored `AssignedApp` plus `present: AppEntry?`, where nil means missing.
- *What persists.* `Settings.switcherList: SwitcherList`, a value whose only mutations are:
  - `append`, which ignores a bundle ID already in the list;
  - `remove`;
  - `move(_:to:)`, which clamps the index.

  It is encoded as a plain array and drops duplicates when decoded. `Settings` gets a hand-written `init(from:)` that reads the new key with `decodeIfPresent` (F22).
- *What the tap sees.* `ScrollEvent` has four cases:
  - `.wheel`, where `isContinuous == 0`;
  - `.fingers(Phase)`;
  - `.momentum(Momentum)`;
  - `.unphased`.

  `ScrollVerdict` is `.pass`, `.drop` or `.passStill` (deltas zeroed in place). `CGEvent` and its fields stay in `ClickTap.swift`.

**Load-bearing decisions.**

1. *One recognizer owns the finger session; the swipe is two more states of it (O1; F9, F10, F11).* A tap, a resting pair and a swipe are three readings of the same non-thumb fingers since the last moment none was down. They must agree on `touched`, on the landing origins and on the flag, so a second state machine beside this one would be two owners of one decision (per `model-the-domain`). The rules:
   - *Begin.* The drag check in `.tapping` becomes the swipe's entry. When the farthest-moved finger passes 3 mm, the tap becomes `.swiping` if all of these hold; otherwise it is spoiled as today:
     - swipes are on;
     - the tap is a `Pair`: exactly two touched, both down, none joining on this frame;
     - that finger's displacement is more sideways than vertical (`|dx| > |dy|`).
   - *No time limit (R3).* The 400 ms rule no longer spoils a `Pair`; it moves it to `.resting`. `.resting` never fires a tap, which keeps plan 002 R2's `twoFingersHeldFiveHundredMillisecondsFireNothing`. It spoils on a delivered click, on either finger lifting, or on any other non-thumb contact. It becomes `.swiping` on a sideways first move past 3 mm and is spoiled by a vertical one.
   - *Thumb before fingers (R3).* This holds by construction, because a tap only starts from `.armed`.
   - *During a swipe the thumb plays no part (R8, R9).* The top-of-step anchor check covers only the anchored states. `.swiping` keeps its own `thumb: Anchor?`:
     - the thumb becomes nil when it lifts or leaves `holds`;
     - while it is nil, a contact landing in `admits` becomes the thumb, with `landedAt = frame.time`;
     - a contact that is already down is never adopted (F10, the `.idle` rule).
   - *Exits, all named, in this order:*
     - a `.click` press: `cancelled`;
     - either pair finger lifting (a reused id counts as a lift): `ended`;
     - a contact landing outside `admits`: `cancelled`.

     A `.blocked` press changes nothing. Every exit goes to `thumb.map(.spoiled) ?? .idle`, which is exactly "nothing further until every non-thumb finger has lifted", with or without a thumb.
   - *Blocking after the swipe.* After a swipe, plan 002 R4 alone decides blocking, using the current thumb's `landedAt`. A thumb that re-landed mid-swipe opens its own fresh 3-second window. A `run` ends any swipe, because it replaces the recognizer.
2. *The flag stays the only channel (F21; why.md "Change").* `blocksClicks` is `true` in `.swiping`, whatever the anchor or the clock says, and follows the unchanged R4 expression in every other state. The tap reads it for presses and now for scrolls. Nothing new crosses between threads (per "single source of truth per invariant").
3. *Swipes are recognised only while the switcher list is not empty (R11).* `TrackpadHardware.run` gains `swipes: Bool`, and `reconcile()` passes `!settings.switcherList.isEmpty`. With swipes off, the recognizer behaves exactly as today plus five fingers: a pair's drag spoils, and a resting pair spoils at 400 ms.
   - Without this gate, every user with an empty list (every upgrading user) would find an anchored thumb plus a sideways two-finger scroll suppressed for its whole length, past the 3 s window, while R11 says such a movement "MUST do nothing".
   - The list's emptiness flips only through the three edit intents, and they reconcile only on a flip.
4. *Travel crosses the port and the selection is decided on main (O2; F11).* The recognizer knows millimetres and nothing about rows. The row depends on the frontmost app and on the catalog, which are main-actor facts, so the selection belongs to the pure `Switcher` in core:
   - `selected = clamp(home + round(travel / 12 mm))`, rounding half away from zero, so it changes at ±6 mm and then every 12 mm;
   - `position = clamp(home + travel / 12 mm)`;
   - `stretch` is a rubber band, bounded below 0.2 icons, over the push's high-water mark past an end;
   - `move(to:)` returns the number of icons crossed.

   Right is +x on `SurfacePoint` in both hand modes, so R6's direction rule needs no code.
5. *Delivery is the main queue, gated by run generation (O3; F6, F7).*
   - `MultitouchTrackpads` hops with `DispatchQueue.main.async { MainActor.assumeIsolated { … } }`, the path libdispatch documents as FIFO and the one `SystemAppScanner` already uses. Events then arrive in frame order without depending on the observed but undocumented order of unstructured tasks.
   - Each session's deliver closure captures the `run` generation that made it. On main, an event whose generation is stale is dropped. This closes the existing "a session fetched just before `run` can still deliver" gap for taps too. For a `began`, it is not a nicety: a stale `began` would open a switcher that no `ended` can ever close.
   - `reconcile()` sets `switcher = nil`, because every recognizer is fresh afterwards (per `make-operations-idempotent`).
   - The in-memory adapter keeps calling `onEvent` inline (F7).
6. *The frontmost app is read once, at begin, through `SystemActions` (O6; F1, F2, F3).*
   - `frontmostApp() -> URL?` returns the active app's bundle location, or nil when there is none or when it is Trackpad Launcher itself.
   - The model parses it with `catalog.entry(at:)`, as Other… already parses its URL. Identity is the bundle ID.
   - Nil or self means no switcher. A `Switcher` has no meaning without a home, and starting anywhere else would make a lift without moving open an app. F1 shows that a frontmost app always exists in practice. F2 shows that self is possible only while the Other… chooser is up.
   - It is a query on the workspace port, beside `bringToFront`, its natural pair. A one-method port would be a hypothetical seam.
7. *The switcher is model state rendered by `LauncherUI`, with AppKit and Core Animation (O5; F24, F26, F27, F32).*
   - The model owns which apps are shown, which one is selected, when the switcher shows, and every effect. A test reads `launcher.switcher` with no fake.
   - `SwitcherPresenter`, owned by `MenuBarShell`, iterates `Observations({ launcher.switcher })`, which coalesces to the latest value per main-actor turn, a natural back-pressure at about 100 Hz. Its panel uses the launch overlay's configuration (F26): borderless, `.nonactivatingPanel`, `ignoresMouseEvents`, `.screenSaver` level, `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`, never key. It is created once at launch (F32's 27 ms), with an `NSGlassEffectView` behind icon layers and a glass highlight view.
   - *On open:* size the panel from the icon count (deterministic, no measuring), centre it on the display under `NSEvent.mouseLocation`, and call `orderFrontRegardless`.
   - *Per update:* set the highlight's x to `position × 100 pt` inside a `CATransaction` with actions disabled, so it follows the fingers one to one. Draw the selected icon at 1.12× scale and show its name below the row.
   - *When `stretch` grows:* add an additive `CASpringAnimation` from `stretch × 100 pt` to 0. Pushing keeps the highlight slightly past the end; holding lets the render server settle it on the end icon. No code of ours runs per display frame.
   - *On close:* fade out over 150 ms, then `orderOut` from the completion callback, unless a new switcher opened meanwhile.
   - *Reduce motion:* no spring, no scale animation, no fade.
8. *Icons are ready before the swipe (F4, F5).*
   - `AppIcons` gains a `side` parameter; the presenter holds an 80 pt instance.
   - It re-renders the list's present apps off the main actor whenever `switcherRows` changes, and when `NSApp.effectiveAppearance` changes (KVO, a push).
   - A frontmost app outside the list is looked up through `NSRunningApplication.icon`, which took 0.1 ms in both runs. A cache miss for a listed app falls back to drawing on the spot, as `LaunchOverlay.bitmap(for:)` already does.
9. *Haptics take a kind (O8; F14).* `playFeedback(_ haptic: Haptic, on:)`, where `Haptic` is `.gesture` or `.lightTick`. The adapter maps `.gesture` to actuation 6 (unchanged) and `.lightTick` to 3, the "weak" one the existing comment names; the light tick is tuned by feel. The model plays one light tick per icon crossed and plays the gesture haptic only when an app is brought to front.
10. *Scrolls are suppressed per scroll gesture, in the one tap (O4; F8, F15–F20).*
    - `ClickTap` adds `.scrollWheel` (22) to its mask and keeps a `Mutex<ScrollFilter>` beside its `Mutex<ClickFilter>`. Both read the same `anyTrackpadBlocksClicks()` before taking their own lock.
    - *The memory is the treatment of the scroll gesture in progress, momentum included:*
      - a gesture first seen at an opening event (`mayBegin` or `began`) while blocking is `dropped`: apps never see any of it;
      - a gesture that was passing and meets blocking mid-way becomes `stilled`: its remaining events pass with every delta zeroed (axes 1–3 in lines, fixed point and points), so the app's began-to-ended bracket closes and nothing moves;
      - a `passed` gesture's momentum is never touched (R14, "coasting from before");
      - the treatment never relaxes inside a gesture, the scroll analogue of "a press is blocked or passed whole" (plan 002 R5).
    - *Exemptions and resets:*
      - `.wheel` always passes (R12);
      - `.unphased` is decided per event on the flag;
      - momentum with no known gesture passes;
      - on `tapDisabledBy…` the filter forgets the gesture in progress, as `forgetHeldPresses()` does.
    - Without access there is no tap, so nothing is suppressed (F20).
    - Zeroing is an in-place rewrite like `passAsMove`. Nothing is posted.
11. *The gate moves the token; it does not weaken it (F17).* `scrollWheel` leaves `banned` and becomes `Confined(token: "scrollWheel", onlyIn: "ClickTap.swift")`. `ScrollWheel` stays banned, which passes the case-sensitive overlap check. Every scroll field name lives in that one file, and core comments say "scroll event".
12. *Persistence is tolerant by construction (F22, F23).* A missing `switcherList` key decodes as empty, and `handMode` and `assignments` decode as today. The first-launch rule (no record means first launch) and "undecodable loads as defaults" are unchanged. An old record's `assignments` decode into the five-case `Gesture`.
13. *The window reuses the picker machinery (O7, O9; F28–F31).*
    - *The Add menu.* It is a pure shape: `InstalledApps.addMenu(listing:)` returns the recent apps, a divider, the others, a divider, then Other…, with no None. A listed app becomes `PickerItem.listed(entry)`, which is checked and disabled. `AppPicker`'s item building is extracted into one `PickerMenu.populate` that both the picker and the pull-down `AddAppButton` call.
    - *Other….* `LauncherActions.chooseOtherApp` takes its completion, `(URL) -> Void`, so one chooser serves rows and the list.
    - *Reorder.* A `DragGesture` on each row: rows have a fixed pitch, the drop index is `start + round(dy / pitch)`, and the model clamps it. This needs no drag session or pasteboard, so it does not depend on drag-and-drop inside a non-activating panel (O9 unprobed).
    - *Remove.* An `.onHover` trailing button and `.contextMenu { Remove }`.
    - *The height cap (R22).* The list is a `ScrollView` with `idealHeight` equal to its natural height and `.layoutPriority(-1)`. The root keeps `fixedSize` horizontally only. `fitToContent` caps the panel's height at the visible frame minus 16 pt, so SwiftUI's flexible layout takes the deficit out of the list alone.
    - *Refits.* `MenuBarShell` also refits when `switcherRows.count` changes.
14. *`AppChoice` loses `.unassigned` (type tightening).* `setAssignment(_ choice: AppChoice?, for:)` reads nil as None, matching `assignments`' own "absent = unassigned". `addToSwitcher(_ choice: AppChoice)` then has no case to ignore.

**Depth.**

| Module | Public surface | What it hides |
|---|---|---|
| `GestureRecognizer` | `init(handMode:surface:swipes:)`, `step` → `Recognition` (2 stored fields) | Taps of 1–5 fingers; the swipe's entry (pair, sideways, 3 mm, no time limit); vertical inertness; thumb independence and re-anchoring; four named exits; travel in mm; the swipe-wide block |
| `Switcher` | failable `init`, `move(to:)` → crossed; `row`, `home`, `selected`, `selectedApp`, `position`, `stretch`, `selectsFrontmost` | R4's row rule, R5's start, R6's nearest-icon, 12 mm, hard stops and bounded rubber band with its high-water mark, R7's crossings, R11's "nothing to switch to" |
| `SwitcherList` | `apps`, `isEmpty`, `append`, `remove`, `move`, `Codable` | No duplicates ever, clamped moves, array coding with dedupe on decode |
| `ScrollFilter` | `init`, `decide`, `forgetGesture` | Per-gesture treatment (dropped, stilled, passed), momentum inheritance, the wheel exemption, unknown coasting, the mid-gesture rule |
| `TrackpadHardware` | `run` gains `swipes`; `playFeedback` gains a kind | Plus: FIFO hop, stale-session drop, scroll parsing, zeroing, the actuation table |
| `SystemActions` | gains `frontmostApp()` | `NSWorkspace`, `NSRunningApplication`, excluding itself |
| `Launcher` | gains `switcher`, `switcherRows`, 3 intents | Plus: row building at begin, R11, ticks, end effects, closing the switcher on reconcile, reconciling when the list's emptiness flips |

The public surface grows by:

- one sum type on `step`'s result;
- one case on `TrackpadEvent`;
- one argument on `run`;
- one argument on `playFeedback`;
- one query on `SystemActions`;
- two observed properties and three intents on `Launcher`.

**Concurrency** (one writer per field).

- *Frame thread:* the recognizer as today. Each session's `blocking` flag is written before `deliver`, so the swipe-wide block is in effect before main knows a swipe began.
- *Tap thread:* the `ClickFilter` and `ScrollFilter` mutexes, each written only there, taken one at a time after the flag read.
- *Main:* `Launcher.switcher` is written only by `swipe(_:)` and by `reconcile()`. `MultitouchTrackpads.runs` is written only by `run`. Every field the presenter's layers touch is main-only.

#### Module map

```
LauncherCore     (Foundation, Observation)   Gesture (+ five) · Recognized · SwipePhase · SwipeEvent · Recognition (event) ·
                                              GestureRecognizer (+ resting, swiping, Pair, Swipe, swipes flag) ·
                                              GestureRules (+ switcherStepMM, switcherMaxStretch, switcherPushStepMM) ·
                                              Switcher · SwitcherList · SwitcherRow · Settings (+ switcherList, tolerant init) ·
                                              AppChoice (no .unassigned) · PickerItem (+ listed) · InstalledApps.addMenu ·
                                              ScrollEvent · ScrollVerdict · ScrollFilter · ClickFilter (unchanged) ·
                                              ports: TrackpadEvent (+ swipe), Haptic, TrackpadHardware (run + swipes, playFeedback(kind)),
                                              SystemActions (+ frontmostApp) · Launcher (+ switcher, switcherRows, list intents)
LauncherPlatform                              MultitouchTrackpads (main-queue hop, run generation, actuation per Haptic) ·
                                              DeviceSession (delivers TrackpadEvent) · ClickTap (TapEvent, scroll in mask, ScrollFilter,
                                              ScrollEvent parsing, ScrollVerdict.apply zeroing) · WorkspaceActions (+ frontmostApp)
LauncherUI                                    SwitcherPresenter + SwitcherPanel (AppKit/CA, glass) · AppIcons (side) · SwitcherSection ·
                                              SwitcherListRow · AddAppButton · PickerMenu (shared item building) · LauncherView (5 rows,
                                              section, cap, copy) · LauncherPanel.fitToContent (height cap) · MenuBarShell (presenter,
                                              refit on list count) · LauncherActions.chooseOtherApp(then:)
TrackpadLauncher app target                   unchanged · assets/gesture-5.svg, assets/swipe.svg (drawn during implementation)
Tests                                         LauncherCoreTests: recognizer, Switcher, SwitcherList, ScrollFilter, addMenu, World seam,
                                              SourcePolicyTests; InMemoryTrackpads (swipe delivery, lightTicks, scroll), RecordingSystemActions
                                              (frontmost), TouchScript (land, slide, lift, press, thumb re-land), World (play, swipe,
                                              makeFrontmost) · LauncherPlatformTests: scroll parse, mask, zeroing
```

#### LauncherCore: recognition

```swift
/// One of the five tap gestures, named by finger count.
public enum Gesture: Int, CaseIterable, Codable, CodingKeyRepresentable, Sendable {
    case one = 1, two, three, four, five
    /// nil outside 1...5: a six-finger tap is not a gesture.
    public init?(fingerCount: Int) { self.init(rawValue: fingerCount) }
    public var fingerCount: Int { rawValue }
}

/// A swipe's progress as the frame thread reports it.
public enum SwipePhase: Equatable, Sendable {
    /// Two fingers under an anchored thumb moved sideways past 3 mm. Travel is 0 here.
    case began
    /// Sideways movement of the two fingers' midpoint since `began`, in trackpad millimetres, positive to the right in
    /// both hand modes. Sent only when it changed.
    case moved(travelMM: Double)
    /// The first of the two fingers lifted: open the selection.
    case ended
    /// A finger landed outside the anchor corner, or a press reached apps: open nothing.
    case cancelled
}

/// A swipe phase on a specific trackpad (its haptics play there; its switcher belongs to it).
public struct SwipeEvent: Equatable, Sendable {
    public let phase: SwipePhase
    public let trackpad: TrackpadID
}

/// What one frame produced, if anything. A frame never both fires a tap and moves a swipe.
public enum Recognized: Equatable, Sendable {
    case tap(Gesture)
    case swipe(SwipePhase)
}

/// What one frame meant on one trackpad.
public struct Recognition: Equatable, Sendable {
    public let event: Recognized?
    /// This trackpad's half of click blocking and scroll suppression: true for the whole of a swipe; otherwise a
    /// thumb this recognizer saw land less than 3 s ago is still anchored and another contact is down.
    public let blocksClicks: Bool

    public var fired: Gesture? { if case .tap(let gesture)? = event { gesture } else { nil } }
    public var swipe: SwipePhase? { if case .swipe(let phase)? = event { phase } else { nil } }
}

package enum GestureRules {
    // … unchanged …
    /// Icons are this far apart in finger travel; the selection is the nearest icon.
    static let switcherStepMM = 12.0
    /// The most the highlight's rubber band shows past an end, in icons.
    static let switcherMaxStretch = 0.2
    /// A push past an end must go this much further than its high-water mark to stretch again (finger jitter).
    static let switcherPushStepMM = 0.5
}

public struct GestureRecognizer: Sendable {
    /// `swipes`: false while the switcher list is empty; a pair's drag then spoils like any drag (R11).
    public init(handMode: HandMode, surface: SurfaceSize, swipes: Bool = true) { fatalError("not implemented") }

    public mutating func step(_ frame: TouchFrame) -> Recognition {
        // Per-frame sets exactly as today: isFirstFrame, before, down, reused, lifted, landed; defer previouslyDown.
        //
        // Anchor check as today, but only for the anchored states (state.anchor is nil for .idle and .swiping):
        //   anchor lifted or outside holds → .idle
        //
        // switch state
        // .idle, .armed, .spoiled: unchanged.
        //
        // .tapping(anchor, tap):
        //   drop lifted ids from tap.down; joining = landed minus the anchor
        //   pair = swipes ? Pair(tap, joining: joining) : nil
        //   .click press                                  → .spoiled(anchor)
        //   let move = Self.drag(of: tap.fingers, in: down): the farthest finger, if past 3 mm
        //     pair != nil && move.isSideways              → .swiping(Swipe(pair, down: down, thumb: anchor)); event .swipe(.began)
        //     otherwise                                   → .spoiled(anchor)
        //   past maxTapDuration                           → pair.map { .resting(anchor, $0) } ?? .spoiled(anchor)
        //   tap.down empty                                → fire as today: event = Gesture(fingerCount:).map(Recognized.tap)
        //   otherwise                                     → join landings as today
        //
        // .resting(anchor, pair):  (fires nothing, ever)
        //   .click press, a pair finger lifted, or any other non-anchor contact down → .spoiled(anchor)
        //   let move = Self.drag(of: pair.fingers, in: down)
        //     move.isSideways                             → .swiping(Swipe(pair, down: down, thumb: anchor)); event .swipe(.began)
        //     otherwise                                   → .spoiled(anchor)
        //
        // .swiping(var swipe):  (the thumb plays no part)
        //   swipe.thumb = nil if it lifted or left holds; while nil, the first contact landed in admits becomes
        //     Anchor(id, landedAt: frame.time); a contact already down is never adopted
        //   after = swipe.thumb.map(State.spoiled) ?? .idle   — "nothing further until every non-thumb finger has lifted"
        //   .click press                                  → after; event .swipe(.cancelled)    (a .blocked press: nothing)
        //   a pair finger in lifted                       → after; event .swipe(.ended)
        //   a contact landed outside admits               → after; event .swipe(.cancelled)
        //   otherwise: travel = (pair midpoint x − swipe.startMidX) × surface.widthMM
        //              travel != swipe.travelMM → swipe.travelMM = travel; event .swipe(.moved(travelMM: travel))
        //              state = .swiping(swipe)
        //
        // blocksClicks = state is .swiping ? true : today's expression over state.anchor (unchanged)
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
        /// Normalised x of the midpoint; nil if either finger is not down.
        func midX(in down: [TouchID: Touch]) -> Double? { fatalError("not implemented") }
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
        var isSideways: Bool { abs(dxMM) > abs(dyMM) }
    }

    /// The farthest-moved finger's displacement, when it is more than `dragThresholdMM`.
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

#### LauncherCore: the switcher, the list, settings, menus

```swift
/// The switcher during one swipe. The row is fixed when the swipe begins; everything else follows the travel.
public struct Switcher: Equatable, Sendable {
    /// Left to right: the frontmost app first when the list lacks it, then the list's present apps in list order.
    /// Always at least two icons.
    public let row: [AppEntry]
    /// The frontmost app's index: the selection at travel 0.
    public let home: Int
    public private(set) var travelMM: Double = 0
    let trackpad: TrackpadID
    /// Signed icons past an end at this push's high-water mark; 0 while inside the row.
    private var peakExcess: Double = 0

    /// nil when the row would hold nothing besides the frontmost app (R11). `listed`: the list's present apps, in order.
    package init?(listed: [AppEntry], frontmost: AppEntry, trackpad: TrackpadID) {
        // row = listed holds frontmost.bundleID ? listed : [frontmost] + listed
        // home = index of frontmost.bundleID in row; guard row.count >= 2
        fatalError("not implemented")
    }

    /// Returns how many icons the selection crossed: one light tick each.
    package mutating func move(to travelMM: Double) -> Int {
        // before = selected; self.travelMM = travelMM
        // excess = unclamped position − position (icons)
        // inside the row, or past the other end than peakExcess   → peakExcess = excess
        // past the same end, further than |peakExcess| by ≥ switcherPushStepMM / switcherStepMM → peakExcess = excess
        // return |selected − before|
        fatalError("not implemented")
    }

    /// The nearest icon, never past an end: home + round(travel / 12 mm), half away from zero, clamped.
    public var selected: Int { fatalError("not implemented") }
    public var selectedApp: AppEntry { row[selected] }
    /// Lifting here is a silent no-op (R8).
    public var selectsFrontmost: Bool { selected == home }
    /// Where the highlight rests, in icons: home + travel / 12 mm, clamped to the row. Between two icons it sits
    /// between them in proportion (R6).
    public var position: Double { fatalError("not implemented") }
    /// The rubber band past an end, in icons, signed: maxStretch × (1 − 1 / (1 + |peakExcess| / maxStretch)).
    /// Grows only while a push extends; the shell springs it back to `position`.
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
    /// Moves the app to `index`, clamped into the list (R20).
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
    /// saved by an older build keeps its assignments (F22).
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

public enum PickerItem: Equatable, Sendable {
    case app(AppEntry, checked: Bool)
    /// Already in the switcher list: shown checked, cannot be chosen.
    case listed(AppEntry)
    case divider
    case other
    case unassigned
}

extension InstalledApps {
    /// The switcher's Add app… menu: recent, divider, others, divider, Other…; no None. Listed apps are `.listed`.
    public func addMenu(listing listed: Set<BundleID>) -> [PickerItem] { fatalError("not implemented") }
}
```

#### LauncherCore: scroll suppression

```swift
/// A scroll event as suppression needs it. Parsed in the tap; no event-system type crosses.
public enum ScrollEvent: Equatable, Sendable {
    /// Line-based, no phases: a scroll wheel. Never suppressed (R12).
    case wheel
    /// Fingers on a surface: a trackpad or a Magic Mouse.
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
/// device; `trackpadBlocking` is the same merged flag, read when the event arrives.
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

    /// The system disabled the tap; events may have passed unseen. Forget the gesture in progress.
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
    /// Launcher itself.
    func frontmostApp() -> URL?
}

@MainActor @Observable public final class Launcher {
    public private(set) var rows: [GestureRow] = []
    /// The switcher list as the window shows it, in switcher order. Resolved with `rows`.
    public private(set) var switcherRows: [SwitcherRow] = []
    /// Non-nil exactly while a swipe shows the switcher. Written only by swipe events and `reconcile()`.
    public private(set) var switcher: Switcher?
    // … everything else as today …

    /// App picker. nil = None.
    public func setAssignment(_ choice: AppChoice?, for gesture: Gesture) { fatalError("not implemented") }
    /// Add app… and its Other…: appends; an app already listed is left where it is.
    public func addToSwitcher(_ choice: AppChoice) { fatalError("not implemented") }
    public func removeFromSwitcher(_ app: BundleID) { fatalError("not implemented") }
    /// Drag to reorder: `index` is where the row lands, clamped into the list.
    public func moveInSwitcher(_ app: BundleID, to index: Int) { fatalError("not implemented") }

    // start(): onEvent gains `case .swipe(let event): swipe(event)`.

    /// The one place a swipe becomes effects.
    private func swipe(_ event: SwipeEvent) {
        // .began:     guard switcher == nil, activity.isActive,
        //                   let url = system.frontmostApp(), let frontmost = catalog.entry(at: url)
        //             listed = settings.switcherList.apps.compactMap(catalog.locate)          — missing apps left out (R4)
        //             switcher = Switcher(listed: listed, frontmost: frontmost, trackpad: event.trackpad)   — nil: R11
        // .moved(t):  guard var open = switcher, open.trackpad == event.trackpad
        //             crossed = open.move(to: t); switcher = open
        //             crossed × hardware.playFeedback(.lightTick, on: event.trackpad)                (R7)
        // .ended:     guard let open = switcher, open.trackpad == event.trackpad; switcher = nil
        //             guard !open.selectsFrontmost                                                    (R8: silent)
        //             hardware.playFeedback(.gesture, on:); system.bringToFront(open.selectedApp); window = .closed
        //             — no launch animation
        // .cancelled: if switcher?.trackpad == event.trackpad { switcher = nil }                    (R9)
        fatalError("not implemented")
    }

    // reconcile(): … hardware.run(active ? connected : [], handMode:, blockClicks: active && granted,
    //                             swipes: !settings.switcherList.isEmpty); switcher = nil
    // fire(_:): playFeedback(.gesture, on:) — otherwise unchanged
    // resolveRows(): also switcherRows = settings.switcherList.apps.map { SwitcherRow(assigned: $0, present: catalog.locate($0)) }
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
public func playFeedback(_ haptic: Haptic, on trackpad: TrackpadID) { fatalError("not implemented") }   // .gesture 6, .lightTick 3 (by feel)

// DeviceSession: `deliver: @Sendable (TrackpadEvent) -> Void`; receive writes `blocking` first, then
//   .tap(g) → .gesture(GestureEvent(gesture: g, trackpad:)); .swipe(p) → .swipe(SwipeEvent(phase: p, trackpad:))

// ClickTap.swift (the only file that may say scrollWheel)
/// Everything the tap is told about, parsed.
enum TapEvent: Equatable {
    case pointer(PointerEvent)
    case scroll(ScrollEvent)
    /// Buttons, drags, pressure (34) and scroll (22). A test parses one synthetic event of every listed type.
    static let tapTypes: [CGEventType] = [/* today's ten */ .scrollWheel]
    static var tapMask: CGEventMask { fatalError("not implemented") }
    init?(_ type: CGEventType, _ event: CGEvent) { fatalError("not implemented") }
}
extension ScrollEvent {
    /// isContinuous 0 → .wheel; scrollPhase ≠ 0 → .fingers; momentumPhase ≠ 0 → .momentum; else .unphased.
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
        // panel = SwitcherPanel() — created now, so a swipe never pays the first window's cost
        // Observations({ launcher.switcher }) → render(_:)
        // Observations({ launcher.switcherRows }) and effectiveAppearance KVO → icons.renderOffMainActor(present apps)
        fatalError("not implemented")
    }

    /// nil → hide: fade ≤ 150 ms, orderOut from the completion unless shown again (Reduce motion: at once).
    /// Newly non-nil → lay out the row's icon layers, size from the icon count, centre on the pointer's display,
    /// orderFrontRegardless.
    /// Always → highlight x = position × 100 pt with actions disabled; selected icon 1.12× with its name below;
    /// stretch grew → additive CASpringAnimation from stretch × 100 pt to 0 (none under Reduce motion).
    private func render(_ switcher: Switcher?) { fatalError("not implemented") }
}

/// The launch overlay's configuration (F26) around an NSGlassEffectView holding 80 pt icon layers 20 pt apart, a glass
/// highlight slightly larger than an icon, and the name label. Never key, never activating, click-through.
final class SwitcherPanel: NSPanel { }

// AppIcons(side: CGFloat): today's 16 pt cache, parameterised; the presenter holds an 80 pt one. Its icon lookup for the
//   switcher: cached → the running app's icon (the frontmost, F4) → drawn on the spot.
// SwitcherSection: illustration "swipe" mirrored in left hand, "Swipe to switch apps", rows, AddAppButton (R16, R21).
// SwitcherListRow: 16 pt icon + name, or greyed "<name>  not found"; hover → trailing remove button; context menu
//   Remove; DragGesture → moveInSwitcher(id, to: start + round(dy / pitch)) (R17, R19, R20).
// AddAppButton: pull-down NSPopUpButton titled "Add app…"; menuNeedsUpdate → PickerMenu.populate(addMenu(listing:));
//   .listed items checked and disabled (R18).
// LauncherView: rows (five), SwitcherSection, HandModeToggle, Divider, hint, notices, Quit; root fixedSize horizontal
//   only; the list ScrollView idealHeight = natural, layoutPriority(-1) (R22).
// LauncherPanel.fitToContent: height = min(fittingSize.height, visible.height − 16) (R22).
// MenuBarShell: refit also on switcherRows.count; iconTargets include the list's present apps.
// HintText: "… tap with 1, 2, 3, 4 or 5 fingers anywhere to launch selected app, or swipe left or right with 2 fingers
//   to switch apps" (R24). Accessibility hint: "Clicks and scrolling aren't blocked during gestures. …" (R15).
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
    // thumb that is down.
}

extension World {
    /// What the next swipe reads as frontmost; nil models "none" or Trackpad Launcher itself.
    func makeFrontmost(_ name: String?) { fatalError("not implemented") }
    /// Delivers the frames of `script` newer than any delivered on that trackpad, so scroll events can interleave.
    func play(_ script: TouchScript, on trackpad: Trackpad = .macBook14) { fatalError("not implemented") }
    /// A World with Safari, Mail, Slack and Notes installed, Mail, Slack and Notes listed in that order, Safari frontmost, started.
    static func switcherWorld(accessGranted: Bool = false) -> World { fatalError("not implemented") }
    /// Thumb at (10, 10), two fingers down, each slide in turn (mm, positive right), then the fingers lift unless `lift` is false.
    func swipe(_ slidesMM: Double..., lift: Bool = true, on trackpad: Trackpad = .macBook14) { fatalError("not implemented") }
}

// InMemoryTrackpads: run(_:handMode:blockClicks:swipes:) builds recognizers with `swipes`, arms ClickFilter and
//   ScrollFilter together; touch delivers .gesture and .swipe inline; playFeedback records `feedback` (gesture) and
//   `lightTicks`; `scroll(_ event: ScrollEvent) -> ScrollVerdict` decides on the merged flags the last frames left
//   (.pass when no tap is armed) and records `scrollVerdicts`; inject(_ event: SwipeEvent) models a stale delivery.
// RecordingSystemActions: `var frontmost: URL?`; frontmostApp() returns it.

// SourcePolicyTests
//   banned:   − Entry(token: "scrollWheel", rule: "R6 never scrolling")
//             ~ Entry(token: "ScrollWheel", rule: "006 R12 scroll events only by their Swift names, in the tap")
//   confined: + Confined(token: "scrollWheel", onlyIn: "ClickTap.swift", rule: "006 R12 scroll suppression in the one tap")
//   The kept-token pin and the overlap check are unchanged; they pass as is.
```

**Requirement trace and seams.**

| R | Carried by | Verified at |
|---|---|---|
| R1 | `Gesture.five`; `init?(fingerCount:)` nil above 5 | Recognizer: five → `.five`, rolling five → `.five`, six → nothing (amends `fiveFingerTapFiresNothing`, `fiveFingersInARollingTapFireNothing`). World: Slack, not Spotify; haptic and animation |
| R2 | `Gesture.allCases` rows; `gesture-5.svg` | World: five rows, all `.unassigned` (amends `PersistenceTests` counts). Illustration and mirroring: manual |
| R3 | `.tapping` drag check → `.swiping`; `.resting`; `Pair`; `Move.isSideways` | Recognizer: 5 mm sideways → `.began`; 2 s rest then sideways → `.began`; 10 mm down then 20 mm right → no phase; one or three fingers → none; fingers before thumb → none; two-finger tap under 3 mm → `.two`; drifting three-finger tap → `.began` then `.cancelled`; drifting two-finger tap → `.began` then `.ended`. World: no haptic, nothing fronted |
| R4 | `Switcher.init?` row rule; `catalog.locate` at begin | Switcher (pure): frontmost in or out of the list. World: Figma trashed → left out |
| R5 | `Switcher.home` | Switcher (pure); World: `selectedApp` at begin |
| R6 | `selected`, `position`, `stretch`; travel is +x on `SurfacePoint` | Switcher (pure): 5, 7, 24, 24 then −12, +30 at the end, stretch bound. Recognizer: travel values on `.macBook14` and `.magicTrackpad`, left hand → same sign. Spring and look: manual |
| R7 | `move(to:)` → crossed; `Haptic.lightTick` | World: 36 mm → 3 `lightTicks`; 5 mm → 0. Feel against the gesture haptic: manual |
| R8 | `.ended` at the first pair lift; `Launcher.swipe(.ended)` | Recognizer: one finger lifts → `.ended`, later frames silent until all lift. World: Slack fronted, `feedback` once, no animation, window closed; frontmost selected → nothing, window stays; thumb lifted → still fronted |
| R9 | Exits `.click`, foreign landing; `.blocked` ignored; optional thumb | Recognizer: thumb slides out, re-lands → `.ended`; third finger → `.cancelled`; `.click` → `.cancelled`; `.blocked` → continues. World: no access + press → nothing fronted; access + press → `[.drop, .drop]`, fronted |
| R10 | `SwitcherPresenter`, `SwitcherPanel` (F26 configuration), AppIcons 80 pt | World: `switcher` non-nil while up, nil at end or cancel. Glass, sizes, display, full screen, focus, dark mode, Reduce motion, ≤ 200 ms: manual |
| R11 | `Switcher.init?` nil; `run(swipes:)`; `activity` guard; frontmost nil → none | World: empty list → recognizer never begins (no blocking); only frontmost → `switcher == nil`; Tap to click on → nothing |
| R12 | `ScrollFilter` on the R4 flag; `.wheel`; no tap without access | ScrollFilter table. World `scroll`: within 3 s → `.drop`; after 4 s → `.pass`; thumb lifted → `.pass`; wheel → `.pass`; no access → `.pass` and the switcher works. Real pages and a real wheel: manual |
| R13 | `blocksClicks` true in `.swiping` | Recognizer: true from `.began` to `.ended`, thumb or no thumb, after 4 s. World: late swipe press → `[.drop, .drop]`; late swipe scroll → `.pass` then `.passStill` |
| R14 | Treatment inherited by momentum, never escalated | ScrollFilter table; World: flick in the window → momentum `.drop`; coasting then thumb lands → `.pass` |
| R15 | Accessibility hint copy | Manual (rendered copy) |
| R16 | `SwitcherSection`, `swipe.svg`, order in `LauncherView` | Manual (layout, mirroring, light and dark) |
| R17 | `switcherRows` resolved with `rows`; `present == nil` = missing | World: order matches the switcher row; trash → `present == nil`; restore and `openWindow` → present |
| R18 | `addToSwitcher`; `SwitcherList.append`; `addMenu(listing:)`; `.listed` | Pure menu projection: `✓ Mail (disabled)`, no `None`. World: append Notes; Other… from Downloads; Other… a listed app → unchanged; an app on a tap and in the list → added |
| R19 | `removeFromSwitcher` | World: list after removal. Hover and context menu: manual |
| R20 | `moveInSwitcher`; `SwitcherList.move` | World: Notes to 0 → Notes, Mail, Slack; the next switcher uses it. Dragging in the panel: manual |
| R21 | `ForEach` over an empty `switcherRows` | World: fresh install → `switcherRows.isEmpty`. Look: manual |
| R22 | List `ScrollView` + `fitToContent` height cap; refit on count | Manual (30 apps on a 13" display) |
| R23 | `Settings.switcherList`, tolerant `init(from:)`, `SwitcherList` coding | World: relaunch keeps five-finger Slack and Notes, Mail; a record encoded by a test-local copy of today's `Settings` loads with its assignments and an empty list |
| R24 | `HintText` copy | Manual (rendered copy per hand) |

**Test handles.**

| Thing | Handle |
|---|---|
| The clock behind 400 ms, 3 s and "no time limit" | `TouchFrame.time`; `TouchScript.wait` |
| The swipe event stream | `Recognition.event` per frame (`steps.compactMap(\.swipe)`); `InMemoryTrackpads.touch` delivers it inline |
| A swipe by script | `TouchScript.land`, `slide`, `lift(.first)`, `press`, `liftThumb`, and `thumb` again; `World.play` for increments |
| The frontmost app | `RecordingSystemActions.frontmost`, `World.makeFrontmost(_:)`, nil for none or self |
| The switcher's visible state | `launcher.switcher` (row, selected, position, stretch) |
| The haptic kind | `InMemoryTrackpads.feedback` (gesture haptic) and `lightTicks` |
| Scroll events | `InMemoryTrackpads.scroll(_:)` on the frames' flags; `ScrollFilter` directly; synthetic `CGEvent(scrollWheelEvent2Source:…)` plus `setIntegerValueField` for phase, momentum and continuous in LauncherPlatformTests |
| What suppression does to an event | `ScrollVerdict.apply(to:)`: `.drop` → nil; `.passStill` → all nine delta fields read 0 and the phases are unchanged |
| A stale delivery after `run` | `InMemoryTrackpads.inject(SwipeEvent)` after a reconcile → ignored; the real generation gate: manual |
| The old settings record | A test-local `struct TodaySettings: Codable { handMode; assignments }` encoded as a binary plist into the suite |
| Presses during a swipe | `TouchScript.press()` → `pressVerdicts` |

**Existing tests this plan amends** (only the ones `how.md` names): `fiveFingerTapFiresNothing` and `fiveFingersInARollingTapFireNothing` now expect `.five`; `thumbThenNFingerTapFiresThatGestureOnce` and `aFirmTapOpensItsAppAndTheWholePressNeverReachesApps` run over 1...5; the `PersistenceTests` row counts go to 5; `PointerEventTests` covers mask bit 22 and no longer lists `.scrollWheel` under `ignoresEverythingElse`, and `everyMaskedTypeParses` parses `TapEvent`; the `RecentAppsTests.menu` projection gains `.listed`; `.unassigned` call sites become `nil`. Every other behaviour test should pass unchanged. A two-finger sideways drag is now a swipe, but it fires no tap, so `draggingFingersIsNotATapAndTheNextTapStillFires` still reads `[.two]`.

**Docs.**

- `docs/domain-model.md`:
  - *Gesture*: five tap gestures; the swipe is its own term.
  - *Tap*: a two-finger tap that slides sideways becomes a swipe.
  - *Launcher window*: five rows, the switcher section, the toggle, the hint, Quit.
  - *Feedback*: names the *gesture haptic* and the *light tick*, and the silent lift on the frontmost app.
  - *Click blocking*: trackpad and Magic Mouse scrolling are suppressed under the same rule and for the whole of a swipe; the momentum of a suppressed scroll is suppressed too; pointer movement and wheel mice never.
  - *Blocking window*: held open for the whole of a swipe.
  - *Accessibility hint*: names scrolling.
  - New entries: *5-finger gesture*, *Swipe*, *Switcher*, *Switcher list*, *Frontmost app*, *Light tick*.
- `docs/architecture.md` changes in three cross-cutting places:
  - Concurrency: "only completed gestures hop to the main actor" becomes "only recognised events hop: a fired tap, and a swipe's begin, moves and end, in frame order on the main queue, never from a replaced session".
  - Privacy: Accessibility is used "only to block trackpad clicks and suppress trackpad scrolling during gestures", and the scroll-event API is confined to the tap's file like the tap itself.
  - The tap's thread now wakes for scroll events while armed.

**Deliberately not done.**

- No timer, deadline or display link.
- No main-to-frame channel: the recognizer is never told the row.
- No device attribution of scrolls beyond `isContinuous`.
- No posting, and no synthesising of momentum or `ended` events: zeroing happens in place.
- No switcher row wider than the screen.
- No grace period at the lift.
- No launch animation on a swipe.
- No `NSRunningApplication` crosses a port.
- No pasteboard drag for reordering.
- No cap on the list.

### Synthesis decision

### Tradeoffs accepted

- We accept that a scroll gesture suppressed at any point stays suppressed until its fingers lift and its momentum ends, even if the 3 s window closes mid-gesture. In exchange, no app ever sees a broken began-to-ended bracket, and momentum follows its gesture with no clock. We read R12's "work again at once" as "the next scroll works at once", the scroll analogue of plan 002 R5's whole press.
- We accept two suppression mechanics, dropping (gesture never seen) and zeroed pass-through (gesture already seen), in exchange for apps seeing either nothing of a suppressed gesture (no overlay-scroller flash) or a complete, motionless one (no stuck elastic state). The probe verified zeroing only on a locally built event.
- We accept that a thumb landing in the corner while two fingers are already scrolling stills the rest of that scroll, because R12 says "exactly the conditions that block clicks", and a thumb landing with fingers down opens a window.
- We accept one main-queue hop per changed frame while a swipe moves (~100 Hz), plus a layer update per main turn. In exchange, the selection, ticks and effects stay pure and in the model. The work is input-driven and stops when the fingers stop.
- We accept swipes switched off while the switcher list is empty (one more `run` argument, and a reconcile when emptiness flips). In exchange, users who never fill the list keep today's scrolling past the 3 s window.
- We accept that a list holding only the frontmost app, or only missing apps, still recognises a swipe and keeps clicks and scrolling blocked for its length, with nothing on screen. Telling the frame thread that would need a main-to-frame channel.
- We accept that the switcher panel repeats the launch overlay's ~10-line panel configuration in `LauncherUI`, because `LauncherUI` does not depend on `LauncherPlatform`. The recipe is cited, not shared.
- We accept that rendering the switcher in AppKit and Core Animation is more imperative than SwiftUI. In exchange, the springs and fades are played by the render server, so no code of ours runs per display frame (architecture rule), as in the launch overlay.
- We accept that `AppChoice` loses `.unassigned` (a handful of call sites change) in exchange for intents that are total over their input.
- We accept a light tick per icon crossed, even when one frame crosses two (they merge on the actuator), in exchange for counts that match R7's "one per icon crossed".

### Alternatives considered

- **A separate `SwipeRecognizer` beside `GestureRecognizer` on the frame thread.**
  - *Exposes:* nothing new to callers. But each recognizer would need the other's facts: which fingers belong to the tap, whether the 400 ms rule ends a pair, which owns the flag. It would need either two writers of `blocking` or a merge, and a protocol between two state machines.
  - *Hides:* the swipe in a file of its own.
  - *Verdict:* rejected. It means two owners of one finger session, the same reason plan 002 rejected a second owner of the blocking decision.
- **The recognizer is told the row length and emits the selection (O2).**
  - *Exposes:* a main-to-frame channel (a second writer to recognizer configuration mid-gesture), because the row depends on the frontmost app and the catalog. The 12 mm rule would also have to be tested through frames instead of as pure math.
  - *Hides:* main-actor hops on moves that do not change the selection. The highlight needs every move anyway (R6).
  - *Verdict:* rejected.
- **The switcher as an effect behind `SystemActions` (`show`, `update`, `hide`) played by `LauncherPlatform` (O5).**
  - *Exposes:* three methods that mirror model state (callers coordinate several calls per swipe). It splits state between the model (selection) and the adapter (what is shown). Tests would read a recording fake instead of the model.
  - *Hides:* nothing the model-state shape does not also hide.
  - *Verdict:* rejected as shallow.
- **SwiftUI for the switcher's content.**
  - Declarative, with `glassEffect` and environment Reduce motion. But its springs and fades are interpolated in-process per display frame, which the architecture's animation rule avoids. The overlay precedent is Core Animation.
  - *Verdict:* kept for the window, not used for the switcher.
- **Delivery by `Task { @MainActor }` (observed order), or a coalescing mailbox (O3).**
  - The first rests on undocumented ordering (F6).
  - The second needs a field written by two threads (producer sets, consumer clears).
  - Self-describing events cannot make an `ended` that overtakes its `began` harmless without a remembered set of swipe IDs.
  - *Verdict:* the documented FIFO queue plus a generation gate is the simplest correct choice.
- **Suppress by dropping only (O4).**
  - *Upside:* simplest.
  - *Downside:* when suppression starts mid-gesture (a late swipe, or a thumb landing mid-scroll), apps keep an open scroll gesture with no `ended`.
- **Suppress by zeroing only (O4).**
  - *Upside:* brackets always close.
  - *Downside:* a gesture blocked from its first event would still show apps an empty gesture (overlay scrollers flash).
  - *Verdict:* the per-gesture treatment combines the two failure-free halves.
- **Per-event scroll decisions with no memory.**
  - Fails R14 by construction, because momentum arrives after the flag is false (F18).
- **Recognise swipes regardless of the list.**
  - Simpler `run`, but it suppresses scrolling for every user who never uses the switcher (R11 says "do nothing").
- **`List` with `.onMove`, or `.draggable` and `.dropDestination`, for reordering (O9).**
  - Both depend on unprobed drag behaviour in a non-activating key panel, and `List` brings its own chrome into the glass card.
  - A `DragGesture` over fixed-pitch rows needs neither.
- **A `SwiftUI ViewThatFits` or an observable height cap for R22 (O7).**
  - `ViewThatFits` picks by fitting the proposal, which `fittingSize` makes unbounded.
  - An observable cap written in `refit` races SwiftUI's asynchronous update.
  - Capping the panel frame and letting one flexible child absorb the deficit uses SwiftUI's layout as designed.

### Open questions and risks

- Is gating swipes on a non-empty switcher list the intended reading of R11 ("a sideways two-finger movement MUST do nothing")? Without the gate, an upgrading user with an empty list gets scrolling suppressed for any anchored-thumb sideways scroll, for its whole length.
- R6 measures travel from where the swipe began, so with fingers moving together the first selection change comes about 9 mm after the fingers landed (3 mm to begin, then 6 mm). Should travel instead count from the landing midpoint (6 mm from landing)?
- Is "a scroll suppressed at any point stays suppressed until its fingers lift" acceptable for R12's "scrolling MUST work again at once"? The alternative, resuming mid-gesture, shows apps `changed` events without a `began`.
- R12 read literally stills an in-progress two-finger scroll when a thumb lands in the corner. Should a thumb that lands while two fingers are already scrolling open no scroll suppression (as R14 already protects momentum)?
- When the frontmost app cannot be read (or is Trackpad Launcher, only while Other… is open), the swipe shows nothing. Is that right, or should the switcher open with the selection on the first icon?
- Does actuation 3 feel right as the light tick next to 6? The meaning of `actuatorActuate`'s other arguments is unknown (`how.md`).
- What should happen when two fingers lift in the same frame that a third lands? This design ends the swipe (opening the selection), and a delivered click wins over both (cancel).
- A swipe on a second trackpad while the first one's switcher is up is ignored on screen but still blocks on its own pad. Is that acceptable?
- Downgrade: an older build reading a record with a `5` key or `switcherList` fails to decode and loads defaults. Should the plan say so?
- Plan text gaps that `why.md` found are still open. Plan 002 R9 ("MUST NOT read, record or change … scrolling") is overridden but not named in the amendments, and `docs/architecture.md`'s Accessibility sentence changes.
- *Risk:* zeroed deltas were verified only as a field round trip on a local event (F18). An app that computes scrolling from data outside the nine delta fields would still move. The fallback is mapping `stilled` to `.drop`, a one-line change.
- *Risk:* the `mayBegin`-before-the-flag race. If the system's scroll recognizer emits `mayBegin` before our frame sets the flag, a gesture we would have dropped is stilled instead: overlay scrollers flash, and nothing moves.
- *Risk:* a swipe's block has no cap. Its exits are a lift, a foreign landing, a delivered click, or a `run`. A swipe could stick only if the pad never sent the empty frame after the last lift, the same assumption tap firing already relies on (plan 002's open question).
- *Risk:* F4's fast frontmost icon rests on two observations. A cold `NSRunningApplication.icon` for a rarely used app may cost about 25 ms on the first swipe from it.
- *Risk:* F35's unmerged `feature/005` branch adds a switch to the launcher window, and its merge will meet this layout.

### Next implementation step

Add the `TouchScript` swipe primitives (`land`, `slide`, `lift(.first)`, `press`, thumb re-landing). Then grow `GestureRecognizer` test-first with `.resting`, `.swiping` and `Recognition.event`, against R1, R3, R8, R9 and R13 at the recognizer seam.
