
## Design

### Problem

The window swipe is a sibling of the swipe, not a second feature beside it. Two fingers under an anchored thumb already
run through one recognizer, one finger session, one blocking rule, one event hop and one model handler, and today a
first drag past 3 mm that is not strictly sideways spoils the pair. The shape is not obvious because the window swipe
brings several firsts: the first effect on the system while the fingers still move (raising windows changes the state
the lift then acts on), the first use of the `AXUIElement` family and of a private window API
(`_AXUIElementGetWindow`), the first second permission (Screen Recording), and the first pictures of other apps'
windows, which arrive after the window swipe began and must go when it ends.

The grounding fixes these constraints, and the design honours each:
- One recognizer and one `.swiping` state; the direction is decided once, in `beginOrSpoil`; the recognizer never
  learns whether the app has windows; a window swipe with nothing to switch still runs its course blocked (`why.md`
  Preserve 1, 3; Avoid 1, 2).
- Travel crosses the port as one scalar in step millimetres, through the pointer curve installed at begin; 100 cursor
  points make a row (Preserve 4; R9).
- The list is fixed at begin; the system is read at begin and again at the lift; a window closed mid-swipe is the
  analogue of an app that quit; the lift must not depend on what the raises while sliding did (Preserve 5; Risk 4).
- `LauncherCore` imports Foundation and Observation only; framework types (`AXUIElement`, `CGImage`, `NSImage`) never
  cross a port; every port has exactly two adapters; `LauncherUI` cannot see `LauncherPlatform`
  (`docs/architecture.md` Shape; F32, F33).
- A shell asset the model never decides on stays in the shell: plan 008 put icon readiness there because routing it
  through the model "would add state the model never decides on" (`why.md` Q4).
- No timers, no polling: the TCC broadcast, user events and frames are the pushes; `notify_register` is confined to
  one file, and the broadcast names no service (F29, F34).
- AX calls are synchronous IPC bounded by a messaging timeout, set process-wide on the system-wide element (F15,
  `AXUIElement.h`); `AXRaise` fronts, focuses and restores a minimised window (F19, F20); raising back to front
  re-stacks exactly (F22); raising a window on another Space switches Spaces (F24); a closed window answers `-25202`
  (F14); a minimised window's subrole is unreliable (F9); a full-screen front window stands alone on its Space (F10);
  only ScreenCaptureKit can capture (F25); a Screen Recording preflight costs about 4 ms on the calling thread
  (check-1).

### Usage (caller's view)

**README for the next maintainer.** A slide is a *swipe* (more sideways) or a *window swipe* (more up or down). The
recognizer decides which on the frame the farthest-moved finger passes 3 mm and holds that until both fingers lift. A
window swipe's phases arrive as `.windowSwipe(phase)` through the same hop as the swipe's, and
`Launcher.windowSwipe(_:)` is the one place a window swipe becomes effects. It reads the frontmost app's windows with
`system.frontmostWindows()`, beside `runningApps()` on `SystemActions`, and builds a `WindowSwitcher` value whose
content is fixed for the window swipe. Each selection change onto a visible window is `system.raiseWindows([window])`,
beside `bringToFront`. The lift reads the windows again and asks the value for a `WindowLift`, a pure plan of which
windows to raise and whether to pulse. The selection maths is the app switcher's,
extracted into `SwitcherSelection`. The shell draws `launcher.windowSwitcher`. Previews are a shell asset, like icons:
the model says whether rows show previews and which windows; the window switcher's presenter captures those windows
once per window swipe and holds the pictures only while that window switcher is on screen. Both permissions sit behind
one `Permissions` port that owns the one TCC broadcast.

**Call site 1: the model (`Launcher`, `LauncherCore`).**

```swift
/// The one place a window swipe becomes effects.
private func windowSwipe(_ event: SwipeEvent) {
    switch event.phase {
    case .began:
        guard shown == nil, activity.isActive else { return }
        windowSwipesBegun += 1
        let read = system.frontmostWindows()
        let content = isAccessibilityGranted ? WindowSwitcher.Content(read) : .accessibilityNeeded(for: read.app)
        // The grant as the last TCC push left it (R7): a fresh preflight would cost about 4 ms here.
        shown = .windows(WindowSwitcher(
            content, showsPreviews: isScreenRecordingGranted, serial: windowSwipesBegun, trackpad: event.trackpad))
    case .moved(let travel):
        guard case .windows(var open)? = shown, open.trackpad == event.trackpad else { return }
        let crossed = open.selection.follow(travel)
        shown = .windows(open)
        for _ in 0..<crossed { hardware.playFeedback(.lightTick, on: event.trackpad) }
        // Only a visible window comes forward while sliding: raising a minimised one would restore it (R10).
        if crossed > 0, let window = open.selectedVisibleWindow { system.raiseWindows([window]) }
    case .ended:
        guard case .windows(let open)? = shown, open.trackpad == event.trackpad else { return }
        shown = nil
        // A message row has nothing to switch: silent, and nothing is read (R13, R14).
        guard open.listsWindows else { return }
        // The second read: the plan follows the windows as they are now, whatever the raises while sliding did.
        let lift = open.lift(now: system.frontmostWindows())
        if lift.playsHaptic {
            hardware.playFeedback(.gesture, on: event.trackpad)
            window = .closed
        }
        system.raiseWindows(lift.raises)
    case .cancelled:
        // The windows stay as they are: no reordering, silent (R15).
        if case .windows(let open)? = shown, open.trackpad == event.trackpad { shown = nil }
    }
}
```

**Call site 2: the shell (`WindowSwitcherPresenter`, `LauncherUI`), the app switcher's presenter pattern.**

```swift
for await shown in Observations({ launcher.windowSwitcher }) { render(shown) }

private func render(_ switcher: WindowSwitcher?) {
    guard let switcher else {
        capture?.cancel()
        shownSerial = nil
        panel.dismiss()                                   // fades, then `emptied()` drops every picture (R17)
        return
    }
    if switcher.serial != shownSerial { open(switcher) }  // one layout and one capture per window swipe
    panel.show(position: switcher.selection.position, selected: switcher.selection.selected)
    if switcher.selection.stretch != lastStretch, switcher.selection.stretch != 0, !reduceMotion {
        panel.springHighlight(fromY: switcher.selection.stretch * layout.pitch)
    }
    lastStretch = switcher.selection.stretch
}

private func open(_ switcher: WindowSwitcher) {
    let screen = Displays.screen(under: NSEvent.mouseLocation)
    let visible = screen?.visibleFrame ?? .zero
    let scale = screen?.backingScaleFactor ?? 2
    layout = WindowColumnLayout(
        rowCount: switcher.rows.count, widestTitle: panel.widestTitle(switcher.rows), displayHeight: visible.height)
    panel.lay(out: switcher.rows, icon: switcher.app.map(icons.icon(forSwitcher:)), layout: layout,
              topLeft: NSPoint(x: visible.minX + WindowColumnLayout.margin, y: visible.maxY - WindowColumnLayout.margin))
    shownSerial = switcher.serial
    lastStretch = 0
    panel.present(animated: !reduceMotion)
    capture?.cancel()
    guard !switcher.previewWindows.isEmpty else { return }
    let serial = switcher.serial, rows = switcher.rows, pixels = layout.previewPixels(scale: Double(scale))
    capture = Task { [weak self] in
        for await (window, picture) in PreviewCapture.pictures(of: switcher.previewWindows, fitting: pixels) {
            guard let self, shownSerial == serial, let row = rows.firstIndex(where: { $0.window == window }) else { return }
            panel.setPreview(picture, row: row, animated: !reduceMotion)
        }
    }
}
```

**Call site 3: tests at the high seam (`World`).** `RecordingSystemActions.windows` is a small window stack that
behaves the way `AXRaise` does: a raised window moves to the front, and a raised minimised window is restored.

```swift
@Test func liftingOnNewsStacksNewsThenTheFrontWindowThenTheRest() {
    let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
    let first = world.windowSwipe(3.5, 24)                       // begin, two rows down, lift
    #expect(world.system.windows.onScreenTitles == ["News", "Docs", "Mail"])
    #expect(world.hardware.lightTicks.count == 2)
    #expect(world.hardware.feedback == [Trackpad.macBook14.id])
    #expect(world.system.launchAnimations.isEmpty)
    world.play(first.land(fingers: 2).slide(byMM: (0, 3.5)))     // the next window swipe, under the same thumb
    #expect(world.launcher.windowSwitcher?.rows.map(\.title) == ["News", "Docs", "Mail"])
}

@Test func aSelectedWindowThatClosesLeavesTheWindowsAsTheyAre() {
    let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
    let hand = world.windowSwipe(3.5, 12, lift: false)
    #expect(world.system.windows.onScreenTitles == ["Mail", "Docs", "News"])
    world.system.windows.close("Mail")                           // Docs is in front again
    world.play(hand.lift())
    #expect(world.system.windows.onScreenTitles == ["Docs", "News"])
    #expect(world.hardware.feedback.isEmpty)
}

@Test func withoutScreenRecordingNoRowAsksForAPreviewAndNothingPrompts() {
    let world = World.windowWorld(visible: ["Docs", "Mail"], minimised: ["Notes"], screenRecording: false)
    let lifted = world.windowSwipe(3.5, lift: false).lift()
    #expect(world.launcher.windowSwitcher?.previewWindows.isEmpty == true)
    world.play(lifted)
    #expect(world.permissions.asks.isEmpty)
    world.permissions.set(.screenRecording, granted: true)       // the TCC push
    world.play(lifted.land(fingers: 2).slide(byMM: (0, 3.5)))
    #expect(world.launcher.windowSwitcher?.previewWindows == [world.window("Docs"), world.window("Mail")])
}
```

**Call site 4: the launcher window (`LauncherUI` views).**

```swift
// SwitcherSection, the third row:
SettingRow(illustration: "window-swipe", title: "Swipe up or down to switch windows",
           isOn: Binding(get: { launcher.isWindowSwipeOn }, set: { launcher.setWindowSwipe(on: $0) }))
// LauncherView, after the Accessibility hint:
if let hint = launcher.screenRecordingHint {
    SettingsNotice(message: Copy.screenRecordingHint, button: Copy.screenRecordingButton(hint)) {
        switch hint {
        case .ask: launcher.askForScreenRecording()
        case .openSettings: actions.openSettings(.screenRecording)
        }
    }
}
```

**Call site 5: the recognizer over scripted frames.**

```swift
@Test(arguments: [(HandMode.right, 10.0), (.left, 114.8)])
func twoFingersSlidingDownPastThreeMillimetresBeginAWindowSwipe(hand: HandMode, thumbX: Double) {
    let frames = TouchScript(.macBook14).thumb(atMM: (thumbX, 10)).land(fingers: 2).slide(byMM: (0, 5)).lift().frames
    #expect(windowPhases(frames, handMode: hand).first == .began)
    #expect(windowPhases(frames, handMode: hand).last == .ended)
    #expect(phases(frames, handMode: hand).isEmpty)
}
```

### Shape

**Data first.** One read of the system, `FrontmostWindows` (the app; its visible windows on the current Space, front
to back; its minimised windows in the app's order), is parsed once at the model's edge into
`WindowSwitcher.Content`, a sum type: `.windows(of:, WindowList)` where `WindowList` is `.front(…)` or
`.minimisedOnly(…)`, `.noWindows(of:)`, or `.accessibilityNeeded(for:)`. Everything else derives from that fixed value:
the rows the presenter draws, the window a move raises (`selectedVisibleWindow`), the front window (`frontWindow`), the
windows the presenter captures (`previewWindows`), and, given the second read, the lift (`lift(now:)`). Every dominant
access reads the one value; nothing needs an index or a cache.

**Load-bearing decisions.**

- **One recognizer state, kind fixed at begin** (per model-the-domain). `beginOrSpoil` stays the single place a
  slide's direction is decided: `Move.slide` is strict both ways, so a tie spoils, as today; `slides: Set<SlideKind>`
  replaces `swipes: Bool`; `Swipe.kind` is a `let`. `.swiping` is unchanged, so blocking, rejoin, thumb, cancel and end
  apply to both kinds by construction (R15). A pair and `.resting` exist while any kind is on (R16: swipe off with the
  window swipe on); with only one kind on, the other axis spoils exactly as today.
- **Phases by kind, same hop** (per type-system-discipline). `Recognition.Event.windowSwipe` and
  `TrackpadEvent.windowSwipe` are new cases, so the compiler routes a window swipe to its own handler and the tests'
  existing `.swipe(...)` phases and injections are untouched; only the frame thread's per-begin travel hook widens, to
  `Recognition.beginsSlide`. The hop, the generation check and `TrackpadEvent.init` are the same code.
- **Travel along the slide.** `PointerCurve.cursorMove` returns both components, scaled by the one speed-dependent
  multiplier; `SwipeTravel.travel(along:)` picks the component. One step is 100 cursor points on either axis: the app
  switcher's icon pitch and R9's row.
- **One selection rule.** `SwitcherSelection` is the app switcher's maths moved out of `Switcher` unchanged and shared
  by both switchers; `follow` returns the items crossed, which is the tick count.
- **At most one switcher.** The model stores `shown: ShownSwitcher?` (`.apps` or `.windows`) and derives `switcher` and
  `windowSwitcher`; `reconcile` clears both with one write (per encode-lessons-in-structure).
- **Content as a construction, not flags** (per type-system-discipline). The front window exists only in `.front`; the
  all-minimised case is its own variant; a message row exists only as the single row of a message content. The rules
  live in the one parse: a full-screen front window alone, other full-screen windows left out, visible before
  minimised, the cut at 10 (per boundary-discipline).
- **The lift is a pure plan from a second read** (per make-operations-idempotent; Risk 4). `lift(now:)` takes the
  windows as they are at the lift and returns which to raise and whether to pulse, so it never depends on what the
  raises while sliding did. The target is the selected window, then the visible windows in their begin order (the
  front window first), minus any that closed; `WindowStack.raises` gives the shortest front part of it that, raised
  back to front, leaves that order (F22): empty when the order already holds, so a lift on the front window that slid
  nowhere raises nothing (R5's focus scenario) and one that slid away and back restores the order. A selected window
  that closed raises nothing; another app in front at the lift raises nothing and is silent. Every R11 and R12 rule is
  in this one pure function; the adapters only raise.
- **Window reads and raises beside their pairs on `SystemActions`** (`why.md` Preserve 7; no new port).
  `frontmostWindows()` sits beside `runningApps()` and `raiseWindows(_:)` beside `bringToFront(_:)`; the real work
  lives in one small platform type, `FrontmostAppWindows`, which `WorkspaceActions` creates once and delegates to, as
  it does `RunningAppsReader`. It holds no window, so its tests construct it alone, and its pure `sort` and
  `number(of:among:)` let them check R4's filter and R3's order without the Accessibility permission.
- **One TCC module.** The `Permissions` port replaces `AccessibilityPermission` and owns both permissions and the one
  `notify_register`; each broadcast re-reads both, and `onChange` runs when either changed (F29; per
  separate-before-serializing-shared-state: one writer of the registration). The R8 hint derives from three facts: the
  setting, the grant, and the persisted `hasAskedForScreenRecording`.
- **Previews are rendered assets, not model state** (per minimize-reader-load; plan 008's icon precedent). No decision
  reads a picture. The model decides whether rows show previews (R7: the grant at begin) and which windows (the visible
  rows, R4). The presenter captures exactly `previewWindows` once per `serial`, so the pictures' lifetime derives from
  the observed value and every exit (lift, cancel, reconcile) discards them by construction: the capture task is
  cancelled at nil, each arrival is checked against the shown serial, and the panel empties its layers once it is out
  (R17). The capture runs only when the model says previews show, and the source policy bans streams, recordings and
  every image encoder.
- **Window identity is the window server's number.** `WindowID` brands the one number AX (`_AXUIElementGetWindow`),
  the window list and ScreenCaptureKit share, stable across the begin and lift reads. It is what lets the shell capture
  with no image channel through the core; the AX handle stays in the adapter.

**Interface depth.** `SystemActions` gains two methods. Behind them: the frontmost pid; AX IPC under a 0.2 s process-wide
messaging timeout, with no further raises to an app after its first timeout; the private window number and its
frame-matching fallback; the current-Space test by the on-screen window list; subrole filtering for visible windows
only (F9); the full-screen flag; closed-element errors; focus; restore by raise. `Permissions` is three members over AX
trust, screen-capture access, both prompts and the shared broadcast. `WindowSwitcher` hides row derivation, naming, the
cut, the message rows, the lift plan and the haptic rule behind reads plus `follow` and `lift(now:)`. The model's
public surface grows by `windowSwitcher`, `isWindowSwipeOn` / `setWindowSwipe(on:)` and `screenRecordingHint` /
`askForScreenRecording()`; the grant stays private because the hint and `showsPreviews` carry it.

**Deliberately not done.** No main-to-frame channel. No window state in the model between window swipes. No restore
while sliding. No raise of an unlisted window. No prompt from a gesture. No live previews, no stream. No attribute
writes: closing, minimising and moving windows are banned by the source policy. No change to the gesture hint text.

#### Module map

| Module | New or changed |
|---|---|
| LauncherCore | `SlideKind`; `GestureRecognizer` (`slides`, `beginOrSpoil`, `Swipe.kind`); `Recognition.Event.windowSwipe`, `Recognition.windowSwipe`, `beginsSlide`; `PointerCurve.cursorMove` (replaces `cursorPoints`), `SwipeTravel.travel(along:)`, `pointsPerStep`; `SwitcherSelection` (new), `Switcher` holds one; `WindowID`, `AppWindow`, `FrontmostWindows`, `WindowStack` (new); `WindowSwitcher`, `WindowLift` (new); `WindowColumnLayout` (new); ports: `SystemActions` +2, `Permission` / `Permissions` (replaces `AccessibilityPermission`), `TrackpadEvent.windowSwipe`, `TrackpadHardware.run(slides:)`; `Settings.isWindowSwipeOn`, `.hasAskedForScreenRecording`, `.slides`; `ScreenRecordingHint`; `Copy` strings; `GestureRules.windowSwitcherMaxRows`; `Launcher` (`shown`, `windowSwipe(_:)`, setters, hint, both grants); the stale `SwipePhase`, `Switcher` and `switcherMaxOvershoot` comments fixed |
| LauncherPlatform | `FrontmostAppWindows` (new, the window read and raise, with its pure `sort` and `number(of:among:)` seams); `WorkspaceActions` delegates the two window methods to it; `SystemPermissions` (was `SystemAccessibilityPermission`); `DeviceSession.receive` installs travel on `beginsSlide`; `MultitouchTrackpads.run(slides:)`; `CursorTravel` and `LaunchTuning` use `pointsPerStep` |
| LauncherUI | `OverlayPanel` (new base for both switcher panels), `Displays.screen(under:)` (moved out of `SwitcherPresenter`); `WindowSwitcherPanel`, `WindowSwitcherPresenter`, `WindowSwitcherLook`, `PreviewCapture` (new); `SwitcherPanel` and `SwitcherPresenter` adopt the base and read `selection`; `SwitcherSection` third row through `SettingRow`; `LauncherView` hint; `SettingsPane.screenRecording`; `MenuBarShell` builds the presenter and adds `screenRecordingHint` to the refit observation |
| App target | `SystemPermissions()` in place of `SystemAccessibilityPermission()`; `assets/window-swipe.svg` |
| Tests | `RecordingSystemActions.windows` (a `FakeWindows` stack), `InMemoryPermissions` (replaces `InMemoryAccessibilityPermission`); `World` (`permissions`, `windowWorld`, `windowSwipe`, `window(_:)`); the `windowPhases` driver; `slides:` at every recognizer construction site; `TouchScript.tap(dragMM:)` takes `(x, y)`; source policy rows |

#### Core types and signatures

```swift
// MARK: Recognition

/// What two fingers sliding under an anchored thumb start. Decided once, on the frame the farthest-moved finger passes
/// 3 mm, and held until both fingers lift.
public enum SlideKind: Hashable, Sendable {
    /// More sideways than up or down: the app switcher. Travel is positive to the right in both hand modes.
    case swipe
    /// More up or down than sideways: the window switcher. Travel is positive downwards in both hand modes.
    case windowSwipe
}

/// A swipe's or a window swipe's progress; the event case says which. (Replaces the three stale comments.)
public enum SwipePhase: Equatable, Sendable {
    /// One of two fingers under an anchored thumb moved past 3 mm. Travel is 0 here: the 3 mm do not count.
    case began
    /// Travel along the slide since `began`, in step millimetres (12 per item), absolute. Sent only when it changed.
    case moved(travelMM: Double)
    /// Both fingers have lifted.
    case ended
    /// A third finger landed outside the anchor corner while both were down, or a click reached apps.
    case cancelled
}

extension Recognition.Event {
    // New case beside .fired, .swipe and .swap:
    //     case windowSwipe(SwipePhase)
    static func slide(_ kind: SlideKind, _ phase: SwipePhase) -> Self {
        kind == .swipe ? .swipe(phase) : .windowSwipe(phase)
    }
}

extension Recognition {
    public var windowSwipe: SwipePhase? { fatalError("not implemented") }
    /// This frame began a swipe or a window swipe: the frame thread installs the cursor travel now.
    public var beginsSlide: Bool { swipe == .began || windowSwipe == .began }
}

extension GestureRecognizer {
    /// `slides`: the kinds whose setting is on. Empty: a pair's drag spoils like any drag, as with both settings off.
    public init(handMode: HandMode, surface: SurfaceSize, slides: Set<SlideKind>, swaps: Bool, travel: SwipeTravel) {
        fatalError("not implemented")
    }
    // .tapping:   let pair = slides.isEmpty ? nil : Pair(tap, joining: joining)
    //
    // beginOrSpoil, the one place a slide's direction is decided:
    //     guard let pair, let kind = move.slide, slides.contains(kind) else { return (.spoiled(anchor), nil) }
    //     return (.swiping(Swipe(kind: kind, fingers: …, lastTime: time, thumb: anchor)), .slide(kind, .began))
    //
    // Move:       var slide: SlideKind? { abs(dxMM) > abs(dyMM) ? .swipe : abs(dyMM) > abs(dxMM) ? .windowSwipe : nil }
    //
    // .swiping:   travel = swipe.travelMM + self.travel.travel(along: swipe.kind, dxMM: dxMM, dyMM: dyMM, interval: interval)
    //             every phase is emitted as .slide(swipe.kind, phase); blocking stays `if case .swiping = state`
}

extension PointerCurve {
    /// Cursor points the pointer moves along x and y for one report of finger movement: the HID system scales the
    /// whole delta by one speed-dependent multiplier (y by symmetry with x; open question 1). Replaces `cursorPoints`.
    public func cursorMove(dxMM: Double, dyMM: Double, interval: Double) -> (x: Double, y: Double) {
        fatalError("not implemented")
    }
}

public enum SwipeTravel: Equatable, Sendable {
    case linear
    case cursor(PointerCurve, pointsPerStep: Double)
    /// 100 cursor points per step: the app switcher's icon pitch, and the window switcher's row (R9). For rows the
    /// cursor match is not literal, by requirement ("whatever the rows' size on screen").
    public static let shippedPointsPerStep = 100.0
    /// `.linear`: the millimetres along the slide. `.cursor`: the cursor's points along it ÷ pointsPerStep × 12.
    func travel(along kind: SlideKind, dxMM: Double, dyMM: Double, interval: Double) -> Double {
        fatalError("not implemented")
    }
}

// MARK: Selection, shared by both switchers

/// Where the fingers have taken a switcher's selection along its fixed list: the nearest item; hard stops at both
/// ends; a rubber band of at most a quarter step, forgotten the moment the fingers turn back (no dead zone).
/// `Switcher.follow`, `selected`, `position` and `stretch` today, moved here unchanged.
public struct SwitcherSelection: Equatable, Sendable {
    /// At least 1: a one-row switcher rubber-bands at both ends (R13).
    public let count: Int
    public package(set) var travelMM: Double = 0
    private var reportedMM: Double = 0
    package init(count: Int) { fatalError("not implemented") }
    /// Takes the slide's absolute travel. Returns how many items the selection crossed: one light tick each.
    @discardableResult package mutating func follow(_ reportedMM: Double) -> Int { fatalError("not implemented") }
    public var selected: Int { fatalError("not implemented") }
    public var position: Double { fatalError("not implemented") }
    public var stretch: Double { fatalError("not implemented") }
}
// Switcher keeps `row`, `startsOnFrontmost`, `selectedApp`, `selectsFrontmost` and `trackpad`; its maths moves into
// `public package(set) var selection: SwitcherSelection`. No forwarding properties: callers read `selection`.

// MARK: Windows

/// The window server's number for one window: the one number the Accessibility API, the window list and screen
/// capture all report, stable for the window's life. (Core comments never spell the confined API names: the source
/// scan reads comments too.)
public struct WindowID: Hashable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}

/// One of an app's normal document or app windows, as one read found it.
public struct AppWindow: Equatable, Sendable, Identifiable {
    public let id: WindowID
    /// As the app titles it; "" when it has no title.
    public let title: String
    public let isFullScreen: Bool
}

/// One read of the frontmost app's windows.
public enum FrontmostWindows: Equatable, Sendable {
    /// There is no active app, or it is Trackpad Launcher itself.
    case noApp
    /// `visible`: its windows on the current Space, front to back; panels, palettes, sheets and other helpers left
    /// out. `minimised`: its minimised windows, in the order the app lists them. Both empty when it has none, when
    /// Accessibility is missing, or when the app did not answer in time.
    case app(AppEntry, visible: [AppWindow], minimised: [AppWindow])

    public var app: AppEntry? { fatalError("not implemented") }
}

/// How raising windows one at a time, each to the front of its app, reaches an order.
public enum WindowStack {
    /// The shortest front part of `target` (front to back) that, raised back to front, leaves the app's windows in
    /// `target` order. `current`: the app's visible windows now, front to back, including any that opened since the
    /// begin. The first target window is part of it unless it already leads `current`, so a minimised first window is
    /// restored and one opened mid-swipe is passed; target windows not in `current` other than the first (minimised)
    /// are left out, so a later minimised window is never restored. Empty when the order already holds. Total: the
    /// whole target always qualifies.
    public static func raises(current: [WindowID], target: [WindowID]) -> [WindowID] { fatalError("not implemented") }
}

// MARK: The window switcher

/// The window switcher during one window swipe. Its content is fixed when the window swipe begins: a window that opens
/// later is not added, and one that closes stays listed. The selection follows the travel.
public struct WindowSwitcher: Equatable, Sendable {
    public enum Content: Equatable, Sendable {
        case windows(of: AppEntry, WindowList)
        /// "No open windows", with the app's icon when there is a frontmost app.
        case noWindows(of: AppEntry?)
        /// "Allow Accessibility to switch windows", with the frontmost app's icon.
        case accessibilityNeeded(for: AppEntry?)
    }

    /// At most `GestureRules.windowSwitcherMaxRows` windows in all.
    public enum WindowList: Equatable, Sendable {
        /// The front window, the other visible windows front to back, then the minimised ones in the app's order.
        /// A full-screen front window is alone.
        case front(AppWindow, others: [AppWindow], minimised: [AppWindow])
        /// Every listed window is minimised: there is no front window.
        case minimisedOnly(first: AppWindow, rest: [AppWindow])
    }

    public enum Row: Equatable, Sendable {
        /// Its preview, or the app icon until the preview is ready, and its title.
        case visible(WindowID, title: String)
        /// Dimmed, with the app icon, its title and the "Minimised" badge.
        case minimised(WindowID, title: String)
        /// The single row of a window switcher with nothing to switch.
        case message(String)

        public var window: WindowID? { fatalError("not implemented") }
        public var title: String { fatalError("not implemented") }
    }

    public let content: Content
    public package(set) var selection: SwitcherSelection
    /// Screen Recording was granted when the window swipe began, so visible rows show previews (R7).
    public let showsPreviews: Bool
    /// The window swipes since launch. Tells one window swipe's switcher from the next, so the presenter lays out and
    /// captures once per window swipe and a picture taken for one never shows in another.
    public let serial: Int
    public let trackpad: TrackpadID

    /// The selection count is `rows.count` (one for a message) and starts on the first row (R9, R11).
    package init(_ content: Content, showsPreviews: Bool, serial: Int, trackpad: TrackpadID) {
        fatalError("not implemented")
    }

    /// Whose windows these are and whose icon the rows show. nil: no frontmost app.
    public var app: AppEntry? { fatalError("not implemented") }
    /// Top to bottom. A window titled "" reads as the app's name, plus " — Window N" when there is more than one row,
    /// N its 1-based row (`Copy.untitledWindow`).
    public var rows: [Row] { fatalError("not implemented") }
    /// The app's window in front when the window swipe began. nil when every window is minimised, or for a message.
    public var frontWindow: WindowID? { fatalError("not implemented") }
    /// The windows to capture: the visible rows while `showsPreviews`, else none.
    public var previewWindows: [WindowID] { fatalError("not implemented") }
    /// The window that comes to the front while its row is selected. nil on a minimised row or a message (R10).
    public var selectedVisibleWindow: WindowID? { fatalError("not implemented") }
    /// Windows are listed, so a lift can change something. false for a message: its lift reads nothing and is silent.
    public var listsWindows: Bool { fatalError("not implemented") }

    /// The lift (R11, R12), from the rows fixed at begin and a second read of the frontmost app's windows. Pure.
    /// - `now` is no app or another app, or nothing is listed → `.nothing`: no raises, silent.
    /// - The selected window has closed → no raises (no reordering); the haptic plays iff a window is in front now and
    ///   it is not `frontWindow`. Every listed window closed is therefore silent.
    /// - Otherwise the target is the selected window, then the visible windows in their begin order (the front window
    ///   first) without it, minus any that closed; `raises` is `WindowStack.raises(current: now's visible, target:)`;
    ///   the haptic plays iff the selected window is not `frontWindow`, which covers restoring a minimised one and every
    ///   row when every window is minimised. Lifting on the front window therefore restores the order, silently.
    public func lift(now: FrontmostWindows) -> WindowLift { fatalError("not implemented") }
}

/// What the lift does: `raises` front to back (the first ends in front with the keyboard focus), and R12's pulse.
public struct WindowLift: Equatable, Sendable {
    public let raises: [WindowID]
    public let playsHaptic: Bool
    public static let nothing = WindowLift(raises: [], playsHaptic: false)
}

extension WindowSwitcher.Content {
    /// The one parse from what the system read to what the switcher lists:
    /// - `.noApp`, or an app with no windows, reads as `.noWindows`.
    /// - A full-screen front window is the single row; other full-screen windows are left out.
    /// - Visible windows come before minimised ones, and the list is cut at 10.
    package init(_ read: FrontmostWindows) { fatalError("not implemented") }
}

/// Where the window switcher's rows and highlight sit: one column of `rowCount` rows on a display whose visible frame
/// is `displayHeight` points tall. When the column would not fit, everything shrinks by one factor (R5). Pure, tested
/// in core like `SwitcherRowLayout`.
public struct WindowColumnLayout: Equatable, Sendable {
    public static let margin = 12.0, panelPadding = 8.0, rowGap = 2.0, rowInset = 6.0
    public static let previewWidth = 120.0, previewHeight = 60.0, iconSide = 44.0, titleGap = 12.0
    public static let minTitleWidth = 180.0, maxTitleWidth = 320.0, titleSize = 13.0
    public let rowCount: Int
    /// 1 when the column fits at full size, otherwise below 1.
    public let scale: Double
    public init(rowCount: Int, widestTitle: Double, displayHeight: Double) { fatalError("not implemented") }
    /// Row height plus gap: the highlight's travel per row.
    public var pitch: Double { fatalError("not implemented") }
    public var panelSize: (width: Double, height: Double) { fatalError("not implemented") }
    /// The top of a row, measured down from the panel's top edge, for a position counted in rows.
    public func rowTop(at position: Double) -> Double { fatalError("not implemented") }
    /// A picture of a window `aspect` (width ÷ height) wide, in the slot: 60 pt tall, or less when 120 pt wide would
    /// not hold it (R6), times `scale`. The slot stays 120 pt wide, so titles never move when a picture lands.
    public func previewSize(aspect: Double) -> (width: Double, height: Double) { fatalError("not implemented") }
    /// The largest picture worth capturing, in pixels at a display's backing `scale`.
    public func previewPixels(scale: Double) -> (width: Int, height: Int) { fatalError("not implemented") }
}

// MARK: Ports

@MainActor public protocol SystemActions: AnyObject {
    // bringToFront(_:), registerLoginItem(), prepareLaunchAnimations(for:), playLaunchAnimation(for:), runningApps():
    // unchanged.

    /// The frontmost app's windows, read now, beside `runningApps()`: about a millisecond, at most one messaging timeout
    /// (0.2 s) when the app does not answer. Reads only. The windows it lists are the only ones a later
    /// `raiseWindows` may name, until the next read.
    func frontmostWindows() -> FrontmostWindows

    /// Raises these windows of the latest `frontmostWindows()` read, the last first, so the first ends in front of its
    /// app with the keyboard focus and the rest behind it in this order; beside `bringToFront`, which is app-level. A
    /// raised minimised window is restored. A window that has closed is skipped; an id the latest read did not list is
    /// skipped, so nothing on another Space is ever raised. About 2 ms per raise; once the app has timed out, no
    /// further calls go to it for that read. [] does nothing.
    func raiseWindows(_ frontToBack: [WindowID])
}

public enum Permission: Hashable, Sendable { case accessibility, screenRecording }

/// The permissions macOS grants the app. Real: SystemPermissions. Test: InMemoryPermissions.
@MainActor public protocol Permissions: AnyObject {
    /// On the main actor after either permission changed, and only then. Carries no data: re-read.
    var onChange: (@MainActor () -> Void)? { get set }
    /// Read fresh. Never prompts. Screen Recording's read costs about 4 ms (check-1), so the model reads it on pushes,
    /// never on a gesture.
    func isGranted(_ permission: Permission) -> Bool
    /// The system's prompt for it. Returns at once; the prompt belongs to another process.
    func ask(_ permission: Permission)
}

// TrackpadEvent gains `case windowSwipe(SwipeEvent)`; `TrackpadEvent.init(_:on:)` maps `.windowSwipe(phase)` to it.
// TrackpadHardware.run(_:handMode:blockClicks:slides:swaps:) replaces `swipes: Bool` with `slides: Set<SlideKind>`.

// MARK: Model additions

extension Settings {
    // public var isWindowSwipeOn = true                 // decodeIfPresent ?? true: an upgrade leaves it on (R16)
    // public var hasAskedForScreenRecording = false     // the hint's first press asked macOS (R8)
    /// Derived, never stored.
    public var slides: Set<SlideKind> { fatalError("not implemented") }
}

public enum ScreenRecordingHint: Equatable, Sendable {
    /// Never asked: the button asks macOS.
    case ask
    /// Asked before and still missing: the button opens System Settings on the Screen Recording page.
    case openSettings
}

extension Launcher {
    // init: `access: any AccessibilityPermission` becomes `permissions: any Permissions`; nothing else changes.
    // private enum ShownSwitcher: Equatable { case apps(Switcher), windows(WindowSwitcher) }
    // private var shown: ShownSwitcher?            // written only by swipe(_:), windowSwipe(_:) and reconcile()
    // private var isScreenRecordingGranted = false // read with Accessibility in reconcile, on every push, before the
    //                                              // Run guard; a Screen Recording change never restarts trackpads
    // @ObservationIgnored private var windowSwipesBegun = 0
    public var switcher: Switcher? { fatalError("not implemented") }
    /// Non-nil for the whole of a window swipe: it always shows (R13).
    public var windowSwitcher: WindowSwitcher? { fatalError("not implemented") }
    public var isWindowSwipeOn: Bool { fatalError("not implemented") }
    /// nil while the window swipe setting is off or Screen Recording is granted (R8).
    public var screenRecordingHint: ScreenRecordingHint? { fatalError("not implemented") }
    /// Saved at once. The recognizers are rebuilt, so the next slide obeys it and a window swipe in progress ends.
    public func setWindowSwipe(on: Bool) { fatalError("not implemented") }
    /// Only while the hint is `.ask`. Records the ask and saves, then asks: a crash in between never asks twice.
    public func askForScreenRecording() { fatalError("not implemented") }
    // start(): onEvent routes `.windowSwipe(let e)` to windowSwipe(e); permissions.onChange = { reconcile() };
    //          the first-launch prompt becomes permissions.ask(.accessibility).
    // reconcile(): Run.slides = settings.slides.
}

// GestureRules: windowSwitcherMaxRows = 10.
// Copy: noOpenWindows, accessibilityForWindows, minimisedBadge, untitledWindow(of:position:rows:),
//       screenRecordingHint ("Window previews need Screen Recording."),
//       screenRecordingButton(_:) ("Allow Screen Recording…" for .ask, "Open System Settings…" for .openSettings).
```

#### Platform and shell signatures

```swift
/// The whole window read and raise behind `SystemActions.frontmostWindows()` and `raiseWindows(_:)`, over the
/// Accessibility element API and the window list. `WorkspaceActions` creates one and delegates both methods to it, as it
/// does `runningApps()` to `RunningAppsReader`. Holds no window, so its tests construct it alone. The only file that may
/// name `AXUIElement` (and so `_AXUIElementGetWindow`) or `CGWindowList`.
@MainActor final class FrontmostAppWindows {
    static let messagingTimeout: Float = 0.2
    /// Sets the messaging timeout once on the system-wide element (process-wide; set on any other element it covers
    /// that element only, `AXUIElement.h`), resolves `_AXUIElementGetWindow` with dlsym, and pays the window list's
    /// first-call cost (about 50 ms) off the main actor now, not at the first window swipe.
    init() { fatalError("not implemented") }
    func read() -> FrontmostWindows {
        // 1. NSWorkspace.frontmostApplication, not this process → RunningApp.entry(for:), else .noApp.
        // 2. AXUIElementCreateApplication(pid), kAXWindowsAttribute. Any error (not trusted, cannot complete) →
        //    .app(entry, [], []).
        // 3. Per window, one AXUIElementCopyMultipleAttributeValues: role, subrole, title, minimised, AXFullScreen,
        //    position, size. Stop at the first cannot-complete; the listing is then marked unanswering.
        // 4. Number: _AXUIElementGetWindow, else Self.number(of:among:) against the pid's window-list entries.
        // 5. On screen: CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements]), the pid's layer-0
        //    numbers, front to back.
        // 6. Self.sort(raw, onScreen:); keep [WindowID: AXUIElement] for the listed windows as what `raise` may name.
        fatalError("not implemented")
    }
    func raise(_ frontToBack: [WindowID]) {
        // Unanswering listing → nothing. For each id, last first: unlisted → skip; kAXRaiseAction on its element
        // (it restores a minimised window, F20); kAXErrorInvalidUIElement (closed, F14) → skip; kAXErrorCannotComplete
        // → mark the listing unanswering and stop.
        fatalError("not implemented")
    }

    /// The adapter's internal seam, pure and tested in LauncherPlatformTests: R4's filter and R3's order from raw
    /// facts. Visible: role AXWindow, subrole AXStandardWindow, not minimised, on screen now (so on this Space, F10), in
    /// the window list's order. Minimised: kAXMinimized alone, because a minimised window reports AXDialog (F9), in AX
    /// order. A window with no number is left out.
    nonisolated static func sort(_ windows: [RawWindow], onScreen: [UInt32]) -> (visible: [AppWindow], minimised: [AppWindow]) {
        fatalError("not implemented")
    }
    /// The fallback without the private symbol, pure: the pid's window-list entry with the same frame, and the same
    /// title where the list names windows. nil when none, or more than one, matches.
    nonisolated static func number(of window: RawWindow, among listed: [ListedWindow]) -> UInt32? {
        fatalError("not implemented")
    }
}

struct RawWindow: Sendable {
    var number: UInt32?; let title: String; let role: String?; let subrole: String?
    let isMinimised: Bool; let isFullScreen: Bool; let frame: CGRect?
}
struct ListedWindow: Sendable { let number: UInt32; let frame: CGRect; let name: String? }

// WorkspaceActions: `private let windows = FrontmostAppWindows()`; frontmostWindows() → windows.read();
// raiseWindows(_:) → windows.raise(_:).

/// Permissions over AX trust, screen-capture access and tccd's one broadcast (about 30 ms after a change, main queue,
/// no payload, no service named): both are re-read on every post, and `onChange` runs only when either changed. The
/// only file that may name `AXIsProcessTrusted`, `notify_register` or `ScreenCaptureAccess`.
@MainActor public final class SystemPermissions: Permissions {
    /// Both reads are injectable for the adapter's own test, which flips them and posts the notification itself.
    public init(
        trusted: @escaping @Sendable () -> Bool = { AXIsProcessTrusted() },
        capturing: @escaping @Sendable () -> Bool = { CGPreflightScreenCaptureAccess() }
    ) { fatalError("not implemented") }
    public var onChange: (@MainActor () -> Void)?
    public func isGranted(_ permission: Permission) -> Bool { fatalError("not implemented") }
    /// .accessibility: AXIsProcessTrustedWithOptions with the prompt key. .screenRecording: CGRequestScreenCaptureAccess().
    public func ask(_ permission: Permission) { fatalError("not implemented") }
}
```

```swift
/// Both switchers' window: borderless, non-activating, click-through, screen-saver level on every Space and beside
/// full-screen apps, never key. Its content is Liquid Glass under `roundedClip`. Presents at once or with a short
/// appear animation; dismisses with a 150 ms fade (at once with Reduce motion) unless presented again meanwhile.
class OverlayPanel: NSPanel {
    init(cornerRadius: CGFloat, content: NSView) { fatalError("not implemented") }
    func present(animated: Bool) { fatalError("not implemented") }
    func dismiss() { fatalError("not implemented") }
    /// Runs once the panel is out. The window switcher drops every picture here (R17).
    func emptied() {}
}

/// AppKit's rule for which display holds the pointer, the nearest when none does. Moved out of SwitcherPresenter.
enum Displays { static func screen(under pointer: NSPoint) -> NSScreen? { fatalError("not implemented") } }

/// The window switcher: one `.regular` glass panel, ten pre-created rows, one `.clear` glass highlight inside the panel
/// glass's content. The presenter decides what shows; every look and motion number is in `WindowSwitcherLook`.
final class WindowSwitcherPanel: OverlayPanel {
    /// The widest title at full size, measured with the row font.
    func widestTitle(_ rows: [WindowSwitcher.Row]) -> Double { fatalError("not implemented") }
    func lay(out rows: [WindowSwitcher.Row], icon: NSImage?, layout: WindowColumnLayout, topLeft: NSPoint) {
        fatalError("not implemented")
    }
    /// The highlight sits `position` rows from the top, with actions disabled; the selected title takes `labelColor`.
    func show(position: Double, selected: Int) { fatalError("not implemented") }
    func springHighlight(fromY offset: Double) { fatalError("not implemented") }
    /// Crossfades the row's slot from the icon to the picture, sized by `layout.previewSize(aspect:)`.
    func setPreview(_ picture: CGImage, row: Int, animated: Bool) { fatalError("not implemented") }
    override func emptied() { /* every slot layer's contents = nil */ }
}

/// Pictures of windows, taken off the main actor. The one file that captures the screen, for previews only.
enum PreviewCapture {
    /// Yields each window's picture as it is taken: SCShareableContent once (on-screen windows, about 14 ms), then one
    /// SCScreenshotManager capture per window, concurrently (F27), through SCContentFilter(desktopIndependentWindow:),
    /// sized to the window's proportions within `fitting` pixels, with `scalesToFit`, no cursor and no shadow. A window
    /// that cannot be captured yields nothing. Cancelling the consuming task stops the captures. Called only for a
    /// window switcher whose `showsPreviews` is true, so it never prompts.
    nonisolated static func pictures(of windows: [WindowID], fitting: (width: Int, height: Int))
        -> AsyncStream<(WindowID, CGImage)> { fatalError("not implemented") }
}

/// The look and motion, in one value whose defaults are the shipped look, as `LaunchTuning` is for the launch
/// animation: refining it later together touches no policy. Sizes that decide fit live in WindowColumnLayout.
struct WindowSwitcherLook: Sendable {
    var panelRadius = 22.0, highlightRadius = 14.0           // highlight = panel radius − padding: concentric
    var previewRadius = 6.0, minimisedAlpha = 0.55, badgeSize = 10.0
    var titleWeight = NSFont.Weight.medium
    var appearDuration = 0.1, appearScale = 0.96, previewCrossfade = 0.15, dismissFade = 0.15
    var springStiffness = 420.0, springDamping = 22.0
    static let shipped = WindowSwitcherLook()
}

/// Renders `launcher.windowSwitcher` and holds nothing the model holds. Owned by MenuBarShell beside SwitcherPresenter.
/// The panel is created now, so a window swipe never pays the first window's cost. Its own `AppIcons` takes the
/// frontmost app's icon from the running app (about 0.1 ms), so it needs none of the swipe setting's icon passes.
final class WindowSwitcherPresenter {
    // panel; icons = AppIcons(side: WindowColumnLayout.iconSide); capture: Task<Void, Never>?; shownSerial: Int?;
    // layout; lastStretch. render(_:) and open(_:) as in call site 2.
    init(launcher: Launcher) { fatalError("not implemented") }
}
```

**The look and motion** are best judgement, kept in `WindowSwitcherLook` (shell) and `WindowColumnLayout` (core
geometry):
- The panel is `.regular` glass, radius 22, its top-left corner 12 pt inside the pointer display's `visibleFrame`:
  below the menu bar and clear of a left Dock, in both hand modes. Each row is 72 pt: a 120 × 60 pt slot with radius 6
  holding the picture, 60 pt tall or less when 120 pt wide would not hold it, or a 44 pt app icon centred until the
  picture is ready; then the title on one line, 13 pt medium, truncated at the end, `labelColor` when selected and
  `secondaryLabelColor` otherwise. The column is as wide as the widest title, clamped to 180 to 320 pt, so a short
  list stays compact. A minimised row sits at 55 % alpha with a 10 pt "Minimised" capsule.
- The highlight is one `.clear` glass view, radius 14, concentric with the panel's padding (the macOS 26 SDK has no
  `cornerConfiguration`, so concentricity is by these numbers). It follows the travel 1:1 with actions disabled and
  springs on `position.y` past the ends, as the app switcher's does on `position.x`.
- The panel appears with 0.1 s of opacity and a spring from 0.96 scale anchored at its top-left corner, at once with
  Reduce motion; a picture arrives with a 0.15 s crossfade; the panel leaves with the shared 150 ms fade. Shrinking
  scales fonts with the rows.

**Degraded cases.**

| Case | Behaviour | Where |
|---|---|---|
| No Accessibility | One row: the frontmost app's icon and "Allow Accessibility to switch windows". The lift is silent. The window swipe is still recognised; nothing is blocked (R14). | model gate on `isAccessibilityGranted` |
| App does not answer | The read lists nothing, so the row is "No open windows". A timeout during `raiseWindows` stops raises to that app for this read. | adapter |
| Window closed | A raise changes nothing. The lift does no reordering, with the haptic only if another window is now in front (R10, R11). | adapter; `lift(now:)` |
| Every listed window closed | Nothing is in front: the lift is silent. | `lift(now:)` |
| Another app in front at the lift | Nothing is raised; silent. | `lift(now:)` |
| No `_AXUIElementGetWindow` | Numbers come from frame matching; an unmatched window is not listed. | adapter |
| No Screen Recording | `previewWindows == []`: nothing captures, rows show the icon, nothing prompts (R7). | model; shell |
| Capture fails for a window | Its row keeps the icon. | shell |
| No frontmost app | "No open windows" with no icon (R13). | model parse |

#### Requirement trace

| R | Carried by |
|---|---|
| R1 | `beginOrSpoil` (`Move.slide`, `slides.contains`); pair and `.resting` exist while `!slides.isEmpty`; `dragThresholdMM` shared; the edge filter; `.windowSwipe(.began)` → `windowSwipe(_:)` builds the switcher whatever the permissions |
| R2 | `Swipe.kind` fixed at begin; phases emitted by kind (`.slide(kind, _)`); a slide never re-enters `beginOrSpoil` |
| R3 | Current Space and window-list order in `FrontmostAppWindows.sort`; `Content.init(_:)`: the full-screen front window alone, visible before minimised, the cut at 10; `content` is a `let` |
| R4 | `FrontmostAppWindows.sort` (standard visible windows on screen; minimised by `kAXMinimized` alone); `Row.minimised` drawn dimmed with the badge and the icon |
| R5 | `Displays.screen(under:)` + `visibleFrame` top-left with `margin`; `WindowColumnLayout.scale`; `OverlayPanel` (never key, click-through); `dismiss()` on nil |
| R6 | `rows` titles (`Copy.untitledWindow`); `WindowColumnLayout.previewSize(aspect:)`; the icon until `PreviewCapture` yields; one capture per `serial` at the open; the panel shown in the begin turn |
| R7 | `showsPreviews` from the pushed grant at begin; `previewWindows` empty otherwise; the capture called only then; `onChange` → `reconcile` |
| R8 | `screenRecordingHint` (setting, grant, `hasAskedForScreenRecording`); `askForScreenRecording()` → `permissions.ask(.screenRecording)`; `SettingsPane.screenRecording`; the TCC push → reconcile → refit |
| R9 | `SwipeTravel.travel(along: .windowSwipe)`, `pointsPerStep` 100; `SwitcherSelection.follow`; travel 0 at begin |
| R10 | `selectedVisibleWindow` + `system.raiseWindows([window])` in `.moved`; row 0 is the front window, so sliding back raises it; nothing when every window is minimised; a closed window is skipped by the adapter |
| R11 | the second read; `lift(now:)` and `WindowStack.raises` (restore of the first only, closed selected → no reordering); `system.raiseWindows(lift.raises)`; `window = .closed` on a changing lift |
| R12 | Ticks = `follow`'s return; `WindowLift.playsHaptic`; `windowSwipe(_:)` never calls `playLaunchAnimation` |
| R13 | `.noWindows(of:)`; a one-row `SwitcherSelection`; a single visible row's lift raises nothing and is silent |
| R14 | `.accessibilityNeeded(for: read.app)`; the existing Accessibility hint unchanged |
| R15 | `.swiping` unchanged; `.cancelled` → `shown = nil` with no read and no raise |
| R16 | `Settings.isWindowSwipeOn`, `slides`, `Run.slides`, `setWindowSwipe(on:)`, the third `SwitcherSection` row |
| R17 | One capture per `serial`, only at the open; cancelled at nil; arrivals checked against the shown serial; `emptied()`; no image type in the core; bans on streams, recordings, image encoders and file writes |

#### Testing seams

| Seam | Scenarios | Handles a test holds |
|---|---|---|
| The recognizer over `TouchScript` (`windowPhases`, `phases`, `perFrame`) | R1, R2, R15 (blocking, rejoin, thumb lift, third finger, click), R16 (each kind alone, both, neither); the old vertical-spoil rows flipped to "window swipe off" | the frame clock |
| `World`: the real `Launcher`, recognizer and filters inside `InMemoryTrackpads`, `RecordingSystemActions` with its `FakeWindows`, `InMemoryPermissions` | R3/R4 as the fake lists them, R6 titles, R7 (`showsPreviews`, `previewWindows`, no ask), R8, R9 (linear), R10, R11, R12, R13, R14, R15 (cancel, no scroll), R16 (persistence, upgrade with the frozen record) | `system.windows.set(visible:minimised:fullScreenFront:)`, `close(_:)` / `open(_:)` between `play` pieces, `answers = false`, `onScreenTitles`, `raised`, `reads`; `permissions.set(_:granted:)` (the push), `asks` |
| Pure values | `SwitcherSelection`, `Content.init`, `rows` and titles, `lift(now:)`, `WindowStack.raises`, `WindowColumnLayout` (scale, `previewSize`), `cursorMove` y, `Copy` | none |
| `LauncherPlatformTests` | `FrontmostAppWindows.sort` and `number(of:among:)` over raw facts (R3, R4 filters and order); `SystemPermissions` re-reads both on a posted broadcast and pushes only on a change (injected closures); `FrontmostAppWindows` over the test process's own windows, only when trusted | the posted notification |
| By hand | The glass, placement on two displays, shrink, motion; real AX across apps (Spaces, full screen, restore, focus, Chromium and Electron); previews arriving with the icon until then, and R17 by code review (LauncherUI has no test target); the TCC prompt and the Settings page; any relaunch; a hung app (`kill -STOP`); the periodic capture alert (F31) | none |

`FakeWindows`, held by `RecordingSystemActions` as `windows`, is a small window stack that does what `AXRaise` does and
nothing more: `raiseWindows` moves each window, last first, to the front and restores a minimised one, skipping closed
and unlisted ids, and records each call in `raised`; `frontmostWindows()` answers from the existing `frontmost` field
and the stack, so a second window swipe sees the first one's order (R11's toggle scenario). All policy stays in the
model's pure functions, so the fake carries none. The rest of `RecordingSystemActions` is unchanged.

#### Source policy and docs

- Confined, each to one file: `AXIsProcessTrusted`, `notify_register` and `ScreenCaptureAccess` (the preflight and the
  request) to `SystemPermissions.swift`; `AXUIElement` (which covers `_AXUIElementGetWindow`) and `CGWindowList` to
  `FrontmostAppWindows.swift`; `ScreenCaptureKit`, `SCShareableContent` and `SCScreenshotManager` to
  `PreviewCapture.swift`.
- Banned: `SCStream(` and `SCRecordingOutput` (pictures, never a stream or a recording; `SCStreamConfiguration(` does
  not match); `CGImageDestination`, `representation(using` and `tiffRepresentation` (a picture is never encoded or
  written); `AXUIElementSetAttributeValue` and `kAXPressAction` (the switcher only picks a window). None of these
  appears in the sources today. The "R9 only Accessibility" labels become "no Input Monitoring or event posting". The
  scan matches comments, so no other file may spell a confined name, even in a doc comment.
- `docs/architecture.md`: Shape names the Accessibility element API and the private window number among
  `LauncherPlatform`'s frameworks, and ScreenCaptureKit in `LauncherUI` for window previews. Concurrency: a window
  swipe's phases hop like a swipe's; the window reads and raises are synchronous AX IPC on the main actor under a short
  timeout; the window list's first call is paid off the main actor at launch; previews are captured off the main actor.
  Privacy: two optional permissions and what each is used for; previews in memory only; the private window number with
  its fallback; the confinement sentence covering the AX element API, the window list and capture.
- `docs/domain-model.md`: the plan's new terms (window swipe, window switcher, window, front window, window swipe
  setting, screen recording hint) and the changed entries.

### Synthesis decision

**The arena.** Three candidates answered the same task and grounding. Candidate-2 (Fable) and candidate-1 (Opus) come
from the earlier run; candidate-1's runner finished after that run's architect stopped on a Fable quota error, so this
run believed it missing and dispatched an Opus runner, which wrote candidate-3 over candidate-1's path. The judged
candidate-1 was restored verbatim and the late package kept as candidate-3. Fable being out of quota, the cross-judge
ran on Opus, the model behind candidates 1 and 3; my own criterion-by-criterion pass is the check on that bias.

**Scores** (rubric C1 to C5, 0 to 3 each):

| | C1 | C2 | C3 | C4 | C5 | Judge | Mine |
|---|---|---|---|---|---|---|---|
| candidate-1 | 3 | 2 | 2 | 2 | 3 | 12 | 12 |
| candidate-2 | 2 | 2 | 2 | 3 | 2 | 11 | 11 |
| candidate-3 | 2 | 3 | 2 | 2 | 2 | 13 | 11 |

The row scores are mine. The judge gave candidate-3 a 3 on C1 and C5 where I give 2: it changes the gesture hint and
closes the launcher window on the ask, neither asked for, and its all-minimised case is an optional rather than a
variant.

**Base: candidate-1**, for its content types (`.front` / `.minimisedOnly`, the `Row` enum, the per-swipe `serial`)
and its event shape. The judge recommended candidate-1 over candidate-2, then candidate-3 once it had scored it, mainly
because candidate-3 already ran the lift's policy in the model over a second read and kept the window methods on
`SystemActions` (Preserve 5 and 7). Both of those are grafted below, which leaves two differences to carry the label.
The event shape: candidate-1's `.windowSwipe` case leaves the 78 bare `.began` uses in 18 files untouched, where
`.began(axis)` would change every one, and gives each action its own handler. The content types: the judge also
preferred candidate-1's.

**Grafted.**
- From candidate-3:
  - the lift as a pure plan over a second read in the model (`lift(now:)`, `WindowLift`), the adapter only raising and
    the fake only emulating `AXRaise`;
  - the window read and raise on `SystemActions`, with the work in one platform type;
  - the adapter's pure `sort` and `number(of:among:)`;
  - `previewSize(aspect:)` and `previewPixels(scale:)`;
  - the encoder bans;
  - the open question on a window opened mid-swipe.
- From candidate-2:
  - one look value with `.shipped`;
  - separate button titles for asking and for opening System Settings;
  - the open question on a minimised window that belongs to another Space.
- From the judge's review of candidate-1:
  - the messaging timeout set once on the system-wide element (`AXUIElement.h`: per element otherwise);
  - a lift with no window in front is silent;
  - R11's rules in one pure function rather than in both adapters, which the candidate-3 lift settles.
- From verification:
  - `WindowStack.raises` compares against every visible window of the app now, so the selected window ends in front
    even past one opened mid-swipe;
  - core comments never spell a confined name;
  - the usage's second window swipe continues the first hand's script, as `World.play` requires.

**Convergence**, shipped as consensus:
- All three agree on:
  - one `.swiping` state, with the kind fixed at begin and a set of enabled kinds;
  - the selection maths extracted and shared;
  - one stored enum for the open switcher;
  - only visible windows raised while sliding;
  - `AXRaise` to restore;
  - the on-screen window list for the current Space;
  - `_AXUIElementGetWindow` with frame matching;
  - the TCC push;
  - the panel at the top-left of `visibleFrame`;
  - 100 points per row and the cut at ten rows;
  - a persisted "asked" flag.
- Candidates 1 and 3 agree on previews in the shell, one `Permissions` port and a shared `OverlayPanel`.

**A disagreement, resolved.** My first draft grafted candidate-2's capture port, which carried previews as bytes
through the model. The judge recommended keeping previews in the shell, citing plan 008's icon decision, and
candidate-3 chose the same on its own. A preview is to a `WindowID` what an icon is to an `AppEntry`, no decision reads
it, and live previews would later mean frames through the model, so the shell keeps them. The cost is that preview
arrival is checked by hand, as is all `LauncherUI` rendering. I declined the judge's suggested fresh grant read at each
begin, because a preflight costs about 4 ms on the calling thread (check-1). The judge agreed.

**Rejected.**
- From candidate-2:
  - the capture port and the bitmap type;
  - `.began(axis)`;
  - the missing full-screen rule;
  - the World test that contradicted its own lift.
- From candidate-3:
  - `.began(axis)`;
  - the optional front window and the per-row minimised flag;
  - a timeout that stops only the current call;
  - comparing content instead of using a per-swipe serial;
  - closing the launcher window on the ask.
- From candidate-1:
  - `stack` deciding and answering from inside the adapter, which now lives in the model;
  - the separate `AppWindows` port, which loses to Preserve 7.
- From candidates 2 and 3: the gesture hint change, which no requirement asks for.

### Tradeoffs accepted

- We accept AX calls synchronously on the main actor (about a millisecond to read, about 2 ms per raise), bounded by a
  0.2 s process-wide messaging timeout with no further raises to an app after its first timeout, in exchange for a
  synchronous model and model tests with no held reads. An app that hangs mid-swipe can stall the main actor for up to
  0.2 s at the raise that meets it and again at the lift's read; one that hangs before the begin costs 0.2 s once and
  shows "No open windows".
- We accept a second window read at the lift (about a millisecond) in exchange for a lift that follows the windows as
  they are, whatever the raises while sliding did, with every R11 and R12 rule in one pure function.
- We accept that preview arrival, the icon until a picture is ready, and the discard are checked by hand and in code
  review, as every other `LauncherUI` rendering is, in exchange for pictures with one owner, a lifetime derived from
  the model value, and no image channel through the core.
- We accept ScreenCaptureKit in `LauncherUI`, a first permission-gated API outside `LauncherPlatform`, in exchange for
  keeping a rendered asset beside the icons it stands in for; the capture runs only when the model says so, and its
  names are confined to one file.
- We accept gating previews on the grant the last TCC push left, not a fresh read at each begin (about 4 ms, check-1):
  a revocation reaches the model through the push within about 30 ms.
- We accept two more methods on `SystemActions`, delegated by `WorkspaceActions` to `FrontmostAppWindows` as
  `runningApps()` is to `RunningAppsReader`, and a window stack inside the recording fake, in exchange for no new port
  (`why.md` Preserve 7) and the window knowledge in one platform type its tests construct alone. The ordering rule
  "`raiseWindows` names windows of the latest read" is stated on both methods.
- We accept renaming `AccessibilityPermission` to `Permissions` across the tests and the composition root in exchange
  for one module that owns the one TCC broadcast; on a burst of broadcasts each post re-reads both grants (about 4 ms
  for Screen Recording), which happens only while someone changes a permission.
- We accept that a lift on the front window may raise windows when the user slid away and back, in exchange for one
  lift rule that restores the order the user left.
- We accept `WindowID` being the window server's number: a macOS without `_AXUIElementGetWindow` falls back to frame
  matching and leaves unmatched windows out.
- We accept one `pointsPerStep` (100) for both slides, so the Debug tuner moves them together.
- We accept a wasted AX read without Accessibility (it fails at once) in exchange for one read path that always yields
  the app for R14's row.
- We accept that a lift that changes the window in front closes the launcher window, as the swipe's lift does,
  because a key launcher window would otherwise keep the keyboard from the raised window.
- We accept both presenters waking on every write to `shown` (the idle one sees nil and returns) in exchange for "at
  most one switcher" being a property of the type.
- We accept, with the window swipe setting on, that two fingers sliding up or down under an anchored thumb no longer
  scroll after the blocking window: R16's switch is the way out (`why.md` Risk 1).

### Alternatives considered

- **Previews through the model behind a capture port.** The Screen Recording permission and capture as one port
  delivering bitmap bytes, held in the `WindowSwitcher` value. It gives `World` a handle on arrival and checks the
  grant at the OS boundary, but it exposes a capture method and a push on a port, a domain bitmap type, a relay in the
  model, and state no decision reads; it repeats what plan 008 refused for icons; and live previews would then mean
  frames through the model. Lost on depth and locality.
- **`stack(order)` converging inside the adapter and answering the window in front.** A deeper-looking port, but its
  answer is itself a prediction (raises land in the window server after the call returns), it puts R11's closed and
  minimised rules inside both adapters, and it cannot see another app having come forward. Lost on locality.
- **A separate two-method `AppWindows` port.** It keeps the window knowledge and the "latest read" rule on a module of
  its own with its own fake and no delegation in `WorkspaceActions`, but it is a new port for what is a read beside
  `runningApps()` and an effect beside `bringToFront`, the shape the grounding asks to preserve. Lost narrowly.
- **A separate Screen Recording permission port beside `AccessibilityPermission`, with a shared TCC listener.** No
  rename, but two ports of the same shape over one broadcast, each re-reading on every post. Lost on depth.
- **One `.swipe(.began(kind))` event and one model handler.** One fewer enum case, but every phase in the model then
  branches on what is open, and every `.began` site in the tests changes. Lost on reader load.
- **A second recognizer state or recognizer for vertical slides.** Duplicates rejoin, cancel, thumb and blocking, and
  makes two places decide direction (`why.md` Avoid 1). Rejected.
- **Raises on a serial background queue, or an async window read.** The main actor would never wait on another app,
  but the model would gain a loading state and a lift that can arrive before the read lands. For a read of about a
  millisecond, bounded timeouts instead.

### Open questions and risks

1. Does vertical pointer acceleration use the same multiplier on `dy` (O1)? The sketch assumes symmetry; the first
   hardware check should compare a vertical slide's feel with a sideways one at the same tracking speed.
2. A minimised window may belong to another Space, and restoring it on the lift may switch Spaces (F24). Is that
   acceptable because the user picked that window?
3. One minimised window and nothing else: R13 says one window changes nothing, R11 says every window minimised
   restores with the haptic. The design restores. Is that right?
4. Edge readings of R11 and R12 the design makes, for you to confirm: when the front window closes mid-swipe and the
   user lifts on its row, the haptic plays because another window is now in front; when every listed window has
   closed, the lift is silent; when the app opens a window in front mid-swipe, a lift on the front window brings the
   front window back above the new one; when another app is in front at the lift, nothing is raised.
5. Is 0.2 s the right AX messaging timeout? Apps whose accessibility tree wakes on the first query (Chromium, O5) may
   read as "No open windows" on the first window swipe.
6. Since macOS 15, capture without the system picker can bring a periodic system alert (F31). Acceptable for a few
   pictures per window swipe, or should previews wait for a product decision?
7. If macOS needs a relaunch after the grant (F30), the hint stays until the relaunch. Acceptable under R8?
8. Without Accessibility, thumb plus two fingers sliding up or down may open Mission Control, since Dock-swipe blocking
   needs the event tap (`why.md` Risk 2). Should R14 say so?
9. Two- and three-finger taps that drift up or down past 3 mm will flash the window switcher, as sideways drift already
   flashes the app switcher (`why.md` Risk 3).
10. Should the launcher window's gesture hint mention the window swipe? The design leaves it unchanged.
11. `AXRaise` restoring a minimised window was probed on TextEdit only, and the source policy bans attribute writes; an
    app whose raise does not restore would need that ban lifted deliberately.

### Next implementation step

Test first through `TouchScript`: thread `SlideKind` through `beginOrSpoil`, `SwipeTravel.travel(along:)` and
`TrackpadHardware.run(slides:)`, with today's vertical-spoil tests pinned under `slides: [.swipe]`.
