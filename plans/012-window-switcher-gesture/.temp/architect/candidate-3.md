# Candidate 1: the window swipe as the swipe turned 90°

## Design

### Problem

The window swipe is the swipe turned 90°. It has the same finger session, the same blocking, end, rejoin and cancel rules, and the same selection maths. But three things are new. Its list is the frontmost app's windows. Every row change has an effect on the system: this is the first effect that happens mid-swipe. The lift re-stacks windows. On top of that, its rows want pictures, which need a second permission.

The constraints make the shape non-obvious:

- **One recognizer, no main-to-frame channel** (why Preserve 1, 3). The axis must be decided once and carried on the frame thread, and travel stays one scalar (Preserve 4).
- **What crosses the ports.** `LauncherCore` imports only Foundation and Observation, and framework types never cross a port. So AX elements, CG types and images all stay at the edges.
- **Module dependencies.** `LauncherUI` cannot import `LauncherPlatform`, yet the shell is what draws.
- **Port rules.** Every port has exactly two adapters, and anything that delivers asynchronously needs a fake a test can hold.
- **The TCC push.** It is one `notify_register`, confined to one file. The broadcast fires for Screen Capture too (F29).
- **Capture.** `CGWindowListCreateImage` is gone (F25). ScreenCaptureKit is async: 14 ms to enumerate, about 25 ms per window, 100 ms the first time (F26, F27).
- **AX calls are synchronous IPC into another app.** 0.3 to 2 ms when it answers (F8, F19), and up to the messaging timeout when it does not (F15).

The probes settle the mechanics:

- AX lists only windows on the current Space plus minimised ones (F10).
- `AXRaise` fronts and focuses a window, and also restores a minimised one (F19, F20).
- Raising windows back to front re-stacks them exactly (F22).
- A closed window's element answers -25202 (F14).
- A minimised window reports subrole `AXDialog` (F9).

### Usage (caller's view)

**The window swipe, for a contributor.**

1. *The recognizer.* At the 3 mm crossing it decides a slide's axis, once, and reports `.began(.sideways)` or `.began(.vertical)`. Everything after the begin is the one `.swiping` state.
2. *The model, at the begin.* It turns `.began(.vertical)` into a `WindowSwitcher` built from one synchronous read, `system.frontmostWindows()`.
3. *The model, while sliding.* On each row change it brings the selected visible window forward with `system.bringToFront([window])`.
4. *The model, at the lift.* It reads again and applies `WindowSwitcher.lift(now:)`.
5. *The shell.* It draws `launcher.windowSwitcher` in the top-left corner. It asks `WindowPreviews` for pictures of `previewWindows`, and shows the app icon until each one arrives. The model never sees a picture.

The Screen Recording permission sits beside Accessibility on one `Permissions` port. The launcher window's hint reads `launcher.screenRecordingHint`.

**Call site 1: the model** (`Launcher.swipe(_:)`, still "the one place a swipe becomes effects").

```swift
private func swipe(_ event: SwipeEvent) {
    switch (event.phase, shown) {
    case (.began(let axis), nil):
        guard activity.isActive else { return }
        switch axis {
        case .sideways:
            let running = system.runningApps()
            shown = Switcher(frontmost: running.frontmost, running: running.apps,
                             leavingOut: settings.assignedBundleIDs, trackpad: event.trackpad).map(ShownSwitcher.apps)
        case .vertical:
            // Always a switcher (R13, R14). The Accessibility flag is the pushed one: re-reading it here could swallow
            // the adapter's next change push.
            shown = .windows(WindowSwitcher(
                system.frontmostWindows(), accessibilityGranted: isAccessibilityGranted,
                screenRecordingGranted: isScreenRecordingGranted, trackpad: event.trackpad))
        }
    case (.moved(let travel), .apps(var open)?) where open.trackpad == event.trackpad:
        let crossed = open.follow(travel)
        shown = .apps(open)
        tick(crossed, on: event.trackpad)
    case (.moved(let travel), .windows(var open)?) where open.trackpad == event.trackpad:
        let crossed = open.follow(travel)
        shown = .windows(open)
        tick(crossed, on: event.trackpad)                                          // R12
        if crossed > 0, let window = open.selectedVisibleWindow {                  // R10
            system.bringToFront([window])
        }
    case (.ended, .apps(let open)?) where open.trackpad == event.trackpad:
        shown = nil
        liftApps(open, on: event.trackpad)                                          // today's .ended body, unchanged
    case (.ended, .windows(let open)?) where open.trackpad == event.trackpad:
        shown = nil
        guard open.listsWindows else { return }                                    // a notice row: silent (R13, R14)
        let lift = open.lift(now: system.frontmostWindows())                       // the second read (R11)
        if lift.playsHaptic {
            hardware.playFeedback(.gesture, on: event.trackpad)
            window = .closed
        }
        if !lift.bringForward.isEmpty { system.bringToFront(lift.bringForward) }
    case (.cancelled, let open?) where open.trackpad == event.trackpad:
        shown = nil                                                                 // R15: no effect, silent
    default:
        return
    }
}
```

**Call site 2: the shell** (`WindowSwitcherPresenter`).

```swift
for await shown in Observations({ launcher.windowSwitcher }) { render(shown) }

private func render(_ switcher: WindowSwitcher?) {
    guard let switcher else {
        previews.discard()
        panel.hide { [panel] in panel.clearRows() }       // R17: the pictures leave with the rows
        return
    }
    if !panel.isShown || switcher.content != laidOut { open(switcher) }
    panel.select(position: switcher.position, stretch: switcher.stretch)
}

private func open(_ switcher: WindowSwitcher) {
    let screen = displayUnderPointer()                                      // R5: the pointer's display
    let visible = screen?.visibleFrame ?? .zero                             // R5: below the menu bar
    let layout = WindowColumnLayout(rowCount: switcher.rowCount, availableHeight: visible.height)
    panel.layOut(rows(of: switcher), icon: switcher.app.map(icons.icon(forSwitcher:)), layout: layout,
                 topLeft: CGPoint(x: visible.minX, y: visible.maxY))
    laidOut = switcher.content
    previews.capture(switcher.previewWindows, fitting: layout.previewPixels(scale: screen?.backingScaleFactor ?? 2)) { [weak self] id, picture in
        self?.panel.showPreview(picture, for: id)                           // R6: icon until then
    }
    panel.show()
}
```

**Call site 3: the launcher window's hint** (`LauncherView`).

```swift
if let hint = launcher.screenRecordingHint {                                    // nil when granted or the setting is off
    SettingsNotice(message: Copy.screenRecordingHint, button: "Allow Screen Recording…") {
        switch hint {
        case .ask: launcher.askForScreenRecording()                              // R8: the first press asks macOS
        case .openSettings: actions.openSettings(.screenRecording)              // R8: later presses
        }
    }
}
```

**Call site 4: the tests** (the recognizer seam and the `World` seam).

```swift
@Test(arguments: [(dx: 2.9, dy: 3.0, began: SwipePhase?.some(.began(.vertical))), (dx: 3.0, dy: 3.0, began: nil)])
func theFirstMovePastThreeMillimetresDecidesTheAxis(dx: Double, dy: Double, began: SwipePhase?) {
    let frames = thumb.land(fingers: 2).slide(byMM: (dx, dy)).lift().frames
    #expect(phases(frames, swipes: [.sideways, .vertical]).first == began)
}

@Test func slidingOneRowDownBringsMailForwardAndLiftingKeepsIt() {
    let world = World.windowWorld(visible: ["Docs", "Mail", "News"])     // Safari frontmost, Accessibility allowed
    let hand = world.windowSwipe(3.5, 12, lift: false)                 // mm down: 3.5 begins, 12 is one row
    #expect(world.launcher.windowSwitcher?.titles == ["Docs", "Mail", "News"])   // `titles`: a test-only extension
    #expect(world.system.windows.frontToBack == ["Mail", "Docs", "News"])    // R10, before the lift

    world.system.windows.close("News")                                  // a window closes between frames
    world.play(hand.lift())

    #expect(world.hardware.feedback == [Trackpad.macBook14.id])         // R12
    #expect(world.system.windows.frontToBack == ["Mail", "Docs"])       // R11
}
```

### Shape

**Data structures first.** There are five core data structures:

- **`SwipeAxis`** is decided on the frame thread and carried by `.began`. It is fixed in the recognizer's `Swipe`, and it selects which component of the accelerated cursor delta becomes travel.
- **`AppWindows`** is one read of the frontmost app's windows, already split into `visible` (front to back) and `minimised`. This shape makes "minimised after visible" a construction, not a sort.
- **`WindowSwitcher`** is a value fixed at begin. Its `Content` is either `.windows` (1 to 10 rows) or `.notice` (one row), so every switcher has at least one row by construction. It holds a `Selection` extracted unchanged from `Switcher` (per **model-the-domain**: one selection policy, two switchers).
- **`ShownSwitcher`** is one stored enum in the model, `.apps(Switcher)` or `.windows(WindowSwitcher)`. Both switchers showing at once is unrepresentable (per **type-system-discipline**). `launcher.switcher` and `launcher.windowSwitcher` derive from it.
- **`WindowLift`** is a pure function of the switcher and the second read. It gives the front-to-back windows to bring forward and the haptic.

Trace of the access paths:

- **Begin.** One read builds rows and identities (`WindowID`).
- **Each row change.** Selection index to row to `WindowID`, then one raise.
- **Lift.** The second read gives `open` (a set) and `current` (front-to-back ids). A pure suffix check over at most 10 ids then gives the shortest prefix of the target order to bring forward. In the common case this prefix is empty, because the mid-swipe raises already left the target order.

**Load-bearing decisions:**

1. **One state machine, axis as data** (Preserve 1, Avoid 1). `swipes: Set<SwipeAxis>` replaces `swipes: Bool` on the recognizer, `TrackpadHardware.run`, and `Run`.
   - The pair exists iff the set is non-empty, so `.resting` and "no time limit" hold for either kind (R1, and R16 "swipe off, window swipe on").
   - `beginOrSpoil` stays the single decision point.
   - `[.sideways]` is exactly today's rule, which keeps the old vertical-spoil tests as R16 tests.
   - Blocking, cancel, end and rejoin are shared by construction (R15).
2. **Travel along the begin's axis.** `PointerCurve.cursorPoints` returns both components scaled by the one multiplier (F3; y by symmetry, O1). The recognizer keeps the begin's axis component. 100 points per step for both switchers (R9). Downward is positive, so sliding down moves to the next row in both hand modes.
3. **System reads and effects beside their pairs on `SystemActions`** (Preserve 7, Avoid 6). `frontmostWindows()` sits beside `runningApps()`, and `bringToFront(_ windows:)` beside `bringToFront(_ app:)`.
   - The real read lives in a small `FrontmostAppWindows` platform type that tests can construct alone (the `RunningAppsReader` precedent).
   - The read is synchronous on the main actor, bounded by a process-wide 100 ms AX messaging timeout set once (F15), with no async port. It costs 1 to 2 ms for an app that answers, so a two-phase begin would hide nothing.
4. **Identity is the window server's number, branded** (`WindowID(rawValue: UInt32)`), parsed at the adapter. This follows the `TrackpadID` precedent.
   - The number comes from `_AXUIElementGetWindow` through `dlsym` (F12), with frame-and-title matching against the window list when the symbol is missing.
   - It is stable across the begin and lift reads, and it is the same number ScreenCaptureKit keys windows by (F26), so the shell can match previews without any AX type.
   - The adapter keeps the AX elements of its latest read keyed by `WindowID`, so effects need no second lookup. It is idempotent state with one writer (main), replaced by every read.
5. **The lift is pure and convergent** (per **make-operations-idempotent**, Risk 4). It recomputes the target order and the shortest bring-forward prefix from a fresh read, so it does not depend on what the mid-swipe raises did.
   - Bringing a prefix forward back to front re-stacks exactly (F22).
   - Lifting on the front window restores the original order silently, even if a frame skipped rows.
   - A selected window that has closed changes nothing (F14).
6. **Previews are a shell concern, like icons** (008 decision 9; F32).
   - The model decides only *whether* and *which* windows get previews: `previewWindows` is empty without Screen Recording or windows, and minimised rows get none.
   - `LauncherUI`'s `WindowPreviews` is the only file using ScreenCaptureKit. It captures once at open, off the main actor (R6), and keeps no picture: the panel's row layers hold each picture until the rows are cleared at hide (R17).
   - Since capture runs only when the model listed windows, a window swipe never prompts (R7).
   - The model is unaware of preview timing by construction, so its tests need no preview handle.
7. **One permissions port** replaces `AccessibilityPermission`: `Permissions` with `enum Permission { accessibility, screenRecording }`.
   - One real adapter, `SystemPermissions`, owns the one TCC registration and re-reads both permissions on every broadcast (F29, F34).
   - "Asked once" is a field of the settings record (F36). The hint's mode (`.ask` or `.openSettings`) is derived in the model; the view only dispatches.

**Interface depth.** The model learns five things:

- two `SystemActions` methods;
- one `Permissions` method pair;
- `WindowSwitcher.init`, `follow`, `selectedVisibleWindow`, `listsWindows` and `lift(now:)`.

Behind them sit:

- the AX vocabulary (roles, subroles, `AXDialog` minimised windows, full screen);
- current-Space membership;
- window-server ordering;
- id resolution with its fallback;
- timeouts and closed-element errors;
- the minimal re-stack;
- all of R3, R4, R11, R12, R13 and R14's row and lift policy.

The shell learns `previewWindows`, `content`, `position`, `stretch` and `app`. The look and the capture are behind `WindowSwitcherPanel` and `WindowPreviews`.

**Validation and trust boundaries** (per **boundary-discipline**):

- **The adapter** parses AX and CG values into `AppWindows` and drops everything that is not a normal window (R4).
- **`WindowSwitcher.init`** applies product policy: precedence of notices, the full-screen rule, the cut at 10, untitled naming.
- **Inside the core**, types are trusted. The core never re-checks minimised state or Space membership.

**What the design deliberately does not do:**

- no main-to-frame channel;
- no async window port;
- no stored window state in the model between swipes;
- no restore while sliding: the model never raises a minimised row mid-swipe (R10);
- no image in core;
- no live preview stream;
- no change to the app switcher's behaviour.

#### Module map

| Module | New or changed |
|---|---|
| `LauncherCore` | `SwipeAxis`, `SwipePhase.began(_:)`; the recognizer's `swipes: Set<SwipeAxis>`, `Move.axis`, `Swipe.axis`; `PointerCurve`/`SwipeTravel` per axis; `TrackpadHardware.run(swipes:)`; `SystemActions` +2; `Permissions` (replaces `AccessibilityPermission`); `WindowID`, `AppWindow`, `AppWindows`; `Selection` (extracted); `Switcher` (holds a `Selection`); `WindowSwitcher`, `WindowRow`, `WindowNotice`, `WindowLift`; `WindowColumnLayout`; `Settings` +2 fields; `Copy` +strings; `GestureRules.switcherMaxWindows`; `Launcher` (`ShownSwitcher`, window swipe paths, hint, setters) |
| `LauncherPlatform` | `FrontmostAppWindows` (new; the AX element family and the window list); `SystemPermissions` (renamed from `SystemAccessibilityPermission`; both permissions); `WorkspaceActions` delegates the two window methods; `FrameStream` installs travel on `.began(_)`; `MultitouchTrackpads.run(swipes:)`; `CursorTravel`/`LaunchTuning` say "per step" |
| `LauncherUI` | `OverlayPanel` (new base: the shared panel recipe, glass, show/fade-hide); `SwitcherPanel` subclasses it; `WindowSwitcherPanel`, `WindowSwitcherPresenter`, `WindowPreviews` (ScreenCaptureKit), `WindowSwitcherLook`; `displayUnderPointer()` shared by both presenters; one `AppIcons(side: 80)` shared by both; `SwitcherSection` third row; `LauncherView` hint; `SettingsPane.screenRecording`; `MenuBarShell` builds both presenters and refits on the hint |
| App target | `SystemPermissions()` in place of `SystemAccessibilityPermission()` |
| Tests | `InMemoryPermissions`; `RecordingSystemActions.windows` (a `FakeWindows` that re-stacks the way macOS does); `World.windowWorld`, `World.windowSwipe`; the fixtures take `swipes: Set<SwipeAxis>`; source-policy rows |
| Assets | `window-swipe.svg` for the third switch |

#### Recognition (`LauncherCore`)

```swift
/// Which way two fingers under an anchored thumb slide, decided once by the first movement past 3 mm (R2). More
/// sideways is a swipe (the app switcher); more up or down, a window swipe (the window switcher). A tie is
/// neither and spoils, as today.
public enum SwipeAxis: Hashable, Sendable, CaseIterable { case sideways, vertical }

public enum SwipePhase: Equatable, Sendable {
    /// Two fingers under an anchored thumb moved past 3 mm, more along `axis` than across it. Travel is 0 here.
    case began(SwipeAxis)
    /// Travel along the begin's axis since `began`, in step millimetres (12 per icon or row), positive right or down,
    /// in both hand modes. Absolute, not a delta. Sent only when it changed.
    case moved(travelMM: Double)
    /// Both fingers have lifted.                          (fixes the stale "first of the two fingers" comment)
    case ended
    /// A third finger landed outside the anchor corner while both were down, or a click reached apps.
    case cancelled
}

public struct GestureRecognizer: Sendable {
    /// `swipes`: the axes along which a pair's first drag past 3 mm begins a swipe. [] forms no pair, so every drag
    /// spoils (both settings off). [.sideways] is exactly today's rules (R16).
    public init(handMode: HandMode, surface: SurfaceSize, swipes: Set<SwipeAxis>, swaps: Bool, travel: SwipeTravel)

    // .tapping:  let pair = swipes.isEmpty ? nil : Pair(tap, joining: joining)
    // .swiping:  ... swipe.travelMM + self.travel.travel(dxMM: dxMM, dyMM: dyMM, interval: interval, along: swipe.axis)
    //            Thumb, rejoin, cancel, end and both blocking flags are untouched (R15).

    /// The single place a slide's direction is decided.
    private func beginOrSpoil(
        _ pair: Pair?, _ move: Move, _ anchor: Anchor, _ down: [TouchID: Touch], _ time: FrameTime
    ) -> (State, Recognition.Event?) {
        guard let pair, let axis = move.axis, swipes.contains(axis) else { return (.spoiled(anchor), nil) }
        let fingers = Dictionary(uniqueKeysWithValues: pair.fingers.compactMap { id in down[id].map { (id, $0.position) } })
        return (.swiping(Swipe(axis: axis, fingers: fingers, lastTime: time, thumb: anchor)), .swipe(.began(axis)))
    }

    private struct Move: Sendable {
        let dxMM: Double
        let dyMM: Double
        /// Strictly more along one axis than the other; nil on a tie.
        var axis: SwipeAxis? { abs(dxMM) > abs(dyMM) ? .sideways : abs(dyMM) > abs(dxMM) ? .vertical : nil }
    }

    private struct Swipe: Sendable {
        /// Fixed at begin. Travel counts along it only, so sideways wobble moves a window swipe nowhere (R2).
        let axis: SwipeAxis
        var fingers: [TouchID: SurfacePoint]
        var lastTime: FrameTime
        var travelMM: Double = 0
        var thumb: Anchor?
    }

    private let swipes: Set<SwipeAxis>
}

extension PointerCurve {
    /// Cursor points for one report of finger movement: both components scaled by the one speed-dependent multiplier,
    /// as `IOHIDPointerAccelerator::accelerate` does. Replaces the x-only form.
    public func cursorPoints(dxMM: Double, dyMM: Double, interval: Double) -> (x: Double, y: Double) {
        fatalError("not implemented") // TODO: today's body, returning (dx * m / v, dy * m / v)
    }
}

public enum SwipeTravel: Equatable, Sendable {
    case linear
    /// `pointsPerStep` cursor points make one step: one app switcher icon, one window switcher row.
    case cursor(PointerCurve, pointsPerStep: Double)
    /// 100 cursor points per step (R9). It is the app switcher's icon pitch; for rows the cursor match is not
    /// literal, by requirement ("whatever the rows' size on screen"), as plan 008 accepted for shrunk icons.
    public static let shippedPointsPerStep = 100.0

    /// Linear: the finger's millimetres along `axis`. Cursor: the cursor's points along `axis`, in step millimetres.
    func travel(dxMM: Double, dyMM: Double, interval: Double, along axis: SwipeAxis) -> Double {
        fatalError("not implemented")
    }
}
```

`FrameStream` changes `if recognition.swipe == .began` to `if case .began? = recognition.swipe`. The curve it installs serves both axes. `Recognition`, `Recognition.Event` and `TrackpadEvent.init` are unchanged: the axis rides in the phase, so there is no second event hop.

#### Windows, selection and the window switcher (`LauncherCore`)

```swift
/// A window for as long as it exists: the window server's number, parsed at the adapter and opaque to the core, as
/// `TrackpadID` is the multitouch device's. Never reused while the window lives. The shell keys previews by it.
public struct WindowID: Hashable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}

public struct AppWindow: Equatable, Sendable {
    public let id: WindowID
    /// As the app titles it; "" when it has none (F9).
    public let title: String
}

/// One read of the frontmost app's windows: only its normal windows (R4). The adapter leaves out panels, palettes,
/// popovers, sheets, toolbars, helpers and windows on other Spaces.
public struct AppWindows: Equatable, Sendable {
    public let app: AppEntry
    /// On the current Space, front to back in the window server's order. `visible.first` is the app's front window.
    public let visible: [AppWindow]
    /// Minimised, in the order the app lists them.
    public let minimised: [AppWindow]
    /// The front window is full screen, on its own Space.
    public let frontIsFullScreen: Bool
}

/// What a switcher's travel selects: the nearest step, hard stops at both ends, a rubber band that forgets the
/// overshoot on the turn. `Switcher`'s maths moved here unchanged; both switchers hold one.
package struct Selection: Equatable, Sendable {
    /// At least 1. One step still rubber-bands at both ends (R13).
    package let count: Int
    /// Written only by `follow` (and tests).
    package var travelMM: Double = 0
    private var reportedMM: Double = 0

    package init(count: Int) { self.count = max(count, 1) }
    /// Takes the reported travel and returns how many steps the selection crossed: one light tick each (R12).
    package mutating func follow(_ reportedMM: Double) -> Int { fatalError("not implemented") }
    package var selected: Int { fatalError("not implemented") }
    package var position: Double { fatalError("not implemented") }
    package var stretch: Double { fatalError("not implemented") }
}

// `Switcher` keeps its public surface (row, selected, selectedApp, position, stretch, selectsFrontmost, trackpad).
// It holds `package var selection: Selection`, and `follow` returns the steps crossed.

/// The window switcher during one window swipe. What it lists is fixed when the window swipe begins (R3): a window
/// that opens is not added; one that closes stays. The selection follows the travel. It always has at least one row,
/// so it always shows (R13, R14).
public struct WindowSwitcher: Equatable, Sendable {
    public enum Content: Equatable, Sendable {
        /// 1 to `switcherMaxWindows` windows: the visible ones front to back, then the minimised ones (R3).
        case windows([WindowRow])
        /// One row in place of the windows.
        case notice(WindowNotice)
    }

    public let trackpad: TrackpadID
    /// The frontmost app when the window swipe began. Its icon stands in for every preview and heads a notice.
    /// nil: there was none (R13 "without an app icon").
    public let app: AppEntry?
    public let content: Content
    /// The windows whose rows draw a preview, top to bottom. The visible rows' windows when Screen Recording was
    /// allowed at the begin; [] otherwise (R7). Minimised rows never have one (R4).
    public let previewWindows: [WindowID]
    public var rowCount: Int { fatalError("not implemented") }
    public var selected: Int { selection.selected }
    public var position: Double { selection.position }
    public var stretch: Double { selection.stretch }

    /// The app's front window when the window swipe began. nil when every listed window is minimised, or no window
    /// is listed.
    private let front: WindowID?
    package private(set) var selection: Selection

    /// The rows from one read, by this precedence:
    /// 1. no Accessibility → `.notice(.allowAccessibility)` (R14);
    /// 2. no frontmost app, or no windows (including an app that did not answer) → `.notice(.noOpenWindows)` (R13);
    /// 3. a full-screen front window → that window alone (R3);
    /// 4. otherwise the visible windows front to back, then the minimised ones, cut at `switcherMaxWindows` (R3).
    /// Untitled rows read the app's name, plus " — Window N" when there is more than one row (`Copy.windowTitle`, R6).
    /// The selection starts on row 0: the front window, or the first minimised window when there is none (R9).
    package init(_ read: AppWindows?, accessibilityGranted: Bool, screenRecordingGranted: Bool, trackpad: TrackpadID) {
        fatalError("not implemented")
    }

    /// Returns the rows crossed.
    package mutating func follow(_ travelMM: Double) -> Int { selection.follow(travelMM) }

    /// The window to bring forward now that the selection rests on it: a visible window's. nil on a minimised window
    /// (never restored while sliding, R10) and on a notice.
    package var selectedVisibleWindow: WindowID? { fatalError("not implemented") }

    /// Windows are listed, so a lift can change something. A notice's lift reads nothing and is silent.
    package var listsWindows: Bool { fatalError("not implemented") }

    /// The lift (R11, R12), given a second read of the frontmost app's windows:
    /// - `now` is nil, is another app, or the app no longer lists the selected window (it closed) → nothing is
    ///   brought forward; the haptic plays iff some window is now in front and it is not `front`.
    /// - otherwise the target is the selected window, then `front`, then the other windows visible at the begin in
    ///   their order, minus any that closed. `bringForward` is its shortest front part that, brought forward back to
    ///   front, yields that order: what is not brought forward keeps its order behind (F22). Usually [] after the
    ///   mid-swipe raises. The haptic plays iff the selected window is not `front`. That covers restoring a
    ///   minimised one, and every row when every window is minimised.
    /// Lifting on the front window therefore restores the stack as it was, silently.
    package func lift(now: AppWindows?) -> WindowLift { fatalError("not implemented") }

    // TODO private static func bringForward(current: [WindowID], target: [WindowID]) -> [WindowID]:
    //   the smallest k such that current.filter { !target.prefix(k).contains($0) }.starts(with: target.dropFirst(k));
    //   k == target.count always qualifies, so the function is total.
}

public struct WindowRow: Equatable, Sendable {
    public let window: WindowID
    /// As shown (R6).
    public let title: String
    /// Drawn dimmed with the "Minimised" badge and the app icon (R4).
    public let isMinimised: Bool
}

public enum WindowNotice: Equatable, Sendable {
    case noOpenWindows, allowAccessibility
    /// `Copy.noOpenWindows`, `Copy.allowAccessibilityToSwitchWindows`.
    public var text: String { fatalError("not implemented") }
}

package struct WindowLift: Equatable, Sendable {
    /// Front to back. [] changes nothing.
    package let bringForward: [WindowID]
    package let playsHaptic: Bool
}

/// Where the window switcher's rows and highlight sit for `rowCount` rows on a display whose visible area (below the
/// menu bar, beside the Dock) is `availableHeight` points tall. Everything shrinks by one factor when the column would
/// not fit (R5). The panel places rows and highlight through `centreY(at:)` alone.
public struct WindowColumnLayout: Equatable, Sendable {
    public static let previewHeight = 60.0          // R6
    public static let previewMaxWidth = 120.0       // R6; the slot is this wide, so titles never jump when a preview lands
    public static let rowInset = 7.0                // preview to the row's (and highlight's) edge
    public static let titleGap = 12.0
    public static let rowGap = 2.0
    public static let columnWidth = 360.0
    public static let padding = 8.0                 // the panel's edge to the rows
    public static let margin = 10.0                 // the visible area's top-left corner to the panel (R5)

    public let rowCount: Int
    /// 1 when the column fits; below 1 otherwise.
    public let scale: Double
    public init(rowCount: Int, availableHeight: Double) { fatalError("not implemented") }

    public var rowHeight: Double { fatalError("not implemented") }
    public var pitch: Double { fatalError("not implemented") }
    public var panelWidth: Double { fatalError("not implemented") }
    public var panelHeight: Double { fatalError("not implemented") }
    /// From the panel's top edge, the vertical centre of a position counted in rows from the first.
    public func centreY(at position: Double) -> Double { fatalError("not implemented") }
    /// A picture of a window `aspect` (width / height) wide: 60 tall, or less when 120 wide would not hold it.
    public func previewSize(aspect: Double) -> (width: Double, height: Double) { fatalError("not implemented") }
    /// The largest picture worth capturing, in pixels at `scale`.
    public func previewPixels(scale: Double) -> (width: Int, height: Int) { fatalError("not implemented") }
}

// GestureRules: `switcherMaxWindows = 10`; `switcherStepMM` reads "steps (icons or rows) are this far apart".
```

#### Ports (`LauncherCore`)

```swift
@MainActor public protocol TrackpadHardware: AnyObject {
    /// … `swipes`: the axes each fresh recognizer begins swipes along. Replacing the recognizers ends any swipe
    /// or window swipe in progress.
    func run(_ trackpads: [Trackpad], handMode: HandMode, blockClicks: Bool, swipes: Set<SwipeAxis>, swaps: Bool)
    // onEvent, connected(), playFeedback: unchanged
}

@MainActor public protocol SystemActions: AnyObject {
    // bringToFront(_ app:), registerLoginItem(), prepareLaunchAnimations, playLaunchAnimation, runningApps(): unchanged

    /// The frontmost app and its windows, read now. nil: no frontmost app (none, one without a bundle, or Trackpad
    /// Launcher itself). Without Accessibility, or when the app does not answer within the messaging timeout, the
    /// app with no windows. Synchronous; a few milliseconds for an app that answers, never more than the timeout per
    /// call. Remembers what it listed for `bringToFront(_:)` until the next read.
    func frontmostWindows() -> AppWindows?

    /// Brings windows the latest `frontmostWindows()` listed to the front of their app: the first in front with the
    /// keyboard focus, the rest behind it in this order, above the app's other windows. Restores a minimised one.
    /// Skips a window that has closed, and any the latest read did not list. Never touches another app's windows and
    /// never switches Spaces (only listed windows are on the current Space, F24). [] does nothing.
    func bringToFront(_ windows: [WindowID])
}

public enum Permission: Hashable, Sendable, CaseIterable { case accessibility, screenRecording }

/// The two optional permissions. Real: SystemPermissions. Test: InMemoryPermissions.
@MainActor public protocol Permissions: AnyObject {
    /// On the main actor after either permission changed, and only then. No payload; re-read with `isGranted`.
    var onChange: (@MainActor () -> Void)? { get set }
    /// Read fresh. Never prompts.
    func isGranted(_ permission: Permission) -> Bool
    /// Shows the system's prompt for it, where macOS still shows one. Returns at once; the prompt is another process's.
    func request(_ permission: Permission)
}
// `AccessibilityPermission` is deleted; its one adapter becomes `SystemPermissions`.
```

#### The model (`LauncherCore`)

```swift
public struct Settings: Codable, Equatable, Sendable {
    // … unchanged fields
    /// Whether two fingers sliding up or down under the thumb switch windows. The key is this field's name,
    /// permanently. Decoded with `decodeIfPresent ?? true`, so an upgrade leaves it on and changes nothing else (R16).
    public var isWindowSwipeOn = true
    /// The screen recording hint's button has asked macOS once (R8). Not a switch; `decodeIfPresent ?? false`.
    public var hasAskedForScreenRecording = false
    /// The axes the recognizers begin swipes along. Derived, never stored.
    public var swipeAxes: Set<SwipeAxis> { fatalError("not implemented") } // isSwipeOn → .sideways, isWindowSwipeOn → .vertical
}

public enum ScreenRecordingHint: Equatable, Sendable {
    /// The button asks macOS (the first press).
    case ask
    /// The button opens the Screen Recording page of System Settings (every later press).
    case openSettings
}

@MainActor @Observable public final class Launcher {
    /// Which switcher a swipe or a window swipe shows, if any. Written only by `swipe(_:)` and `reconcile()`.
    private enum ShownSwitcher: Equatable {
        case apps(Switcher)
        case windows(WindowSwitcher)
        var trackpad: TrackpadID { fatalError("not implemented") }
    }
    private var shown: ShownSwitcher?

    /// Non-nil exactly while a swipe shows the app switcher.
    public var switcher: Switcher? { if case .apps(let s)? = shown { s } else { nil } }
    /// Non-nil exactly while a window swipe is on: it always shows its switcher.
    public var windowSwitcher: WindowSwitcher? { if case .windows(let w)? = shown { w } else { nil } }

    public var isWindowSwipeOn: Bool { settings.isWindowSwipeOn }
    /// Set by `reconcile` from `permissions`, pushed on every change.
    public private(set) var isScreenRecordingGranted = false
    /// The launcher window's screen recording hint. nil while the permission is granted or the window swipe setting
    /// is off (R8).
    public var screenRecordingHint: ScreenRecordingHint? {
        guard settings.isWindowSwipeOn, !isScreenRecordingGranted else { return nil }
        return settings.hasAskedForScreenRecording ? .openSettings : .ask
    }
    /// Mentions the window swipe only while it is on.
    public var gestureHint: String {
        Copy.gestureHint(for: settings.handMode, swipe: settings.isSwipeOn, windowSwipe: settings.isWindowSwipeOn)
    }

    /// `access:` becomes `permissions:`.
    public init(hardware: any TrackpadHardware, preferences: any TrackpadPreferences, permissions: any Permissions,
                system: any SystemActions, catalog: AppCatalog, scanner: any AppScanner, store: SettingsStore)

    /// Window swipe switch. Saved at once; the recognizers are rebuilt, so the next slide obeys it and a window swipe
    /// in progress ends (R16).
    public func setWindowSwipe(on: Bool) { fatalError("not implemented") }

    /// The hint's `.ask` button: asks macOS once, remembers it, closes the window. Idempotent: after the first call it
    /// does nothing, and the hint offers `.openSettings`. A crash between the request and the save repeats the request,
    /// which is harmless (R8).
    public func askForScreenRecording() { fatalError("not implemented") }

    // reconcile: isAccessibilityGranted = permissions.isGranted(.accessibility);
    //            isScreenRecordingGranted = permissions.isGranted(.screenRecording);
    //            Run.swipes = settings.swipeAxes; a changed Run sets `shown = nil` (ends either kind).
    // start(): first launch prompts `permissions.request(.accessibility)` only. Never Screen Recording (R7).
    // swipe(_:): as in Usage, call site 1. `tick(_:on:)` plays one `.lightTick` per step crossed.
}

// Copy: gestureHint(for:swipe:windowSwipe:) adds ", or swipe up or down with 2 fingers to switch windows";
// screenRecordingHint = "Window previews need Screen Recording. Until it is allowed, the window switcher shows app
// icons."; noOpenWindows = "No open windows"; allowAccessibilityToSwitchWindows = "Allow Accessibility to switch
// windows"; minimisedBadge = "Minimised"; windowTitle(_:appName:position:rowCount:) -> String.
// accessibilityHint stays as it is (R14 "the existing Accessibility hint"); see Open questions.
```

#### Platform adapters (`LauncherPlatform`)

```swift
/// The frontmost app's windows over the Accessibility API and the window server's list, behind `SystemActions`.
/// Every AX call is synchronous IPC into the app, bounded by `messagingTimeout`, set once for this process. Keeps the
/// AX elements of its latest read keyed by window, so bringing to front needs no second lookup. It holds no window,
/// so its tests construct it alone. The only file with `AXUIElement` and `CGWindowList` in it.
@MainActor final class FrontmostAppWindows {
    /// An app slower than this is not answering: its read lists no windows, and bringing to front skips the rest.
    static let messagingTimeout: Float = 0.1

    private var elements: [WindowID: AXUIElement] = [:]
    private let numbering: WindowNumbering

    init(numbering: WindowNumbering = .resolved()) {
        // TODO: AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), Self.messagingTimeout)  (F15)
        // TODO: one window-list read now: 52 ms on a process's first call, about 1 ms after (F11), as
        //       LaunchOverlay pays its first window at launch.
        fatalError("not implemented")
    }

    func read() -> AppWindows? {
        // 1. NSWorkspace.frontmostApplication; nil, this process, or no bundle → nil. AppEntry via RunningApp.entry(for:).
        // 2. kAXWindowsAttribute of AXUIElementCreateApplication(pid). Per window, one
        //    AXUIElementCopyMultipleAttributeValues: role, subrole, title, minimised, AXFullScreen, position, size.
        //    Any kAXErrorCannotComplete or kAXErrorAPIDisabled → AppWindows(app:, [], [], false) and `elements = [:]`.
        // 3. The window list, on screen, excluding desktop elements, this pid, layer 0: numbers front to back (F11).
        // 4. Each window's number: `numbering`. A window with no number is left out.
        // 5. Self.sort(raw, onScreen:), then `elements` = the listed windows' elements.
        fatalError("not implemented")
    }

    func bringToFront(_ windows: [WindowID]) {
        // In reverse (back to front): an unlisted id → skip; minimised → set kAXMinimizedAttribute false (F21); then
        // AXUIElementPerformAction(kAXRaiseAction) (F19). kAXErrorInvalidUIElement (closed, F14) → skip.
        // kAXErrorCannotComplete → stop. The last raised ends in front with the keyboard focus (F19, F22).
        fatalError("not implemented")
    }

    /// The pure part, the adapter's internal seam: R4's filter and R3's order, from raw facts.
    /// Visible: role AXWindow, subrole AXStandardWindow, not minimised, and on screen now (so on this Space, F10), in
    /// the window list's order. Minimised: kAXMinimized alone, because a minimised document window reports AXDialog
    /// (F9), in AX order.
    nonisolated static func sort(_ windows: [RawWindow], onScreen: [UInt32])
        -> (visible: [AppWindow], minimised: [AppWindow], frontIsFullScreen: Bool) { fatalError("not implemented") }

    /// No private symbol: the window-list entry of this pid with the same frame, and the same title where the list names
    /// windows. nil when none, or more than one, matches.
    nonisolated static func number(of window: RawWindow, among listed: [ListedWindow]) -> UInt32? { fatalError("not implemented") }
}

struct RawWindow: Sendable { var number: UInt32?; let title: String; let role: String?; let subrole: String?
                             let isMinimised: Bool; let isFullScreen: Bool; let frame: CGRect? }
struct ListedWindow: Sendable { let number: UInt32; let frame: CGRect; let name: String? }

/// How an AX window gets its window-server number: the private `_AXUIElementGetWindow` resolved with `dlsym` from
/// the loaded HIServices (F12, the `LaunchServicesOrder` precedent), else frame matching against the list's
/// `optionAll` entries for this pid. Minimised windows are in that list off screen (F13).
enum WindowNumbering {
    case privateCall(@convention(c) (AXUIElement, UnsafeMutablePointer<UInt32>) -> AXError)
    case frameMatching
    static func resolved() -> WindowNumbering { fatalError("not implemented") }
}

/// Permissions over AX trust, the screen capture preflight and tccd's one Darwin notification. It fires for Screen
/// Capture changes too (F29), and names no service, so both are re-read on every broadcast and `onChange` runs only when
/// either changed. No polling. The only file with AXIsProcessTrusted, CG…ScreenCaptureAccess or notify_register.
@MainActor public final class SystemPermissions: Permissions {
    static let changeNotification = "com.apple.tcc.access.changed"
    public var onChange: (@MainActor () -> Void)?
    /// `granted` is injectable for the adapter's own test, which flips it and posts the notification itself.
    public init(granted: @escaping @Sendable (Permission) -> Bool = SystemPermissions.systemGranted) {
        fatalError("not implemented")
    }
    public func isGranted(_ permission: Permission) -> Bool { fatalError("not implemented") }
    /// .accessibility: AXIsProcessTrustedWithOptions with the prompt key; .screenRecording: CGRequestScreenCaptureAccess().
    public func request(_ permission: Permission) { fatalError("not implemented") }
    /// .accessibility: AXIsProcessTrusted(); .screenRecording: CGPreflightScreenCaptureAccess(), which never prompts (F28).
    public nonisolated static func systemGranted(_ permission: Permission) -> Bool { fatalError("not implemented") }
    private var lastKnown: [Permission: Bool]
    private var token: Int32 = 0
}

// WorkspaceActions: `private let windows = FrontmostAppWindows()`; frontmostWindows() → windows.read();
// bringToFront(_ windows:) → windows.bringToFront(_:).
```

#### The shell (`LauncherUI`)

```swift
/// The switchers' window: borderless, non-activating, click-through, above everything on every Space, never key,
/// around one Liquid Glass view clipped to its corners. It shows at once and hides with a 150 ms fade, unless shown
/// again meanwhile (Reduce motion: at once). The recipe and fade that `SwitcherPanel` and `SwitcherPresenter` hold
/// today move here, so both switchers share them.
class OverlayPanel: NSPanel {
    init(cornerRadius: CGFloat, content: NSView)
    private(set) var isShown: Bool
    func show()                                          // full opacity, front, drops a fade in flight
    func hide(then cleanup: @escaping () -> Void)        // fade, order out, then cleanup, unless shown again meanwhile
}

/// The window switcher's panel (R5, R6). One `NSGlassEffectView` (.regular) holding a `.clear` glass highlight and
/// one row per line: a 120 pt preview slot (picture or app icon, continuous 6 pt corners, a hairline edge), the
/// title in one truncating `NSTextField`, and a "Minimised" capsule badge under it on minimised rows, drawn at
/// `WindowSwitcherLook.minimisedOpacity`. Placed at the visible area's top-left plus `WindowColumnLayout.margin`.
final class WindowSwitcherPanel: OverlayPanel {
    enum Row { case window(WindowID, title: String, isMinimised: Bool), notice(String) }
    func layOut(_ rows: [Row], icon: NSImage?, layout: WindowColumnLayout, topLeft: CGPoint)
    /// The highlight at the continuous `position`, with actions disabled (it follows the fingers 1:1), plus an additive
    /// spring on `position.y` when `stretch` changes past an end.
    func select(position: Double, stretch: Double)
    /// Swaps the slot's icon for `picture`, sized by `layout.previewSize(aspect:)`, crossfading over
    /// `WindowSwitcherLook.previewFadeIn` (none with Reduce motion). A picture for a row not laid out is dropped.
    func showPreview(_ picture: CGImage, for window: WindowID)
    /// Removes every row layer, and with them every picture (R17).
    func clearRows()
}

/// Every look and motion number of the window switcher, in one place, to refine together later. Geometry that a
/// requirement fixes is in `WindowColumnLayout` instead, where it is tested.
enum WindowSwitcherLook {
    static let cornerRadius: CGFloat = 24
    /// Concentric with the panel: its radius minus the padding (the 26 SDK has no `cornerConfiguration`).
    static var highlightRadius: CGFloat { cornerRadius - CGFloat(WindowColumnLayout.padding) }
    static let previewCornerRadius: CGFloat = 6
    static let iconSide: CGFloat = 44
    static let minimisedOpacity: Float = 0.5
    static let titleFont = NSFont.systemFont(ofSize: 13, weight: .medium)
    static let badgeFont = NSFont.systemFont(ofSize: 11)
    static let previewFadeIn: CFTimeInterval = 0.12
    static let springStiffness = 420.0, springDamping = 22.0     // the app switcher's
}

/// Pictures of the frontmost app's visible windows, taken once when a window swipe begins (R6, R17). The app's only
/// screen capture. It holds no picture: each one goes to `ready` once and is forgotten here; the panel's row layers
/// hold it until the rows are cleared. It runs only for windows the model listed, which it lists only with Screen
/// Recording allowed, so it never prompts (R7).
@MainActor final class WindowPreviews {
    private var generation = 0
    /// Off the main actor: one SCShareableContent read of on-screen windows, then one SCScreenshotManager picture per
    /// listed window, concurrently (F26, F27). Each picture is sized to fit `fitting` while keeping the window's
    /// proportions, with no cursor and no shadow. `ready` runs on the main actor once per picture, as each finishes.
    /// A window that closed, left the screen or failed is skipped, so its row keeps the icon. A later `capture` or
    /// `discard` drops whatever the earlier one still delivers.
    func capture(_ windows: [WindowID], fitting: (width: Int, height: Int), ready: @escaping (WindowID, CGImage) -> Void)
    func discard()
}

/// Renders `launcher.windowSwitcher` and holds nothing the model holds. Owned by `MenuBarShell`, created at shell
/// init so the panel exists before any swipe (the first window's cost is already paid by `LaunchOverlay`).
final class WindowSwitcherPresenter {
    init(launcher: Launcher, icons: AppIcons)   // the 80 pt cache it shares with SwitcherPresenter
    // render/open: Usage, call site 2.
}

/// AppKit's own rule for which display holds the pointer; the nearest display when none does. Shared by both presenters.
func displayUnderPointer() -> NSScreen?

// SwitcherSection: a third row, "Swipe up or down to switch windows", illustration "window-swipe", bound to
//   launcher.isWindowSwipeOn / setWindowSwipe(on:), below "Thumb tap to swap apps" (R16).
// LauncherView: the screen recording hint after the Accessibility hint (Usage, call site 3).
// SettingsPane: `.screenRecording` → x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture.
// MenuBarShell: one AppIcons(side: 80) for both presenters; refit observes
//   (activity, isAccessibilityGranted, isSwipeOn, isWindowSwipeOn, screenRecordingHint).
```

**Look and motion, decided now and refined together later:**

- **Appearing.** The panel appears at once at full opacity, in the same movement (R6), like the app switcher.
- **The highlight.** It follows the fingers 1:1, with the app switcher's spring at the ends.
- **Previews.** They crossfade in over 120 ms.
- **Disappearing.** A 150 ms fade.
- **Reduce motion.** It drops the spring and both fades.
- **Width.** A fixed 360 pt column: the panel never changes width under the fingers, and long titles truncate (R6).

#### Test adapters (`LauncherCoreTests`)

```swift
@MainActor final class InMemoryPermissions: Permissions {
    var onChange: (@MainActor () -> Void)?
    private(set) var granted: Set<Permission>
    /// Every request, in order: a test proves a window swipe never asks (R7).
    private(set) var requests: [Permission] = []
    init(granted: Set<Permission> = [])
    func isGranted(_ permission: Permission) -> Bool
    func request(_ permission: Permission)
    /// The user flips a switch in System Settings: pushed synchronously, on a real change only.
    func set(_ permission: Permission, granted: Bool)
}

/// The frontmost app's windows as macOS holds them. `bringToFront` re-stacks the way AXRaise does (it restores a
/// minimised window), so a test reads the stack afterwards.
struct FakeWindows {
    struct Window { let id: WindowID; var title: String; var isMinimised: Bool; var isFullScreen = false }
    /// Front to back. Minimised windows are kept in the app's order among themselves.
    private(set) var stack: [Window] = []
    /// false: the app does not answer. A read lists no windows, and bringing to front changes nothing.
    var answers = true
    /// Every non-empty bringToFront call, in order.
    private(set) var broughtToFront: [[WindowID]] = []
    @discardableResult mutating func open(_ title: String, minimised: Bool = false, fullScreen: Bool = false) -> WindowID
    mutating func close(_ title: String)
    var frontToBack: [String] { get }                    // the visible windows' titles
}
// RecordingSystemActions: `var windows = FakeWindows()`. frontmostWindows() answers from `frontmost` plus `windows`;
// bringToFront(_ windows:) forwards to it.
// World: `permissions: InMemoryPermissions` (was `access`); init(…, accessGranted:, screenRecordingGranted:);
// static windowWorld(app: "Safari", visible:, minimised:, accessGranted: true, screenRecordingGranted: false);
// windowSwipe(_ slidesMM: Double..., lift:) slides y only, positive down.
// Fixtures: fired/phases/perFrame take `swipes: Set<SwipeAxis> = Set(SwipeAxis.allCases)`.
```

#### Source policy rows (`SourcePolicyTests`)

| Kind | Token | Only in / rule |
|---|---|---|
| Confined | `AXIsProcessTrusted`, `notify_register` | `SystemPermissions.swift` (renamed file) |
| Confined | `CGPreflightScreenCaptureAccess`, `CGRequestScreenCaptureAccess` | `SystemPermissions.swift`, "012 R7/R8 asked only from the hint" |
| Confined | `AXUIElement` (covers every `AXUIElement*` call and `_AXUIElementGetWindow`) | `FrontmostAppWindows.swift`, "012 R14 the window APIs have one adapter" |
| Confined | `CGWindowList` | `FrontmostAppWindows.swift`, "012 R4 the window list has one reader" |
| Confined | `ScreenCaptureKit`, `SCShareableContent`, `SCScreenshotManager` | `WindowPreviews.swift`, "012 R17 one place captures" |
| Banned | `SCStream(`, `SCRecordingOutput` | "012 R17 one picture per window, never a stream" (`SCStreamConfiguration(` does not match) |
| Banned | `CGImageDestination`, `representation(using`, `tiffRepresentation` | "012 R17 previews are never encoded or written" |
| Relabel | the "R9 only Accessibility" rows | "no Input Monitoring or event-posting access" (the old label is untrue with two permissions) |

#### Docs (Phase D)

**`docs/architecture.md`, Privacy and permissions.** Replace the first bullet with this text:

> "The app asks for two permissions, both optional. Accessibility blocks trackpad clicks, suppresses trackpad scrolling and blocks the system's desktop and Mission Control swipes during gestures, and lets a window swipe list, bring forward and restore the frontmost app's windows; it is asked for once, on first launch. Screen Recording is used only to take one small picture of each of the frontmost app's visible windows when a window swipe begins; the pictures stay in memory and are dropped when it ends, and none is ever encoded or written. It is asked for only by the screen recording hint's button, never by a gesture. The app never asks for Input Monitoring or any other permission and never reads keyboard events. Without Accessibility everything works except click blocking, scroll suppression, Dock swipe blocking and switching windows; without Screen Recording the window switcher shows app icons. The permission checks and their push, the window APIs (Accessibility elements and the window list), screen capture, the event tap and the scroll-event API are each confined to one file by the source-scan test."

Add `_AXUIElementGetWindow` to the private-symbols bullet: it is resolved with `dlsym`, confined, and falls back to frame matching.

**`docs/architecture.md`, Shape.** `LauncherUI` gains "the switchers' panels and the window previews' capture (ScreenCaptureKit, one file)". `LauncherPlatform` gains "Accessibility (window elements)".

**`docs/architecture.md`, Concurrency.** Three changes:

- The hop list reads "a swipe's or window swipe's begin, moves and end".
- A new exception: the window swipe's Accessibility reads and raises run on the main actor at its begin, row changes and lift, each bounded by a 100 ms messaging timeout, and take a few milliseconds for an app that answers.
- Window pictures join "work that runs off the main actor".

**`docs/domain-model.md`.** Add the plan's new terms:

- *Window swipe*: the swipe's rules, more up or down, with its own setting.
- *Window switcher*: placement, rows, selection, the live bring to front, the lift's order and silence rules, the one-row cases, previews.
- *Window*: R4.
- *Front window*.
- *Window swipe setting*.
- *Screen recording hint*.

Amend the existing entries:

| Entry | Amendment |
|---|---|
| *Gesture* | Lists the window swipe beside the swipe and the swap. |
| *Tap* | A pair sliding past 3 mm is a swipe or a window swipe. |
| *Swipe* | "A slide's direction is decided once, by its first movement past 3 mm; neither kind becomes the other." |
| *Swipe setting* | Speaks of sideways slides. With the window swipe setting on, an up-or-down slide is a window swipe, not a scroll. |
| *Launcher window* | Three switches and the screen recording hint. |
| *Feedback* | The window swipe's lift haptic and silence rules. |
| *Light tick* | "one per icon or row". |
| *Click blocking* and *Blocking window* | "a swipe, a window swipe or a swap series". |

#### Requirements, the signatures that carry them, and the seam each runs at

| R | Carried by | Seam |
|---|---|---|
| R1 | `GestureRecognizer.init(swipes:)`; `Move.axis`; `beginOrSpoil`; the pair formed iff `swipes` is non-empty (no time limit via `.resting`); edge filter unchanged | recognizer over `TouchScript`; `World.windowSwipe` |
| R2 | `Swipe.axis` fixed at begin; `SwipeTravel.travel(…along:)`; `.began(SwipeAxis)`; `ShownSwitcher` chosen once | recognizer; `World` (20 mm sideways in a window swipe) |
| R3 | `AppWindows.visible` and `.minimised`; `WindowSwitcher.init` (order, cut at 10, full screen); `content` is `let` | `WindowSwitcher` values; `World` with `FakeWindows.open/close` mid-swipe |
| R4 | `FrontmostAppWindows.sort` (subrole, on screen, `kAXMinimized`); `WindowRow.isMinimised`; panel dimming and badge | `sort` in `LauncherPlatformTests`; values; panel by hand |
| R5 | `WindowColumnLayout` (scale, margin, panel size); `WindowSwitcherPanel` at the visible top-left of `displayUnderPointer()`; `OverlayPanel` never key, click-through | `WindowColumnLayout` values; placement, glass, focus by hand |
| R6 | `Copy.windowTitle`; `WindowColumnLayout.previewSize`; `previewWindows`; `WindowPreviews.capture` once at open; `showPreview`; icon until then | values; pictures and truncation by hand |
| R7 | `previewWindows == []` without the permission; `Permissions.request` called only by `askForScreenRecording()`; capture confined, gated by the model | `World` + `InMemoryPermissions.requests`; relaunch by hand |
| R8 | `screenRecordingHint`; `askForScreenRecording()`; `Settings.hasAskedForScreenRecording`; `SettingsPane.screenRecording`; the TCC push | `World` + `InMemoryPermissions.set`; `SystemPermissions(granted:)` with a posted notification; the prompt by hand |
| R9 | `Selection` (shared, unchanged maths); 100 points per step; travel 0 at begin | `Selection`/`Switcher` values; `World` (12 mm per row, linear) |
| R10 | `.moved` → `selectedVisibleWindow` → `bringToFront([id])`; minimised rows never raised; closed windows skipped | `World` + `FakeWindows` (stack before the lift) |
| R11 | the second read; `lift(now:)`; `bringForward` prefix; `FrontmostAppWindows.bringToFront` restoring and raising back to front | `lift` values; `World` (toggle, all minimised, closed) |
| R12 | `follow` returns the steps crossed → light ticks; `WindowLift.playsHaptic`; no launch animation call | `World` pulses |
| R13 | `Content.notice(.noOpenWindows)` with `app` nil or not; one-step `Selection` rubber-bands; a notice's lift reads nothing | values; `World` |
| R14 | `.notice(.allowAccessibility)` takes precedence; no tap without trust (unchanged) | `World(accessGranted: false)` |
| R15 | the shared `.swiping` state; `.cancelled` → `shown = nil` with no effect | recognizer; `World` (click, third finger, thumb, rejoin) |
| R16 | `Settings.isWindowSwipeOn`, `swipeAxes`, `setWindowSwipe(on:)`, `Run.swipes`; `[.sideways]` keeps today's spoil | recognizer with each set; `PersistenceTests` (field survives; upgrade with `isSwipeOn` false) |
| R17 | `WindowPreviews` holds no picture; `clearRows()` at hide; capture once, confined; the encoder and stream bans | source scan; code review |

**Test handles for what a test cannot wait for or provoke:**

- **The clock.** The frame time is the only clock; nothing has a timer.
- **A window closing between frames.** `world.system.windows.close(_:)` between `play` pieces.
- **An app that does not answer.** `windows.answers = false`.
- **The permission changing.** `permissions.set(_:granted:)` pushes synchronously, and a test withholds the push by not calling it.
- **Previews arriving later.** The model cannot observe them by construction. The model test asserts `previewWindows`; the presenter is checked by hand.
- **A call that blocks.** The real AX timeout is checked by hand against a paused app (`kill -STOP`).

**Manual checks:**

- glass in a `.screenSaver` non-key panel, in light and dark;
- placement on two displays;
- shrink-to-fit on a short display;
- the motion;
- real `AXRaise` across apps, including Chromium and Electron;
- real pictures;
- the TCC prompt and the System Settings page;
- any relaunch macOS asks for;
- the periodic capture alert (F31).

### Synthesis decision

### Tradeoffs accepted

- We accept synchronous AX IPC on the main actor (1 to 2 ms per read or raise, up to 100 ms per call for an app that does not answer) in exchange for a one-phase begin, a synchronous model and model tests with no held reads.
- We accept a private symbol, `_AXUIElementGetWindow`, in exchange for exact window identity shared by AX, the window list and ScreenCaptureKit. Without it, frame matching may drop windows whose frames coincide.
- We accept that `WindowID` carries the window server's number, which a reader might take for a leaked CG type, in exchange for an identity that is stable across both reads and keys previews without any AX type (the `TrackpadID` precedent).
- We accept a small piece of adapter state (the latest read's AX elements) in exchange for effects that need no re-lookup. It is replaced by every read, so it cannot drift.
- We accept that ScreenCaptureKit is used in `LauncherUI`, a system read in the shell, in exchange for pictures never passing a module the model sees and no one-adapter seam at the composition root (the `AppIcons`/`NSWorkspace` precedent). Previews are therefore checked by hand and R17 by structure and review, not by a test.
- We accept renaming `AccessibilityPermission` to `Permissions`, a test-wide rename, in exchange for one TCC registration and one adapter for both permissions.
- We accept that an unanswering app reads as "No open windows".
- We accept that vertically drifting two- and three-finger taps flash the window switcher, which always shows (Risk 3).
- We accept that a frame that skips rows raises only the row it lands on: the lift's re-stack repairs the order.
- We accept that a cancel leaves the stack the mid-swipe raises made (R15 as written).

### Alternatives considered

- **A second recognizer state or event kind** (`.windowSwiping`, `TrackpadEvent.windowSwipe`). It exposes nothing new to callers, but duplicates thumb, rejoin, cancel, end and blocking handling and the event mapping. Rejected: two owners of one finger session (Avoid 1), against the "no second state machine or event hop" rule.
- **Async window reads behind a holdable port** (the `AppScanner` style). It hides IPC latency, but exposes a loading state to the model and the shell, and a lift that can arrive before the read lands. Rejected: for a 1 to 2 ms read it moves complexity onto callers instead of hiding it. The timeout bounds the bad case.
- **Previews through the model.** Either a core port pushes "ready" while the pictures stay in Platform and reach the shell through a composition-root closure, or the model keeps readiness state. The first is a seam in `LauncherUI` with one implementation; the second is model state it never decides on (008 decision 9). Either way, images still cannot cross a port. Rejected.
- **A `Windows` port plus a `ScreenRecordingPermission` port.** Two shallow ports, a second `notify_register` for the same broadcast (which needs a multi-file `Confined` row), and two protocols with one shape. Rejected for the deeper `SystemActions` pair and one `Permissions` port.
- **A full re-stack at every lift** (raise every visible window back to front). Simpler to state, but up to 11 raises on every lift, including "lifting on the front window changes nothing". Rejected for the pure shortest-prefix rule, which is usually empty.

### Open questions and risks

- Should the Accessibility hint's copy now mention switching windows, or does R14's "the existing Accessibility hint" mean it stays word for word, as this design keeps it?
- Thumb plus two fingers sliding up or down is Mission Control's shape (Risk 2). Without Accessibility the Dock-swipe filter is off, so should R14 say Mission Control may open? And has the filter's vertical case been confirmed on hardware?
- With the setting on, an anchored-thumb vertical scroll past the 3 s window becomes a window swipe (Risk 1). Is R16's switch the accepted way out? If so, 006 R12's "Scrolling returns after 3 seconds" and T68(b) should be amended to the sideways-only case.
- Since macOS 15, ScreenCaptureKit without the picker brings a periodic "bypass the private window picker" alert (F31, unverified). Is that acceptable for previews, or should previews stay off until it is checked?
- Is 100 ms the right per-call AX timeout? Below it, a busy app reads "No open windows"; above it, a hung app stalls the begin.
- If `CGPreflightScreenCaptureAccess()` stays false until a relaunch after the grant (F30), the hint stays up until then. Is that acceptable, given that R7 already allows the relaunch?
- When the front window closes and the user lifts on it, this design plays the haptic only if some other window is now in front. Is that the intended reading of R12?
- When the app opens a window in front mid-swipe, a lift on the front window brings the front window back above the new one (R11's order wins over "changes nothing"). Is that intended?

### Next implementation step

Thread `SwipeAxis` through the recognizer, `SwipeTravel`/`PointerCurve`, `TrackpadHardware.run` and `Settings.swipeAxes`, test first: today's vertical-spoil tests stay pinned under `swipes: [.sideways]`, and new tests cover `.began(.vertical)` and the tie.
