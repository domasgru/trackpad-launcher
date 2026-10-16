## Design

### Problem

The window swipe has to be a sibling of the swipe, not a second feature built beside it. Two fingers under an anchored
thumb already run through one recognizer (`GestureRecognizer`), one finger session, one blocking rule, one event hop
and one model handler. Today a first drag past 3 mm that is not strictly sideways spoils the pair. The shape is hard
to see because the new action brings several firsts. It is the first effect on the system while the fingers are
still moving: raising windows changes the state the lift then reads. It is the first use of the `AXUIElement` family,
the first private window API (`_AXUIElementGetWindow`) and the first second permission (Screen Recording). It is also
the first time asynchronous images belong to a gesture, and they may never enter `LauncherCore` or cross a port.

The grounding fixes these constraints:
- The module graph: `LauncherUI` cannot see `LauncherPlatform`.
- `notify_register` is confined to one file.
- Every port has exactly two adapters.
- There are no timers, and AX calls are synchronous IPC bounded by a messaging timeout.
- `AXRaise` restores a minimised window and switches Spaces for a window on another Space.
- A closed window's element answers `-25202`.
- A minimised window's subrole is unreliable.
- `CGWindowListCreateImage` is gone, so only ScreenCaptureKit can capture.
- The lift must not depend on anything the raises changed while sliding.

### Usage (caller's view)

**README for the next maintainer.** A slide is either a *swipe* (more sideways) or a *window swipe* (more up or
down). The recognizer decides which on the frame the farthest finger passes 3 mm, keeps that decision until both
fingers lift, and reports each phase as `.swipe(phase)` or `.windowSwipe(phase)` through the same hop. The model has
one place per action that turns events into effects: `Launcher.swipe(_:)` and `Launcher.windowSwipe(_:)`. The shell
draws `launcher.windowSwitcher`, a value whose content is fixed when the window swipe begins. Its selection is the
same `SwitcherSelection` maths the app switcher uses.

The model reaches the frontmost app's windows through one two-method port, `AppWindows`:
- `frontmost()` reads the windows once.
- `stack(_:)` puts some of those windows in front, in a given order, and returns which one ended in front.

Previews are a shell asset, like icons. The model says whether rows show previews and which windows to capture. The
window switcher's presenter captures those windows and holds the pictures for as long as that window switcher is on
screen.

**Call site 1: the model, the one place a window swipe becomes effects (`LauncherCore`).**

```swift
private func windowSwipe(_ event: SwipeEvent) {
    switch event.phase {
    case .began:
        guard shown == nil, activity.isActive else { return }
        windowSwipesBegun += 1
        let read = windows.frontmost()
        let content = isAccessibilityGranted
            ? WindowSwitcher.Content(read)
            : .accessibilityNeeded(for: read.app)
        shown = .windows(WindowSwitcher(
            content, showsPreviews: isScreenRecordingGranted, serial: windowSwipesBegun, trackpad: event.trackpad))
    case .moved(let travel):
        guard case .windows(var open)? = shown, open.trackpad == event.trackpad else { return }
        let crossed = open.selection.follow(travel)
        shown = .windows(open)
        for _ in 0..<crossed { hardware.playFeedback(.lightTick, on: event.trackpad) }
        // Only a visible window comes forward while sliding: raising a minimised one would restore it.
        if crossed > 0, let window = open.selectedVisibleWindow { windows.stack([window]) }
    case .ended:
        guard case .windows(let open)? = shown, open.trackpad == event.trackpad else { return }
        shown = nil
        // A message row has nothing to switch: silent.
        guard let order = open.liftOrder else { return }
        let inFront = windows.stack(order)
        // R12's one rule; a restored minimised window is never the front window, so it is covered.
        guard inFront != open.frontWindow else { return }
        hardware.playFeedback(.gesture, on: event.trackpad)
        window = .closed
    case .cancelled:
        // Kept as it is: no reordering, silent.
        if case .windows(let open)? = shown, open.trackpad == event.trackpad { shown = nil }
    }
}
```

**Call site 2: the shell renders the value and owns the pictures (`LauncherUI`).**

```swift
private func render(_ switcher: WindowSwitcher?) {
    guard let switcher else {
        capture?.cancel()
        shownSerial = nil
        // Fades, then `emptied()` drops every picture.
        panel.dismiss()
        return
    }
    if switcher.serial != shownSerial { open(switcher) }
    panel.show(position: switcher.selection.position, selected: switcher.selection.selected)
    if switcher.selection.stretch != lastStretch, switcher.selection.stretch != 0, !reduceMotion {
        panel.springHighlight(fromY: switcher.selection.stretch * layout.pitch)
    }
    lastStretch = switcher.selection.stretch
}

private func open(_ switcher: WindowSwitcher) {
    let screen = Displays.screen(under: NSEvent.mouseLocation)
    let visible = screen?.visibleFrame ?? .zero
    layout = WindowColumnLayout(
        rowCount: switcher.rows.count, widestTitle: panel.widestTitle(switcher.rows),
        displayHeight: visible.height)
    panel.lay(
        out: switcher.rows, icon: switcher.app.map(icons.icon(forSwitcher:)), layout: layout,
        topLeft: NSPoint(x: visible.minX + WindowColumnLayout.margin, y: visible.maxY - WindowColumnLayout.margin))
    shownSerial = switcher.serial
    panel.present(animated: !reduceMotion)
    capture?.cancel()
    guard !switcher.previewWindows.isEmpty else { return }
    let serial = switcher.serial
    let rows = switcher.rows
    capture = Task { [weak self] in
        let pictures = PreviewCapture.pictures(
            of: switcher.previewWindows, fitting: layout.previewBox, scale: screen?.backingScaleFactor ?? 2)
        for await (window, picture) in pictures {
            guard let self, shownSerial == serial, let row = rows.firstIndex(showing: window) else { return }
            panel.setPreview(picture, row: row, animated: !reduceMotion)
        }
    }
}
```

**Call site 3: a test at the high seam (`World`).** The fake `AppWindows` keeps a small window stack.

```swift
@Test func liftingOnNewsStacksNewsThenTheFrontWindowThenTheRest() {
    let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
    // Begin, then two rows down, then lift.
    world.windowSwipe(3.5, 24)
    #expect(world.windows.onScreenTitles == ["News", "Docs", "Mail"])
    #expect(world.hardware.lightTicks.count == 2)
    #expect(world.hardware.feedback == [Trackpad.macBook14.id])
    #expect(world.system.launchAnimations.isEmpty)
    world.windowSwipe(3.5, lift: false)
    #expect(world.launcher.windowSwitcher?.rows.map(\.title) == ["News", "Docs", "Mail"])
}

@Test func aSelectedWindowThatClosesLeavesTheWindowsAsTheyAre() {
    let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
    let hand = world.windowSwipe(3.5, 12, lift: false)
    #expect(world.windows.onScreenTitles == ["Mail", "Docs", "News"])
    // Docs is in front again.
    world.windows.close("Mail")
    world.play(hand.lift())
    #expect(world.windows.onScreenTitles == ["Docs", "News"])
    #expect(world.hardware.feedback.isEmpty)
}
```

**Call site 4: the launcher window (`LauncherUI` views).**

```swift
// SwitcherSection, the third row:
SettingRow(illustration: "window-swipe", title: "Swipe up or down to switch windows",
           isOn: Binding(get: { launcher.isWindowSwipeOn }, set: { launcher.setWindowSwipe(on: $0) }))
// LauncherView, after the Accessibility hint:
if let hint = launcher.screenRecordingHint {
    SettingsNotice(message: Copy.screenRecordingHint, button: "Allow Screen Recording…", open: {
        switch hint {
        case .ask: launcher.askForScreenRecording()
        case .openSettings: actions.openSettings(.screenRecording)
        }
    })
}
```

**Call site 5: the recognizer, over scripted frames.**

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

**Data first.** The data runs through these values, in order:
1. The adapter's read, `FrontmostWindows`: the app, its visible windows in front-to-back order, and its minimised
   windows in app order.
2. The parse at the boundary, `WindowSwitcher.Content.init(_:)`, which yields a sum type:
   - `windows(of:, WindowList)`, where `WindowList` is either `.front(…)` or `.minimisedOnly(…)`;
   - `noWindows(of:)`;
   - `accessibilityNeeded(for:)`.
3. The derived views: `rows`, `frontWindow`, `selectedVisibleWindow`, `liftOrder` and `previewWindows`.

The common access patterns all read the same fixed value:
- the presenter draws rows;
- a move raises the selected visible window;
- the lift stacks `liftOrder`.

Nothing is added later as an index or a cache.

**Load-bearing decisions.**

- **One recognizer state, kind fixed at begin.** `beginOrSpoil` stays the single place a slide's direction is
  decided, per model-the-domain:
  - `Move.slide` is strict both ways, so a tie spoils.
  - `slides: Set<SlideKind>` replaces `swipes: Bool`.
  - `Swipe.kind` is a `let`.
  - `.swiping` is unchanged, so the blocking, rejoin, thumb, cancel and end rules apply to both kinds by construction
    (R15).
  - A pair and `.resting` exist when any slide is on (R16: swipe off with window swipe on). With only one kind on, the
    other axis spoils exactly as today.
- **Phases by kind, same hop.** `Recognition.Event.windowSwipe` and `TrackpadEvent.windowSwipe` are new cases, so the
  compiler routes a window swipe's phases to its own handler (per type-system-discipline). The hop, the generation
  check and `TrackpadEvent.init` are untouched.
- **Travel along the slide.** `PointerCurve.cursorMove` returns both components, scaled by the same speed-dependent
  multiplier. `SwipeTravel.travel(along:)` picks the component. One step is 100 cursor points on either axis, which
  is the icon pitch and also R9's row.
- **One selection rule.** `SwitcherSelection` is extracted from `Switcher` unchanged and shared by both switchers.
  `follow` returns the number of items crossed, which is the tick count.
- **At most one switcher on screen.** The model stores `shown: ShownSwitcher?`, with the cases `.apps` and
  `.windows`, and derives `switcher` and `windowSwitcher` from it. `reconcile` clears both with one write.
- **Content as a construction, not flags** (per type-system-discipline):
  - The front window exists only in `.front`, and the all-minimised case is its own variant.
  - A message row exists only as the single row of a message content.
  - `liftOrder` is nil exactly when there is nothing to switch.
  - The rules live in the one parse: full-screen front only, visible before minimised, the cut at 10, and leaving
    out non-front full-screen windows (per boundary-discipline).
- **The port answers its own outcome.** `stack` returns the listed window in front afterwards, so the lift decides
  the haptic from the effect's exact result (R11, R12) and needs no second read (per make-operations-idempotent).
  - A lift on the front window is the same rule as any other lift: the target is the original order.
  - The adapter raises only what is out of place, so a lift on the front window that slid nowhere makes no raise
    (R5's focus scenario). One that slid away and back restores the order.
  - A closed first window changes nothing.
  - `WindowStack.raises(current:target:)` is the one pure rule both adapters use, on the precedent of
    `TrackpadEvent.init` and `TouchFrame.Press`.
- **One TCC module.** The `Permissions` port replaces `AccessibilityPermission`. It owns both permissions and the one
  `notify_register`, and each broadcast re-reads both (F29; per separate-before-serializing-shared-state: one writer
  of the registration). The R8 hint is derived from three facts: the setting, the grant, and the persisted
  `hasAskedForScreenRecording`.
- **Previews are rendered assets, not model state.** No decision reads a picture.
  - The model decides whether rows show previews (R7, gated at begin) and which windows (visible ones only, R4).
  - The presenter captures exactly `previewWindows` once per `serial`. Their lifetime is derived from the observed
    value, so every exit path (lift, cancel, reconcile) discards them by construction (per minimize-reader-load).
  - R17 is structural:
    - the capture task is cancelled at nil;
    - each arrival is checked against the shown serial;
    - `OverlayPanel.emptied()` drops layer contents once the panel is out;
    - the source policy bans streams, recordings and image encoders.
- **Window identity is the window server's number.** `WindowID(rawValue: UInt32)` brands the one identity that AX
  (`_AXUIElementGetWindow`), the window list and ScreenCaptureKit share. It is what lets the shell capture without an
  image channel through Core.

**Interface depth.** `AppWindows` has two methods. Behind them sit:
- AX IPC with a 0.2 s per-element messaging timeout, and giving up on an app after its first timeout;
- the private window number and its frame-matching fallback;
- Space limiting by the on-screen window list;
- subrole filtering for visible windows only (F9);
- the full-screen sibling;
- closed-element errors;
- minimal raises;
- focus.

The model's public surface grows by:
- `windowSwitcher`;
- `isWindowSwipeOn` / `setWindowSwipe(on:)`;
- `screenRecordingHint` / `askForScreenRecording()`.

The grant itself stays private, because the hint and `showsPreviews` carry it.

**What it deliberately does not do:**
- No main-to-frame channel: the recognizer never learns about windows, and a window swipe always runs its course
  blocked.
- No window state between swipes in the model.
- No restore while sliding.
- No raise of an unlisted window, which might be on another Space.
- No prompt from a swipe.
- No live previews.
- No attribute writes: the policy bans closing, minimising and moving windows.
- No change to the gesture hint text.

#### Module map

| Module | New or changed |
|---|---|
| LauncherCore | `SlideKind`; `GestureRecognizer` (`slides`, `beginOrSpoil`, `Swipe.kind`); `SwipeTravel.travel(along:)`, `PointerCurve.cursorMove`; `SwitcherSelection` (new), `Switcher` holds one; `AppWindow`, `WindowID`, `FrontmostWindows`, `WindowStack` (new); `WindowSwitcher` (new); `WindowColumnLayout` (new); ports `AppWindows` (new), `Permissions` (replaces `AccessibilityPermission`), `TrackpadEvent.windowSwipe`, `TrackpadHardware.run(slides:)`; `Settings.isWindowSwipeOn`, `.hasAskedForScreenRecording`, `.slides`; `Copy` strings; `Launcher` (`shown`, `windowSwipe(_:)`, setters, hint) |
| LauncherPlatform | `AccessibilityWindows` (new, the `AppWindows` adapter); `SystemPermissions` (was `SystemAccessibilityPermission`); the per-begin travel hook in the frame session fires for either kind; `MultitouchTrackpads.run(slides:)`; `CursorTravel` uses `pointsPerStep` |
| LauncherUI | `OverlayPanel` (new base, shared with the app switcher's panel), `Displays.screen(under:)` (moved); `WindowSwitcherPanel`, `WindowSwitcherPresenter`, `WindowSwitcherStyle`, `PreviewCapture` (new); `SwitcherSection` third row; `LauncherView` hint; `SettingsPane.screenRecording`; `MenuBarShell` builds the presenter and adds `screenRecordingHint` to the refit observation |
| App target | wires `AccessibilityWindows()` and `SystemPermissions()` |
| Tests | `InMemoryWindows`, `InMemoryPermissions`, `World.windowWorld` / `windowSwipe` / `windows`, the `windowPhases` driver, `slides:` at every recognizer construction site |

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

/// A swipe's or a window swipe's progress. The event case says which. (Fixes the three stale comments.)
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
    // New case beside .fired, .swipe, .swap:
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
    // beginOrSpoil: the one place a slide's direction is decided:
    //     guard let pair, let kind = move.slide, slides.contains(kind) else { return (.spoiled(anchor), nil) }
    //     return (.swiping(Swipe(kind: kind, fingers: …, lastTime: time, thumb: anchor)), .slide(kind, .began))
    //
    // Move:       var slide: SlideKind? { abs(dxMM) > abs(dyMM) ? .swipe : abs(dyMM) > abs(dxMM) ? .windowSwipe : nil }
    //
    // .swiping:   travel = swipe.travelMM
    //                 + self.travel.travel(along: swipe.kind, dxMM: dxMM, dyMM: dyMM, interval: interval)
    //             every phase is emitted as .slide(swipe.kind, phase); blocking stays `if case .swiping = state`
}

extension PointerCurve {
    /// Cursor points the pointer moves along x and y for one report of finger movement: the HID event system scales
    /// the whole delta by one speed-dependent multiplier (y by symmetry with x; open question 5).
    public func cursorMove(dxMM: Double, dyMM: Double, interval: Double) -> (x: Double, y: Double) {
        fatalError("not implemented")
    }
}

public enum SwipeTravel: Equatable, Sendable {
    case linear
    case cursor(PointerCurve, pointsPerStep: Double)
    /// 100 cursor points per step: the app switcher's icon pitch, and the window switcher's row (R9).
    public static let shippedPointsPerStep = 100.0
    /// `.linear`: the millimetres along the slide. `.cursor`: the cursor's points along it ÷ pointsPerStep × 12.
    func travel(along kind: SlideKind, dxMM: Double, dyMM: Double, interval: Double) -> Double {
        fatalError("not implemented")
    }
}

// MARK: Selection, shared by both switchers

/// Where the fingers have taken a switcher's selection along its fixed list: the nearest item; hard stops at both
/// ends; a rubber band of at most a quarter step that is forgotten the moment the fingers turn back (no dead zone).
public struct SwitcherSelection: Equatable, Sendable {
    /// At least 1.
    public let count: Int
    public package(set) var travelMM: Double = 0
    private var reportedMM: Double = 0
    package init(count: Int) { fatalError("not implemented") }
    /// Takes the slide's absolute travel. Returns how many items the selection crossed: one light tick each.
    package mutating func follow(_ reportedMM: Double) -> Int { fatalError("not implemented") }
    public var selected: Int { fatalError("not implemented") }
    public var position: Double { fatalError("not implemented") }
    public var stretch: Double { fatalError("not implemented") }
}
// Switcher keeps `row`, `startsOnFrontmost`, `selectedApp`, `selectsFrontmost` and `trackpad`; its maths moves into
// `public internal(set) var selection: SwitcherSelection`.

// MARK: Windows

/// The window server's number for one window. The Accessibility, window-list and capture APIs all report this same
/// number.
public struct WindowID: Hashable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}

/// One of an app's normal document or app windows, as one read found it.
public struct AppWindow: Equatable, Sendable, Identifiable {
    public let id: WindowID
    /// As the app titles it. "" when the window has no title.
    public let title: String
    public let isFullScreen: Bool
}

/// One read of the frontmost app's windows.
public enum FrontmostWindows: Equatable, Sendable {
    /// There is no active app, or it is Trackpad Launcher itself.
    case noApp
    /// `visible`: its windows on the current Space, front to back. Panels, palettes, sheets and other helpers are left
    /// out. `minimised`: its minimised windows, in the order the app lists them. Both are empty when it has none,
    /// when Accessibility is missing, or when the app did not answer in time.
    case app(AppEntry, visible: [AppWindow], minimised: [AppWindow])

    public var app: AppEntry? { fatalError("not implemented") }
}

/// How raising windows one at a time, each in front of all the others, reaches an order.
public enum WindowStack {
    /// The windows of `target` to raise, back to front, so that `target` ends front to back in front of the rest of
    /// `current` (front to back, on screen). A target window that is not on screen is raised only if it is the first
    /// (a minimised window to restore); otherwise it is skipped. Empty when `target` is already in place. This is the
    /// smallest k such that `current` without `target[..<k]` starts with the on-screen part of `target[k...]`.
    public static func raises(current: [WindowID], target: [WindowID]) -> [WindowID] { fatalError("not implemented") }
}

// MARK: The window switcher

/// The window switcher during one window swipe. Its content is fixed when the window swipe begins: a window that
/// opens later is not added, and one that closes stays listed. The selection follows the travel.
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
        /// The front window, then the other visible windows front to back, then the minimised ones in the app's order.
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
    }

    public let content: Content
    public internal(set) var selection: SwitcherSelection
    /// Screen Recording was granted when the window swipe began, so visible rows show previews (R7).
    public let showsPreviews: Bool
    /// Counts the window swipes since launch. The presenter uses it to tell one window swipe's switcher from the next,
    /// so a picture taken for one never shows in another.
    public let serial: Int
    public let trackpad: TrackpadID

    /// The selection count is `rows.count`: one for a message.
    package init(_ content: Content, showsPreviews: Bool, serial: Int, trackpad: TrackpadID) {
        fatalError("not implemented")
    }

    /// Whose windows these are, and whose icon a row shows. nil: no frontmost app.
    public var app: AppEntry? { fatalError("not implemented") }
    /// Top to bottom. A window with title "" reads as the app's name, plus " — Window N" when there is more than one
    /// row, N being its 1-based row (`Copy.untitledWindow`).
    public var rows: [Row] { fatalError("not implemented") }
    /// The app's window in front when the window swipe began. nil when every window is minimised, or for a message.
    public var frontWindow: WindowID? { fatalError("not implemented") }
    /// The windows to capture: the visible ones while `showsPreviews`, else none.
    public var previewWindows: [WindowID] { fatalError("not implemented") }
    /// The window that comes to the front while its row is selected. nil for a minimised window or a message (R10).
    public var selectedVisibleWindow: WindowID? { fatalError("not implemented") }
    /// What lifting stacks, front to back: the selected window, then the visible windows in their order from the
    /// begin (front window first) without it. nil for a message: nothing to switch (R11, R13, R14).
    public var liftOrder: [WindowID]? { fatalError("not implemented") }
}

extension WindowSwitcher.Content {
    /// The one parse from what the system read to what the switcher lists:
    /// - `.noApp`, or an app with no windows, reads as `.noWindows`.
    /// - A full-screen front window is the single row.
    /// - Other full-screen windows are left out.
    /// - Visible windows come before minimised ones.
    /// - The list is cut at 10.
    package init(_ read: FrontmostWindows) { fatalError("not implemented") }
}

/// Where the window switcher's rows and highlight sit. One column of `rowCount` rows on a display whose visible frame
/// is `displayHeight` points tall. When the column would not fit, everything shrinks by one factor. Pure: tested in
/// core, as `SwitcherRowLayout` is.
public struct WindowColumnLayout: Equatable, Sendable {
    public static let margin = 12.0, panelPadding = 8.0, rowGap = 2.0, rowInset = 6.0
    public static let previewWidth = 120.0, previewHeight = 60.0, iconSide = 44.0, titleGap = 12.0
    public static let minTitleWidth = 180.0, maxTitleWidth = 320.0, titleSize = 13.0
    public let rowCount: Int
    /// 1 when the column fits at full size; otherwise below 1.
    public let scale: Double
    public init(rowCount: Int, widestTitle: Double, displayHeight: Double) { fatalError("not implemented") }
    /// Row height plus gap: the highlight's travel per row.
    public var pitch: Double { fatalError("not implemented") }
    public var previewBox: (width: Double, height: Double) { fatalError("not implemented") }
    public var panelSize: (width: Double, height: Double) { fatalError("not implemented") }
    /// The top of a row, measured down from the panel's top edge, for a position counted in rows.
    public func rowTop(at position: Double) -> Double { fatalError("not implemented") }
}

// MARK: Ports

/// The frontmost app's windows. Real: AccessibilityWindows. Test: InMemoryWindows.
@MainActor public protocol AppWindows: AnyObject {
    /// Reads the frontmost app's windows now, on the calling thread: about a millisecond, and at most one messaging
    /// timeout (0.2 s) when the app does not answer. Reads only: it never raises, moves or restores anything. The
    /// windows it lists are the only ones a later `stack` may name.
    func frontmost() -> FrontmostWindows

    /// Brings windows of the latest `frontmost()` to the front of their app, front to back in this order:
    /// - It raises only the windows out of place, back to front.
    /// - The first window ends with the keyboard focus, and is restored if it is minimised.
    /// - A later minimised window is never restored.
    /// - A window that has closed is skipped. When the first has closed, nothing changes.
    /// - It never touches a window that read did not list.
    /// Returns the listed window in front of the app afterwards, or nil when none is on screen. A couple of
    /// milliseconds per raise; once the app has timed out, it makes no further calls to it.
    @discardableResult func stack(_ frontToBack: [WindowID]) -> WindowID?
}

public enum Permission: Hashable, Sendable { case accessibility, screenRecording }

/// The permissions macOS grants the app. Real: SystemPermissions. Test: InMemoryPermissions.
@MainActor public protocol Permissions: AnyObject {
    /// Runs on the main actor after either permission changed, and only then. It carries no data: re-read.
    var onChange: (@MainActor () -> Void)? { get set }
    /// Read fresh. Never prompts.
    func isGranted(_ permission: Permission) -> Bool
    /// Asks macOS for it: the system's prompt. Returns at once; the prompt belongs to another process.
    func ask(_ permission: Permission)
}

// TrackpadEvent gains `case windowSwipe(SwipeEvent)`; `TrackpadEvent.init(_:on:)` maps it.
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
    // private enum ShownSwitcher: Equatable { case apps(Switcher), windows(WindowSwitcher) }
    // private var shown: ShownSwitcher?   // written only by swipe(_:), windowSwipe(_:) and reconcile()
    public var switcher: Switcher? { fatalError("not implemented") }
    /// Non-nil for the whole of a window swipe: it always shows (R13).
    public var windowSwitcher: WindowSwitcher? { fatalError("not implemented") }
    public var isWindowSwipeOn: Bool { fatalError("not implemented") }
    /// nil while the window swipe setting is off or Screen Recording is granted (R8).
    public var screenRecordingHint: ScreenRecordingHint? { fatalError("not implemented") }
    /// Saved at once. The recognizers are rebuilt, so the next slide obeys it and a window swipe in progress ends.
    public func setWindowSwipe(on: Bool) { fatalError("not implemented") }
    /// Only while the hint is `.ask`. Records the ask, saves, and then asks: a crash in between never asks twice.
    public func askForScreenRecording() { fatalError("not implemented") }
    // reconcile: isScreenRecordingGranted = permissions.isGranted(.screenRecording) is read on every push, before the
    // Run guard. Run.slides = settings.slides, so a Screen Recording change never restarts the trackpads.
    // GestureRules: windowSwitcherMaxRows = 10.
    // Copy: noOpenWindows, allowAccessibilityToSwitchWindows, minimisedBadge,
    //       untitledWindow(of:position:rows:), screenRecordingHint.
}
```

#### Platform and shell signatures

```swift
/// AppWindows over the Accessibility API and the window list.
@MainActor public final class AccessibilityWindows: AppWindows {
    static let messagingTimeout: Float = 0.2
    /// Resolves `_AXUIElementGetWindow` once with dlsym. Pays the window list's first-call cost (about 50 ms) once,
    /// off the main actor.
    public init() { fatalError("not implemented") }
    public func frontmost() -> FrontmostWindows {
        // 1. NSWorkspace.frontmostApplication, not this process → RunningApp.entry(for:), else .noApp.
        // 2. AXUIElementCreateApplication(pid), messaging timeout set, kAXWindowsAttribute.
        //    Any error (not trusted, cannot complete) → .app(entry, [], []).
        // 3. Per window, one AXUIElementCopyMultipleAttributeValues call: role, subrole, title, minimised,
        //    "AXFullScreen". Stop at the first cannot-complete; the listing is then marked unanswering.
        // 4. Number: _AXUIElementGetWindow. Fallback: the frame (and the title when names are readable) matched
        //    against the pid's layer-0 entries in the window list. A window left unmatched is not listed.
        // 5. On screen: CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements]), the pid's layer-0
        //    numbers, front to back.
        // 6. visible = not minimised, AXWindow/AXStandardWindow, on screen (this limits the list to the current
        //    Space), in window-list order. minimised = kAXMinimized alone (a minimised window's subrole lies), in AX
        //    order.
        // 7. Keep [WindowID: AXUIElement] as the listing that `stack` may name.
        fatalError("not implemented")
    }
    public func stack(_ frontToBack: [WindowID]) -> WindowID? {
        // Unanswering listing or unknown first window → front().
        // First window answers kAXErrorInvalidUIElement → front(); nothing changes.
        // current = the window list's on-screen order, limited to the listing.
        // For each id in WindowStack.raises(current:target: the open ids):
        //     id == first or not minimised → AXUIElementPerformAction(kAXRaiseAction).
        //     A cannot-complete marks the listing unanswering and stops.
        // Returns front(): the first of the listing's windows on screen now.
        fatalError("not implemented")
    }
}

/// Permissions over AX trust, screen-capture access and tccd's one broadcast, which names no service: both are
/// re-read on every post, and `onChange` runs only when either changed.
@MainActor public final class SystemPermissions: Permissions {
    public init(
        trusted: @escaping @Sendable () -> Bool = { AXIsProcessTrusted() },
        capturing: @escaping @Sendable () -> Bool = { CGPreflightScreenCaptureAccess() }) { fatalError("not implemented") }
    public var onChange: (@MainActor () -> Void)?
    public func isGranted(_ permission: Permission) -> Bool { fatalError("not implemented") }
    /// .accessibility: AXIsProcessTrustedWithOptions with the prompt key. .screenRecording: CGRequestScreenCaptureAccess().
    public func ask(_ permission: Permission) { fatalError("not implemented") }
}
```

```swift
/// Both switchers' window. It is borderless, non-activating, click-through, at screen-saver level on every Space and
/// beside full-screen apps, and never key. Its content is Liquid Glass under `roundedClip`. It presents at once and
/// dismisses with a 150 ms fade (at once with Reduce motion), unless it is presented again meanwhile.
class OverlayPanel: NSPanel {
    init(cornerRadius: CGFloat, content: NSView) { fatalError("not implemented") }
    var isPresented: Bool { fatalError("not implemented") }
    func present(animated: Bool) { fatalError("not implemented") }
    func dismiss() { fatalError("not implemented") }
    /// Runs once the panel is out. The window switcher drops every picture here (R17).
    func emptied() {}
}

/// The window switcher: one glass panel, ten pre-created rows, one glass highlight. The presenter decides what shows.
final class WindowSwitcherPanel: OverlayPanel {
    func widestTitle(_ rows: [WindowSwitcher.Row]) -> Double { fatalError("not implemented") }
    func lay(out rows: [WindowSwitcher.Row], icon: NSImage?, layout: WindowColumnLayout, topLeft: NSPoint) {
        fatalError("not implemented")
    }
    /// The highlight sits at `position` rows from the top. It follows the fingers with actions disabled.
    func show(position: Double, selected: Int) { fatalError("not implemented") }
    func springHighlight(fromY offset: Double) { fatalError("not implemented") }
    func setPreview(_ picture: CGImage, row: Int, animated: Bool) { fatalError("not implemented") }
    override func emptied() { /* every row layer's contents = nil */ }
}

/// Pictures of windows, taken off the main actor. The one file that captures the screen, for previews only.
enum PreviewCapture {
    /// Yields each window's picture as it is taken: `SCShareableContent` once, then one `SCScreenshotManager` capture
    /// per window, aspect-fit into `box` points at `scale`, with no cursor and no shadow. A window that cannot be
    /// captured yields nothing. Cancelling the consuming task stops the captures. Called only when the model says
    /// previews show, so it never prompts.
    static func pictures(of windows: [WindowID], fitting box: (width: Double, height: Double), scale: CGFloat)
        -> AsyncStream<(WindowID, CGImage)> { fatalError("not implemented") }
}
```

**The look and motion** are best judgement, kept in `WindowSwitcherStyle` (shell) and `WindowColumnLayout` (core
geometry) so later refinement touches no policy.

The panel:
- It is a `.regular` glass panel with radius 22. Its top-left corner sits 12 pt inside the pointer display's
  `visibleFrame`, so it is below the menu bar and clear of a left Dock.
- The highlight is one `.clear` glass view with radius 14, concentric with the panel's padding.
- It follows the travel 1:1 with actions disabled, and has the app switcher's rubber-band spring on `position.y`.

The rows:
- A row is 72 pt tall.
- Its preview slot is 120 × 60 pt with radius 6. The picture is aspect-fit inside it. Until the picture is ready, a
  44 pt app icon sits in the centre.
- The title is one line at 13 pt medium, truncated at the end. It uses `labelColor` when selected, otherwise
  `secondaryLabelColor`.
- A minimised row is at 55 % alpha, with a 10 pt "Minimised" capsule badge.

The motion:
- Appearing takes 0.1 s of opacity plus a spring from 0.96 scale, anchored at the top-left. With Reduce motion it
  appears at once.
- A preview arrives with a 0.15 s crossfade.
- Dismissing is the shared 150 ms fade.
- The column width follows the widest title, clamped to 180 to 320 pt.
- Scale shrinks fonts with the rows.

**Degraded cases.**

| Case | Behaviour | Where |
|---|---|---|
| No Accessibility | One row: the frontmost app's icon and "Allow Accessibility to switch windows". The lift is silent. The swipe is still recognised, but nothing is blocked (R14). | model gate on `isAccessibilityGranted` |
| App does not answer | The read lists nothing, so the row is "No open windows". A timeout during `stack` ends calls to that app for this listing. | adapter |
| Window closed | A raise changes nothing. The lift does no reordering and gives the haptic only if the window in front changed (R10, R11). | adapter + model |
| No `_AXUIElementGetWindow` | Numbers come from frame matching. An unmatched window is not listed. | adapter |
| No Screen Recording | `previewWindows == []`, so rows show the icon. Capture is never called, and nothing prompts (R7). | model + shell |
| Capture fails for a window | Its row keeps the icon. | shell |
| No frontmost app | "No open windows" with no icon (R13). | model parse |

**Requirement trace.**

| R | Carried by |
|---|---|
| R1 | `beginOrSpoil` (`Move.slide`, `slides.contains`), pair and `.resting` exist when `!slides.isEmpty`, `dragThresholdMM` shared, edge filter. Recognizer tests: left hand, fingers first, three fingers, 2 mm drift. |
| R2 | `Swipe.kind` fixed at begin. Phases are emitted by kind (`.slide(kind, _)`). |
| R3 | Current Space and window-list order in the adapter. `Content.init(_:)` applies the full-screen rule, puts visible before minimised and cuts at 10. `content` is a `let`. |
| R4 | The adapter filters (standard visible windows on screen; minimised by `kAXMinimized`). `Row.minimised` is dimmed with a badge and the icon. |
| R5 | `Displays.screen(under:)` + `visibleFrame` top-left; `WindowColumnLayout.scale`; `OverlayPanel` (never key, click-through). |
| R6 | `rows` titles (`Copy.untitledWindow`), the preview box, the icon until `PreviewCapture` yields, the capture at the open for `serial`, the panel shown in the begin turn. |
| R7 | `showsPreviews` read at begin from the pushed grant; `previewWindows` is empty otherwise. |
| R8 | `screenRecordingHint`, `askForScreenRecording()`, `hasAskedForScreenRecording`, `SettingsPane.screenRecording`, the TCC push → reconcile → refit. |
| R9 | `SwipeTravel.travel(along: .windowSwipe)`, `pointsPerStep` 100, `SwitcherSelection.follow`. Travel is 0 at begin. |
| R10 | `selectedVisibleWindow` + `windows.stack([window])` in `.moved`. Row 0 is the front window, so sliding back raises it; when every window is minimised it raises nothing. |
| R11 | `liftOrder`, `stack`'s returned window, `WindowStack.raises`, a restore on the first window only, `window = .closed` on a changing lift. |
| R12 | Ticks = `follow`'s return. Haptic iff `inFront != frontWindow`. The window swipe never calls `playLaunchAnimation`. |
| R13 | `.noWindows(of:)`; a one-row selection (rubber band); a single visible row's `liftOrder` is already in place. |
| R14 | `.accessibilityNeeded(for: read.app)`; the existing hint stays. |
| R15 | `.swiping` unchanged; `.cancelled` → `shown = nil` with no stack. |
| R16 | `Settings.isWindowSwipeOn`, `slides`, `Run.slides`, `setWindowSwipe(on:)`, the third `SwitcherSection` row. |
| R17 | Capture only at the open for a new `serial`; cancelled at nil; arrivals checked against the serial; `emptied()`; no image type in core; policy bans. |

**Testing seams.**

| Seam | Scenarios | Handles a test holds |
|---|---|---|
| The recognizer over `TouchScript` (`windowPhases`, `phases`, `perFrame`) | R1, R2, R15 (blocking, rejoin, thumb lift, third finger, click), R16 (each kind alone, both, neither). The old vertical-spoil rows are flipped to "window swipe off". | the frame clock |
| `World`: the real `Launcher`, the real recognizer and filters inside `InMemoryTrackpads`, `InMemoryWindows`, `InMemoryPermissions` | R3/R4 as the fake lists them, R6 titles, R7, R8, R9 (linear), R10, R11, R12, R13, R14, R15 (cancel, no scroll), R16 (persistence, upgrade with the frozen record) | `windows.set(visible:minimised:fullScreenFront:)`; `windows.close(_:)` / `open(_:)` between `play` pieces; `windows.answers = false`; `windows.onScreenTitles`, `raised`, `reads`; `permissions.set(_:granted:)` pushes; `permissions.asks` |
| Pure values | `SwitcherSelection`, `Content.init`, `rows`/titles, `liftOrder`, `WindowStack.raises`, `WindowColumnLayout`, `cursorMove` y, `Copy` | none |
| `LauncherPlatformTests` | `SystemPermissions` re-reads both on a posted broadcast (injected closures). `AccessibilityWindows` over the test process's own windows, only when trusted. | the posted notification |
| By hand | The glass, placement on two displays, shrink, motion, real AX across apps (filters, Spaces, full screen, restore, focus), previews arriving and the icon until then, R17 by code review, the TCC prompt and Settings page, any relaunch, a hung app (`kill -STOP`). | none |

`InMemoryWindows` is a tiny window stack. It applies `WindowStack.raises` with move-to-front semantics, restores the
first window only, and answers `frontmost()` from its stack. It lands effects the way the real adapter does, so a
second window swipe sees the first one's order, as in R11's toggle scenario. `RecordingSystemActions` is untouched.

**Source policy and docs.**
- Confined, each to one file:

  | Tokens | File |
  |---|---|
  | `AXIsProcessTrusted`, `notify_register`, `ScreenCaptureAccess` | `SystemPermissions.swift` |
  | `AXUIElement` (covers the private symbol), `CGWindowList` | `AccessibilityWindows.swift` |
  | `ScreenCaptureKit`, `SCShareableContent`, `SCScreenshotManager` | `PreviewCapture.swift` |

- Banned:
  - `SCStream(` and `SCRecordingOutput`: previews are one picture each, never a stream or a recording;
  - `CGImageDestination`: a picture never reaches a file;
  - `AXUIElementSetAttributeValue` and `kAXPressAction`: the switcher only picks a window.
- The "R9 only Accessibility" labels become "no Input Monitoring or event posting".
- `docs/architecture.md`, Privacy: the app may ask for two optional permissions:
  - Accessibility, for click, scroll and Dock-swipe blocking, and to list, raise and restore the frontmost app's
    windows during a window swipe;
  - Screen Recording, used only to capture window previews when a window swipe begins, held in memory and dropped
    when it ends.

  The rest of the Privacy changes:
  - It names the private `_AXUIElementGetWindow` and its fallback.
  - It says each permission API, the AX element API, the window list and capture are confined.
- `docs/architecture.md`, Shape: ScreenCaptureKit joins `LauncherUI`.
- `docs/architecture.md`, Concurrency: the window read and raises are synchronous AX IPC, bounded by the timeout. The
  window list's first call is paid off-main at launch. Capture is asynchronous.
- `docs/domain-model.md`, new entries: *window swipe*, *window switcher*, *window*, *front window*, *window swipe
  setting* and *screen recording hint*.
- `docs/domain-model.md`, changed entries:
  - *Swipe*: more sideways, decided once.
  - *Tap*.
  - *Swipe setting*: a sideways slide spoils while it is off; vertical follows the window swipe setting.
  - *Launcher window*.
  - *Feedback*.
  - *Light tick*.
  - *Click blocking* and *Blocking window*: these now include the window swipe.
  - *Accessibility hint* scope.
  - *Frontmost app*.

### Synthesis decision

### Tradeoffs accepted

- AX calls run synchronously on the main actor: about 1 ms to read and about 2 ms per raise. They are bounded by a
  0.2 s messaging timeout, and calls stop after an app's first timeout. In exchange, the model stays synchronous and
  the lift decides the haptic from the effect's own answer. A hung app can delay the switcher once by up to 0.2 s.
- Preview arrival, icon-until-ready and discard are checked by hand and by code review, which is what R17 asks for.
  In exchange, pictures have one owner, their lifetime is derived from the model value, and no image channel runs
  through core or across the module graph.
- `WindowID` is the window server's number. In exchange for one identity shared by AX, the window list and capture, a
  macOS without `_AXUIElementGetWindow` falls back to frame matching and leaves unmatched windows out.
- One `pointsPerStep` (100) serves both slides, so the debug tuner moves both together.
- Every lift on a window row calls `stack`, even on the front window. The adapter's in-place check makes that a
  read-only no-op. In exchange there is one lift rule, and it also restores the order after sliding away and back.
- Without Accessibility, the window read is wasted (AX fails at once). In exchange there is one read path that always
  yields the app for R14's row, and the permission port is the single source for whether the switcher may list windows.
- A lift that changes the window in front closes the launcher window, as the swipe's lift does. Otherwise a key
  launcher window would keep typing away from the raised window.
- `AccessibilityPermission` is renamed to `Permissions` across tests and the composition root. In exchange, one TCC
  module owns the one broadcast.
- The adapter keeps the latest listing's AX elements until the next read, so there is no lifecycle method on the
  port.
- While the window swipe setting is on, a vertical two-finger slide under an anchored thumb is a window swipe and no
  longer scrolls. R16's switch is the way out.

### Alternatives considered

- **Previews through the model.** Readiness would live per row in `WindowSwitcher`, capture would sit behind the port
  with a push, and images would reach the shell through a lookup the composition root wires from Platform. This would
  give `World` a handle on arrival. But it exposes:
  - a capture method and a push on the port;
  - state that no decision reads;
  - a Platform-to-shell image channel outside any port;
  - discard calls on every exit path.

  It would also give the readiness flag and the image two owners to keep in step. It lost on depth and locality.
- **The window read and `stack` on `SystemActions`, beside `runningApps()`.** This follows precedent. But it turns the
  port into a grab bag, hides the "names windows of the latest read" constraint among unrelated methods, adds two
  pass-throughs in `WorkspaceActions`, and mixes a window stack into a recording fake. It lost narrowly. A two-method
  port is as deep as `why.md` asks.
- **A second state or recognizer for vertical slides.** It would duplicate rejoin, cancel, thumb and blocking, and
  create two places that decide direction. Rejected.
- **One `.swipe(.began(kind))` event and one model handler.** This has one fewer enum case, but every phase in the
  model branches on the kind. It lost on reader load.
- **A lift that re-reads the list, with a void `stack`.** This mirrors the app switcher's second read. But the read
  would have to target the app listed at begin, with IDs that survive across reads: two calls where the effect's own
  answer is exact.
- **Raises on a serial background queue.** The main actor would never wait on another app. But the lift's haptic
  needs the outcome, so the model would have to wait or decide late, and it adds ordering and cancellation states.
  Bounded timeouts were chosen instead.

### Open questions and risks

1. **One minimised window.** R13 says one window → nothing; R11 says all minimised → restore with the haptic. The
   design restores. Is that right?
2. **The front window closes mid-swipe and the user lifts on its row.** The design follows R12 literally: the haptic
   plays if another window is now in front. Should it be silent instead?
3. **The launcher window.** Should a lift that changes the window in front close it (the design does)?
4. **Is 0.2 s the right AX messaging timeout?** Chromium-style apps whose accessibility tree wakes on the first query
   may read as "No open windows" (O5).
5. **Does y acceleration really match x by symmetry (O1)?** Check by feel against the cursor.
6. **The ScreenCaptureKit alert (F31).** macOS 15 and later may show a periodic alert because the capture bypasses
   the picker. Is that acceptable for previews, or should previews wait for a product decision?
7. **A relaunch after the grant (F30).** If macOS needs one, the hint may stay until the relaunch. Is that acceptable
   under R8? Does `CGRequestScreenCaptureAccess()` return at once? This needs a check by hand.
8. **Mission Control.** Without Accessibility, a vertical thumb plus two fingers may open Mission Control. Should R14
   say so?
9. **Taps that drift.** A tap that drifts vertically past 3 mm will flash the window switcher, as sideways drift
   already flashes the app switcher.
10. **The gesture hint.** Should the hint text mention the window swipe? The design leaves it unchanged.

### Next implementation step

Test-first through `TouchScript`: add `SlideKind` to `beginOrSpoil` and `SwipeTravel.travel(along:)` for R1, R2 and
R16, then extract `SwitcherSelection` with the existing switcher tests green.
