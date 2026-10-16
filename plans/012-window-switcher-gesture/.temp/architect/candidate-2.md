## Design

### Problem

Add a second slide to the one finger session the swipe already owns: two fingers moving up or down under the anchored thumb show the frontmost app's windows in a vertical Liquid Glass column top-left, raise each visible window as the selection passes it, and on the lift leave the selected window in front with a deterministic order. The shape is non-obvious because of what the grounding fixed: one recognizer and one `.swiping` state with no second event hop (why.md Preserve 1, Avoid 1); the recognizer never learns whether there are windows (Preserve 3); travel crosses the port as one scalar in step millimetres through the curve installed at begin (Preserve 4, F3); the list is fixed at begin and the system is read at begin and again at the lift (Preserve 5); window reads and raises belong beside `runningApps()` and `bringToFront` on `SystemActions`, never as one-method ports (Preserve 7); no AX, `CGWindowID`, `CGImage` or `NSImage` crosses a port, yet previews arrive asynchronously and must be holdable in tests (F32, F33); `LauncherUI` cannot import `LauncherPlatform`, so the shell cannot capture for itself; mid-swipe raises are the first mid-swipe effect and the lift must not depend on state they changed (Risk 4, F22); `notify_register` is confined to one file and a second permission rides the same tccd broadcast (F29, F34); raising an unlisted window switches Spaces (F24); `AXRaise` is the only lever that fronts, focuses and restores (F19, F20, F23).

### Usage (caller's view)

**README.** A window swipe is the swipe's sibling on the other axis. The recognizer begins one `.swiping` on the first drag past 3 mm and tells the main actor which axis won: `.swipe(.began(.vertical))`. Travel then arrives as the same `.moved(travelMM:)` scalar, taken from the y component through the pointer curve, 100 cursor points per row. `Launcher` reads the frontmost app's windows once (`system.frontmostWindows()`), builds a `WindowSwitcher` value whose `content` is fixed for the swipe, asks `screenRecording.capturePreviews(of:)` for stills of the visible windows, and exposes it as `launcher.windowSwitcher`. Every selection change onto a visible window is one `system.raise(id)`; the lift reads the windows again, asks the value for a `WindowLift` plan (which raises, whether to pulse) and plays it. `WindowSwitcherPresenter` renders `launcher.windowSwitcher` into a pre-created `WindowSwitcherPanel` and holds nothing the model holds; previews land in `switcher.previews` as domain bitmaps and the panel crossfades them in. The Screen Recording permission is a port like Accessibility: `isGranted()` never prompts, `request()` shows the system prompt once, the TCC push re-reads it, and the launcher window shows a hint whose button asks the first time and opens System Settings afterwards.

**Call site 1, the model (`Launcher.swipe(_:)`), the one place a swipe becomes effects:**

```swift
case .began(let axis):
    guard open == nil, activity.isActive else { return }
    switch axis {
    case .sideways:
        let running = system.runningApps()
        open = Switcher(frontmost: running.frontmost, running: running.apps,
                        leavingOut: settings.assignedBundleIDs, trackpad: event.trackpad).map(OpenSwitcher.apps)
    case .vertical:
        let read = system.frontmostWindows()                              // app + its windows, one read
        let switcher = WindowSwitcher(
            app: read.app, windows: read.windows, accessibility: isAccessibilityGranted, trackpad: event.trackpad)
        open = .windows(switcher)
        if isScreenRecordingGranted { screenRecording.capturePreviews(of: switcher.visibleWindowIDs) }
    }
case .moved(let travel):
    guard case .windows(var w)? = open, w.trackpad == event.trackpad else { /* apps path as today */ }
    let before = w.selected
    w.follow(travel)
    open = .windows(w)
    for _ in 0..<abs(w.selected - before) { hardware.playFeedback(.lightTick, on: event.trackpad) }
    if w.selected != before, let row = w.selectedRow, !row.isMinimised { system.raise(row.id) }
case .ended:
    guard case .windows(let w)? = open, w.trackpad == event.trackpad else { /* apps path as today */ }
    open = nil
    let plan = w.lift(given: system.frontmostWindows())                   // second read, pure plan
    for id in plan.raises { system.raise(id) }                            // back to front; often empty
    if plan.playsHaptic { hardware.playFeedback(.gesture, on: event.trackpad); window = .closed }
case .cancelled:
    if open?.trackpad == event.trackpad { open = nil }
```

**Call site 2, a World test (the seam every R3 to R15 scenario runs at):**

```swift
let world = World.windowWorld(app: "Safari", windows: [("Docs", false), ("Mail", false), ("News", true)])
world.screenRecording.holdPreviews()
world.windowSwipe(3.5, 12, lift: false)                                   // y, like `swipe` is x
#expect(world.launcher.windowSwitcher?.rowNames == ["Docs", "Mail", "News"])
#expect(world.launcher.windowSwitcher?.selected == 1)
#expect(world.system.raised == [world.window("Mail")])                   // raised while sliding
#expect(world.launcher.windowSwitcher?.previews.isEmpty == true)         // icon until ready
world.screenRecording.deliverHeldPreviews()
#expect(world.launcher.windowSwitcher?.previews.keys.count == 2)         // the two visible windows
world.system.windows = world.windows(without: "Mail")                     // "Mail" closes before the lift
world.play(hand.lift())
#expect(world.system.raised.count == 1)                                  // no reordering, R11
#expect(world.hardware.feedback.count == 1)                              // "Docs" is not in front now
```

**Call site 3, the shell (`WindowSwitcherPresenter.render`), the same pattern as `SwitcherPresenter`:**

```swift
for await shown in Observations({ launcher.windowSwitcher }) { render(shown) }

private func render(_ switcher: WindowSwitcher?) {
    guard let switcher else { hide(); return }                            // 150 ms fade, previews dropped
    if !isShown || switcher.content != laidOut?.content { open(switcher) }   // layout + orderFrontRegardless
    panel.show(position: switcher.selection.position, selected: switcher.selected)
    for (id, image) in switcher.previews where laidOut?.previews[id] == nil { panel.setPreview(image, for: id) }
    springIfStretched(switcher.selection.stretch)
    laidOut = switcher
}
```

**Call site 4, the composition root:**

```swift
let launcher = Launcher(
    hardware: MultitouchTrackpads(), preferences: SystemTrackpadPreferences(),
    access: SystemAccessibilityPermission(), screenRecording: SystemScreenRecording(),
    system: WorkspaceActions(), catalog: catalog, scanner: SystemAppScanner(catalog: catalog),
    store: SettingsStore(defaults: .standard))
```

### Shape

**Data first.** The domain gains five values. `SwipeAxis` is the one fact a slide's first drag decides; it rides on `SwipePhase.began` and is stored in the recognizer's `Swipe`, so the axis is fixed at begin and carried with it (per **model-the-domain**, Change 2). `AppWindows` is one read of the system: the active app and its windows as `AppWindow(id, title, isMinimised)`, visible ones front to back, minimised ones after in the app's order. `WindowID` brands the window server's number (per **type-system-discipline**); the core never interprets it and the adapter keeps the AX handle for it. `PreviewImage` is a domain bitmap (width, height, premultiplied RGBA bytes); it is what crosses the port instead of `CGImage`, so the image's owner is the model value for the swipe's life and nothing else (R17). `WindowSwitcher` is the swipe's value: `let content` (an enum: windows, no windows, Accessibility needed, so a notice row can never sit among window rows) fixed at begin, `selection` following travel, `previews` filling in. The selection maths that `Switcher` owns today (hard stops, the forgiving band, nearest row, position, stretch) moves into `Selection`, which both switchers compose; the domain differs only in what the rows are and what the lift does, so that is all that differs.

**Flow.** Frame thread: `beginOrSpoil` asks `Move.axis` (strict 45° split, a tie spoils) and `swipes.contains(axis)`; the pair exists when either axis is on, so "swipe off, window swipe on" is one gate (R16). `Swipe.axis` picks which component of the accelerated move accumulates; `.moved(travelMM:)` is unchanged. Main actor: `Launcher` holds one stored `open: OpenSwitcher?` (apps or windows) and derives `switcher` and `windowSwitcher` from it, so "at most one switcher is open" is encoded, not synchronised (per **encode-lessons-in-structure**; derive instead of sync). The lift is a pure plan from the fixed rows and a fresh read: desired order `[selected, front, the other visible rows as at begin]`, minus windows that closed; the raises are the shortest prefix of that order which, raised back to front, leaves the rest already stacked beneath (F22). After a mid-swipe raise this is usually empty; a selected minimised window is always in it (restored by the raise, F20); a selected window that closed yields no raises and a pulse only if the window in front is not the begin front (R11, R12). The pulse is derived from the plan, never from a third read.

**Previews.** The model requests captures only when `isScreenRecordingGranted`; the adapter preflights again at the OS boundary and never touches ScreenCaptureKit otherwise, so R7's "never prompts" is structural (per **boundary-discipline**). Each `capturePreviews` call replaces the last; results from a replaced call are dropped in the adapter, and a delivery after the swipe ended is dropped by the model (no open window switcher). Capture runs `@concurrent` and only the bytes hop back (F27: about 100 ms for the first window in a process, then 20 to 30 ms each, concurrently).

**Invariants in types, validation at the edges.** `Selection(count:)` requires `count >= 1`; `WindowSwitcher.content` can only be built from an `AppWindows` read plus the trust flag; `PreviewImage.init` checks `bytes.count == width * height * 4`; `WindowID` is opaque. Trust and the permission are read at `reconcile` from the two permission ports and pushed by the one TCC broadcast through `TCCChangeListener`, the one file that may register for it. The AX adapter parses `kAXErrorAPIDisabled`, `kAXErrorCannotComplete` and `kAXErrorInvalidUIElement` into "no windows", "no windows" and "no-op" respectively; the core never sees an error code.

**Depth.** `SystemActions` gains two methods and hides: the pid, the AX tree, the subrole rules, the Space test through the CG on-screen list, the private window-number symbol with its fallback, the messaging timeout, the handle table, and the restore-by-raise behaviour. `ScreenRecording` has five members and hides preflight, the prompt, the TCC push, `SCShareableContent`, filters, concurrent capture, bitmap conversion and generation checks. `WindowSwitcher` exposes `follow`, `lift(given:)`, `setPreview` and reads; it hides the row derivation, naming, the cut at ten, the one-row notices and the re-stack algorithm. What stays exposed: the model decides whether to capture (it owns the permission state for the hint anyway) and the lift's three effects (raise list, pulse, window close), because the model is where effects are decided.

**Deliberately not done.** No per-window geometry in the domain: the preview box is a fixed 120 × 60 pt and the image aspect-fits inside, so layout never shifts when a preview lands. No live previews, no capture of minimised windows, no third read at the lift, no cancellation message to the capture adapter, no `NSGlassEffectContainerView` (the highlight nests inside the panel glass's content as the shipped switcher does).

#### Type sketch

```swift
// MARK: LauncherCore / Gesture

/// The axis a slide's first drag past 3 mm decided. Fixed for the slide.
public enum SwipeAxis: Equatable, Sendable, CaseIterable { case sideways, vertical }

public enum SwipePhase: Equatable, Sendable {
    /// Two fingers under an anchored thumb moved past 3 mm, more along `axis` than across it. Travel is 0 here.
    case began(SwipeAxis)
    /// The fingers' mean movement along the axis since `began`, in step millimetres (12 per icon or row),
    /// through the pointer curve installed at begin. Positive is right, or down. Absolute. Sent only when changed.
    case moved(travelMM: Double)
    /// Both fingers have lifted.
    case ended
    /// A third finger landed outside the corner while both were down, or a click reached apps.
    case cancelled
}

// MARK: LauncherCore / GestureRecognizer (changes only)

public struct GestureRecognizer: Sendable {
    /// `swipes`: the axes a pair's drag may begin a slide on; empty means every drag spoils, as before the swipe.
    public init(handMode: HandMode, surface: SurfaceSize, swipes: Set<SwipeAxis>, swaps: Bool, travel: SwipeTravel)

    // .tapping: `let pair = swipes.isEmpty ? nil : Pair(tap, joining: joining)` — the pair, and so `.resting`,
    // exist while either axis is on.
    // .swiping: the accumulate step becomes
    //   let travel = swipe.travelMM + self.travel.travel(dxMM: dxMM, dyMM: dyMM, along: swipe.axis, interval: interval)
    // Blocking: `if case .swiping = state` is unchanged, so both flags hold for either axis (R15).

    /// A drag of a pair begins the slide on the axis it is more along, when that axis is on; any other drag spoils.
    private func beginOrSpoil(_ pair: Pair?, _ move: Move, _ anchor: Anchor, _ down: [TouchID: Touch], _ time: FrameTime)
        -> (State, Recognition.Event?) {
        guard let pair, let axis = move.axis, swipes.contains(axis) else { return (.spoiled(anchor), nil) }
        // TODO: fingers at their current positions, travelMM = 0, thumb = anchor, axis stored on Swipe
        return (.swiping(Swipe(fingers: /*…*/ [:], lastTime: time, thumb: anchor, axis: axis)), .swipe(.began(axis)))
    }

    private struct Move: Sendable {
        let dxMM: Double, dyMM: Double
        /// Strictly more along one axis; nil on a tie, which spoils, as today.
        var axis: SwipeAxis? { abs(dxMM) > abs(dyMM) ? .sideways : abs(dyMM) > abs(dxMM) ? .vertical : nil }
    }

    private struct Swipe: Sendable {
        var fingers: [TouchID: SurfacePoint]
        var lastTime: FrameTime
        var travelMM: Double = 0
        var thumb: Anchor?
        let axis: SwipeAxis
    }

    private let swipes: Set<SwipeAxis>
}

// MARK: LauncherCore / PointerCurve

extension PointerCurve {
    /// Cursor points the pointer moves for one report of finger movement, both components scaled by the one
    /// multiplier macOS derives from the speed (`hypot`). Replaces the x-only `cursorPoints`.
    public func cursorPoints(dxMM: Double, dyMM: Double, interval: Double) -> (x: Double, y: Double) {
        fatalError("not implemented")  // dx * m / v, dy * m / v, as `IOHIDPointerAccelerator::accelerate`
    }
}

public enum SwipeTravel: Equatable, Sendable {
    case linear
    /// `pointsPerIcon` cursor points make one icon or one row: R9 fixes both at 100.
    case cursor(PointerCurve, pointsPerIcon: Double)
    public static let shippedPointsPerIcon = 100.0

    /// The component along `axis`, in step millimetres.
    func travel(dxMM: Double, dyMM: Double, along axis: SwipeAxis, interval: Double) -> Double {
        fatalError("not implemented")
    }
}

// MARK: LauncherCore / Selection (the maths both switchers share, moved out of Switcher)

/// A highlight over `count` rows or icons following one scalar of travel: the nearest item, hard stops with a band
/// that keeps at most a quarter item past either end and forgets it the moment the fingers turn back.
public struct Selection: Equatable, Sendable {
    public let count: Int
    public package(set) var travelMM: Double = 0
    private var reportedMM: Double = 0

    /// `count` must be at least 1 (the one-row switchers rubber-band at both ends, R13).
    public init(count: Int)

    /// round(travel / 12 mm), half away from zero, clamped: changes at ±6 mm then every 12 mm.
    public var selected: Int { fatalError("not implemented") }
    /// Items from the first, clamped; between two items in proportion.
    public var position: Double { fatalError("not implemented") }
    /// The band past an end, signed, bounded below `switcherMaxStretch`. 0 inside.
    public var stretch: Double { fatalError("not implemented") }
    /// `Switcher.follow` today, verbatim: the delta of the reported travel, the quarter-item band, the forgiving turn.
    package mutating func follow(_ reportedMM: Double) { fatalError("not implemented") }
}

// MARK: LauncherCore / Switcher (the app switcher composes Selection; its domain surface is unchanged)

public struct Switcher: Equatable, Sendable {
    public let row: [AppEntry]
    public private(set) var selection: Selection
    public let trackpad: TrackpadID
    package init?(frontmost: AppEntry?, running: [AppEntry], leavingOut: Set<BundleID>, trackpad: TrackpadID)
    public var selected: Int { selection.selected }
    public var selectedApp: AppEntry { row[selected] }
    public var selectsFrontmost: Bool
    package mutating func follow(_ reportedMM: Double) { selection.follow(reportedMM) }
}

// MARK: LauncherCore / Windows (domain values that cross the ports)

/// The window server's number for a window, as the adapter minted it. Opaque to the core; stable for the window's
/// life, so the begin read and the lift read name the same window the same way.
public struct WindowID: Hashable, Sendable { public let rawValue: UInt32 }

/// One of the frontmost app's windows as one read saw it. `title` is the app's title, empty when it has none.
public struct AppWindow: Equatable, Sendable {
    public let id: WindowID
    public let title: String
    public let isMinimised: Bool
}

/// One read of the system: the active app (nil when none, or Trackpad Launcher itself) and its windows: the normal
/// windows on the current Space front to back, then the minimised ones in the app's order. Empty without trust,
/// when the app does not answer in time, or when it has none.
public struct AppWindows: Equatable, Sendable {
    public let app: AppEntry?
    public let windows: [AppWindow]
    public static let none = AppWindows(app: nil, windows: [])
}

/// A still of a window as the window swipe began: `width` × `height` pixels, premultiplied RGBA, 8 bits per channel,
/// row-major, no row padding. Kept only by a `WindowSwitcher` value and dropped with it (R17).
public struct PreviewImage: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let rgba: Data
    /// nil unless `rgba.count == width * height * 4`. The boundary check; the shell trusts the type.
    public init?(width: Int, height: Int, rgba: Data)
}

// MARK: LauncherCore / WindowSwitcher

/// One row of the window switcher: a window with its display name (R6 naming) and whether it was minimised at begin.
public struct WindowRow: Equatable, Sendable, Identifiable {
    public let id: WindowID
    public let name: String
    public let isMinimised: Bool
}

/// The window switcher during one window swipe. `content` is fixed when the swipe begins; `selection` follows the
/// travel; `previews` fill in afterwards. Rendered by `LauncherUI`, read by tests, never by the recognizer.
public struct WindowSwitcher: Equatable, Sendable {
    public enum Content: Equatable, Sendable {
        /// One to ten rows: the visible windows front to back (the front window first), then the minimised ones.
        case windows([WindowRow])
        /// "No open windows", with the app's icon when there is an app.
        case noWindows
        /// "Allow Accessibility to switch windows", with the app's icon.
        case accessibilityNeeded
    }

    /// The frontmost app at begin; nil when there was none.
    public let app: AppEntry?
    public let content: Content
    public private(set) var selection: Selection
    /// Keyed by the row's window. A still arrives for visible windows only, and only with Screen Recording.
    public private(set) var previews: [WindowID: PreviewImage] = [:]
    public let trackpad: TrackpadID

    /// Derives the content: no trust → `.accessibilityNeeded`; no windows → `.noWindows`; else the visible windows in
    /// the order read, then the minimised ones, cut at `GestureRules.switcherMaxRows`, each named by `Copy.windowName`.
    /// The selection starts on the first row in every case (R9, R11).
    package init(app: AppEntry?, windows: [AppWindow], accessibility: Bool, trackpad: TrackpadID)

    public var rowCount: Int { fatalError("not implemented") }           // rows.count, or 1 for a notice
    public var selected: Int { selection.selected }
    /// nil for the one-row notices.
    public var selectedRow: WindowRow? { fatalError("not implemented") }
    /// The front window at begin: the first visible row. nil when every row is minimised, or there are none.
    public var front: WindowID? { fatalError("not implemented") }
    /// The windows a preview is wanted for: the visible rows.
    public var visibleWindowIDs: [WindowID] { fatalError("not implemented") }

    package mutating func follow(_ reportedMM: Double) { selection.follow(reportedMM) }
    /// Ignored for a window not in `content` (a late or stray delivery).
    package mutating func setPreview(_ image: PreviewImage, for id: WindowID) { fatalError("not implemented") }

    /// What the lift does, from the rows fixed at begin and the windows as they are now. Pure.
    public func lift(given now: AppWindows) -> WindowLift { fatalError("not implemented") }
    // TODO:
    //   guard case .windows(let rows) = content, now.app == app else { return .nothing }   // notice, or app changed
    //   let selectedRow = rows[selected]
    //   let alive = Set(now.windows.map(\.id)); let current = now.windows.filter { !$0.isMinimised }.map(\.id)
    //   guard alive.contains(selectedRow.id) else {                                        // closed: no reordering
    //       return WindowLift(raises: [], playsHaptic: current.first != front) }
    //   var desired = [selectedRow.id] + (front.map { [$0] } ?? []) + rows.filter { !$0.isMinimised }.map(\.id)
    //   desired = desired.uniqued().filter(alive.contains)                                 // selected, front, others as before
    //   var raises: [WindowID] = []; var rest = desired
    //   while !rest.isEmpty, !current.filter({ !raises.contains($0) }).starts(with: rest) { raises.append(rest.removeFirst()) }
    //   let playsHaptic = selectedRow.isMinimised || desired.first != front
    //   return WindowLift(raises: raises.reversed(), playsHaptic: playsHaptic)             // back to front (F22)
}

/// The lift's effects: `raises` in the order to perform them (back to front), and the R12 pulse rule.
public struct WindowLift: Equatable, Sendable {
    public let raises: [WindowID]
    public let playsHaptic: Bool
    public static let nothing = WindowLift(raises: [], playsHaptic: false)
}

// MARK: LauncherCore / WindowColumnLayout (geometry policy, pure, unit-tested like SwitcherRowLayout)

/// Where the rows and the highlight sit in a column of `rowCount` rows on a display `displayHeight` points tall.
/// Rows, previews and gaps shrink by one factor when the column would not fit below the menu bar (R5).
public struct WindowColumnLayout: Equatable, Sendable {
    public static let fullRowHeight = 60.0, fullRowGap = 8.0, previewBoxWidth = 120.0, titleWidth = 220.0
    public static let padding = 16.0, margin = 12.0
    public let rowCount: Int
    public let scale: Double
    /// `displayHeight` is the pointer display's `visibleFrame` height (below the menu bar, above the Dock).
    public init(rowCount: Int, displayHeight: Double)
    public var rowHeight: Double { fatalError("not implemented") }
    public var pitch: Double { fatalError("not implemented") }
    public var panelSize: (width: Double, height: Double) { fatalError("not implemented") }
    /// The vertical centre, from the panel's top edge, of a position counted in rows from the first.
    public func centreY(at position: Double) -> Double { fatalError("not implemented") }
}

// MARK: LauncherCore / Ports

@MainActor public protocol SystemActions: AnyObject {
    // … existing members …
    /// The active app and its windows, read now. One synchronous read, about 2 ms warm; bounded by one AX timeout
    /// when the app does not answer. Replaces the handles `raise` acts on.
    func frontmostWindows() -> AppWindows
    /// Brings one window of the latest `frontmostWindows()` read to the front of its app with the keyboard focus,
    /// restoring it if minimised. An id not in that read, or a window that has closed since, is a no-op. Never
    /// raises an unlisted window, so never switches Spaces. Synchronous, about 2 ms.
    func raise(_ window: WindowID)
}

/// The Screen Recording permission and the one thing it is used for. Real: SystemScreenRecording.
/// Test: InMemoryScreenRecording.
@MainActor public protocol ScreenRecording: AnyObject {
    /// On the main actor after the permission changed, and only then. Carries no data; re-read with `isGranted()`.
    var onChange: (@MainActor () -> Void)? { get set }
    /// Read fresh. Never prompts.
    func isGranted() -> Bool
    /// The system's Screen Recording prompt. Returns at once; the prompt belongs to another process.
    func request()
    /// On the main actor with each finished still, in no particular order, only for a request still current.
    var onPreview: (@MainActor (WindowID, PreviewImage) -> Void)? { get set }
    /// Returns at once. Captures one still per window, off the main actor, fitted inside 120 × 60 points at the
    /// sharpest display's scale. Each call replaces the previous request, whose remaining stills are never delivered.
    /// Does nothing, and touches no capture API, while the permission is missing.
    func capturePreviews(of windows: [WindowID])
}

// MARK: LauncherCore / Launcher (additions)

@MainActor @Observable public final class Launcher {
    /// The one open switcher, if any; written only by `swipe(_:)`, `reconcile()` and `preview(_:for:)`.
    private enum OpenSwitcher { case apps(Switcher), windows(WindowSwitcher) }
    private var open: OpenSwitcher?
    /// Derived: non-nil exactly while a swipe shows the app switcher.
    public var switcher: Switcher? { if case .apps(let s)? = open { s } else { nil } }
    /// Derived: non-nil exactly while a window swipe is on, notices included.
    public var windowSwitcher: WindowSwitcher? { if case .windows(let w)? = open { w } else { nil } }

    public var isWindowSwipeOn: Bool { settings.isWindowSwipeOn }
    /// Drives the screen recording hint and the capture request. Read at `reconcile`, pushed by the TCC broadcast.
    public private(set) var isScreenRecordingGranted = false
    /// nil while the permission is granted or the window swipe setting is off (R8).
    public var screenRecordingHint: ScreenRecordingHint? { fatalError("not implemented") }

    public init(hardware:, preferences:, access:, screenRecording: any ScreenRecording, system:, catalog:, scanner:, store:)

    /// Window swipe switch. Saved at once; the recognizers are rebuilt, so the next slide obeys it and one in progress ends.
    public func setWindowSwipe(on: Bool) { fatalError("not implemented") }
    /// The hint's button on its first press: the system prompt, and the fact that it was asked, saved before it shows.
    public func askForScreenRecording() { fatalError("not implemented") }

    private struct Run: Equatable { let trackpads: [Trackpad]; let handMode: HandMode; let blockClicks: Bool
                                    let swipes: Set<SwipeAxis>; let swaps: Bool }
    // reconcile(): swipes = (isSwipeOn ? [.sideways] : []) ∪ (isWindowSwipeOn ? [.vertical] : []);
    //              isScreenRecordingGranted = screenRecording.isGranted(); open = nil on a changed Run, as today.
    // start(): screenRecording.onChange = { reconcile() }; screenRecording.onPreview = { preview($1, for: $0) }
    /// Applies a still to the open window switcher; dropped when none is open or the window is not listed.
    private func preview(_ image: PreviewImage, for id: WindowID) { fatalError("not implemented") }
}

/// What the launcher window shows under the Accessibility hint while previews cannot be drawn.
public struct ScreenRecordingHint: Equatable, Sendable {
    public enum Action: Equatable, Sendable { case ask, openSettings }
    public let action: Action          // `.ask` until the prompt has been shown once, `.openSettings` after
    public var buttonTitle: String     // Copy.screenRecordingAsk / Copy.screenRecordingOpenSettings
}

// MARK: LauncherCore / Settings and Copy (additions)

public struct Settings {
    /// Whether two fingers sliding up or down under the thumb switch windows. The key is this field's name, permanently.
    public var isWindowSwipeOn = true
    /// Whether the screen recording hint's button has shown the system prompt. Not a switch; persisted state.
    public var screenRecordingAsked = false
}

public enum Copy {
    public static func gestureHint(for handMode: HandMode, swipe: Bool, windowSwipe: Bool) -> String
    /// The row name: the title; or the app's name, plus " — Window N" when `count > 1` (R6).
    public static func windowName(app: String?, title: String, index: Int, count: Int) -> String
    public static let noOpenWindows = "No open windows"
    public static let accessibilityForWindows = "Allow Accessibility to switch windows"
    public static let minimisedBadge = "Minimised"
    public static let screenRecordingHint = "Window previews need Screen Recording."
    public static let screenRecordingAsk = "Allow Screen Recording…"
    public static let screenRecordingOpenSettings = "Open System Settings…"
}

package enum GestureRules { /// The most rows either switcher holds.
    static let switcherMaxRows = 10 }   // renamed from switcherMaxApps; one cap for both lists
```

```swift
// MARK: LauncherPlatform

/// The whole window read and raise behind `SystemActions.frontmostWindows()` / `raise(_:)`, over the AX element
/// family and the CG window list. Holds no window, so tests construct it alone. The only file that may name
/// `AXUIElement`, `CGWindowListCopyWindowInfo` and `_AXUIElementGetWindow` (source policy).
@MainActor final class AppWindowReader {
    /// The latest read's windows, replaced by every read: the handle `raise` acts on.
    private var handles: [WindowID: AXUIElement] = [:]
    /// `_AXUIElementGetWindow` resolved with `dlsym`; nil on a macOS that drops it, which selects the fallback.
    private let windowNumber: (@convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError)?

    /// Pays the window list's first-call cost (52 ms, F11) away from the main actor now, not at the first swipe.
    init()

    func read() -> AppWindows {
        fatalError("not implemented")
        // TODO:
        //  app = NSWorkspace.shared.frontmostApplication, not our pid, else .none
        //  element = AXUIElementCreateApplication(pid); AXUIElementSetMessagingTimeout(element, 0.1)
        //  list = kAXWindowsAttribute; any error (APIDisabled, CannotComplete) → AppWindows(app, [])
        //  per element: AXUIElementCopyMultipleAttributeValues(title, subrole, minimized, position, size); a
        //    CannotComplete abandons the read (one timeout bounds it)
        //  number = windowNumber?(element) ?? match(position, size, title) against CG optionAll for the pid
        //  onScreen = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements]) filtered to pid,
        //    layer 0: front-to-back order and the current-Space test (F11, F24)
        //  visible rows: subrole == AXStandardWindow && !minimized && number ∈ onScreen, in onScreen order
        //  minimised rows: minimized == true, in AX order (subrole ignored: F9)
        //  handles = rows' elements; return AppWindows(app, visible + minimised)
    }

    func raise(_ id: WindowID) {
        fatalError("not implemented")
        // TODO: guard let element = handles[id]; if kAXMinimized read true, set it false (F21); AXRaise (F19, F20);
        //       every AXError, including kAXErrorInvalidUIElement for a closed window (F14), is ignored.
    }
}

extension WorkspaceActions {   // delegates, as runningApps() delegates to RunningAppsReader
    private let windows = AppWindowReader()
    public func frontmostWindows() -> AppWindows { windows.read() }
    public func raise(_ window: WindowID) { windows.raise(window) }
}

/// The one registration for tccd's `com.apple.tcc.access.changed` broadcast (about 30 ms after a change, main
/// queue, no payload, no service named). Each permission adapter owns one and re-reads itself on every post.
/// The only file that may call `notify_register` (the row moves here from SystemAccessibilityPermission.swift).
final class TCCChangeListener {
    init(onPost: @escaping @MainActor () -> Void)
    isolated deinit   // notify_cancel
}

/// ScreenRecording over the CG preflight and request calls, the TCC broadcast and ScreenCaptureKit stills. The only
/// file that may `import ScreenCaptureKit` or name `CGPreflightScreenCaptureAccess` / `CGRequestScreenCaptureAccess`.
@MainActor public final class SystemScreenRecording: ScreenRecording {
    public var onChange: (@MainActor () -> Void)?
    public var onPreview: (@MainActor (WindowID, PreviewImage) -> Void)?
    /// `preflight` is injectable for the adapter's own test, which flips it and posts the notification itself.
    public init(preflight: @escaping @Sendable () -> Bool = { CGPreflightScreenCaptureAccess() })
    public func isGranted() -> Bool { fatalError("not implemented") }      // preflight(); lastKnown updated
    public func request() { fatalError("not implemented") }                // CGRequestScreenCaptureAccess()
    public func capturePreviews(of windows: [WindowID]) {
        fatalError("not implemented")
        // TODO: generation += 1; guard preflight() else { return }
        //   Task { let shots = await Self.captureOffMain(windows, boxPixels: 120×60 pt × highest backing scale, generation)
        //          guard generation == self.generation else { return }
        //          for (id, image) in shots { onPreview?(id, image) } }
    }
    /// `@concurrent`: SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) (14 ms), match
    /// `SCWindow.windowID` to each id, `SCContentFilter(desktopIndependentWindow:)`, `SCStreamConfiguration` with
    /// width/height fitted to the window's frame inside the box, `scalesToFit`, `showsCursor = false`,
    /// `ignoreShadowsSingleWindow = true`; `SCScreenshotManager.captureImage` for every window concurrently (F27);
    /// each `CGImage` drawn into an RGBA premultiplied-last context and wrapped as `PreviewImage`.
    @concurrent private static func captureOffMain(_ ids: [WindowID], boxPixels: CGSize, _ generation: Int) async -> [(WindowID, PreviewImage)]
    private var generation = 0
    private var lastKnown: Bool
    private let listener: TCCChangeListener
}

// SystemAccessibilityPermission: unchanged but for taking its TCCChangeListener instead of calling notify_register.
// CursorTravel: unchanged (the curve and 100 points per item serve both axes).
// FrameStream.receive: `if case .began? = recognition.swipe { $0.travel = CursorTravel.travel(curves:) }`.
```

```swift
// MARK: LauncherUI

/// Renders `launcher.windowSwitcher` and holds nothing the model holds. Owned by `MenuBarShell` beside
/// `SwitcherPresenter`. The panel is created now; the app's icon comes from the running app (0.1 ms) at the swipe.
final class WindowSwitcherPresenter {
    private let launcher: Launcher
    private let panel = WindowSwitcherPanel()
    private let icons = AppIcons(side: WindowColumnLayout.fullRowHeight)   // no passes: one running app per swipe
    private var laidOut: WindowSwitcher?
    private var layout = WindowColumnLayout(rowCount: 0, displayHeight: 0)
    private var isShown = false
    private var fadeGeneration = 0
    init(launcher: Launcher)                       // Observations({ launcher.windowSwitcher }) → render
    private func render(_ switcher: WindowSwitcher?)   // see call site 3
    private func open(_ switcher: WindowSwitcher) {
        fatalError("not implemented")
        // TODO: screen = pointer's display; layout = WindowColumnLayout(rowCount:, displayHeight: visibleFrame.height)
        //       rows: .windows → (name, icon, isMinimised) per row; .noWindows / .accessibilityNeeded → one row
        //       with Copy text and the app's icon when `app` is non-nil
        //       panel.layoutRows(rows, layout:, topLeftOf: screen.visibleFrame, scale:); restoreOpacity; orderFrontRegardless
    }
    private func hide()                            // 150 ms fade then orderOut; panel.dropPreviews() in the completion (R17)
}

/// The switcher panel's configuration (borderless, non-activating, click-through, `.screenSaver`, every Space,
/// never key) around Liquid Glass: an `NSGlassEffectView` (.regular) whose content holds the clear glass highlight
/// under one `RowView` per row. Every number of the look is in `WindowSwitcherLook`.
final class WindowSwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    /// One row per entry, top to bottom, sized by `layout`; the panel sits `margin` inside the top-left of `visible`.
    func layoutRows(_ rows: [RowContent], layout: WindowColumnLayout, topLeftOf visible: NSRect, scale: CGFloat)
    /// Moves the highlight to `position` with actions disabled; the selected row's title goes semibold.
    func show(position: CGFloat, selected: Int)
    /// Crossfades the row's preview box from the icon to `image` (`WindowSwitcherLook.previewCrossfade`).
    func setPreview(_ image: PreviewImage, for id: WindowID)
    /// Clears every preview layer's contents: nothing of a window outlives the swipe on screen.
    func dropPreviews()
    func springHighlight(from offset: CGFloat)     // `position.y` spring, as the app switcher's `position.x`
    func fadeOut(duration: CFTimeInterval, completion: @escaping () -> Void)
    func restoreOpacity()

    struct RowContent { let id: WindowID?; let name: String; let icon: NSImage?; let isMinimised: Bool }
}

/// The look and motion, in one place, to be refined together later. Sizes that decide fit live in Core's layout.
struct WindowSwitcherLook: Sendable {
    var cornerRadius = 22.0, highlightInset = 6.0        // highlight corner = cornerRadius − inset (concentric)
    var titleFont = NSFont.systemFont(ofSize: 13, weight: .medium), selectedWeight = NSFont.Weight.semibold
    var minimisedAlpha = 0.5, badgeFont = NSFont.systemFont(ofSize: 10, weight: .semibold)
    var previewCornerRadius = 6.0, previewCrossfade = 0.12
    var fadeOut = 0.15, springStiffness = 420.0, springDamping = 22.0
    static let shipped = WindowSwitcherLook()
}

// SwitcherSection: a third row, "Swipe up or down to switch windows", illustration `window-swipe.svg`, bound to
//   launcher.isWindowSwipeOn / setWindowSwipe(on:).
// LauncherView: `if let hint = launcher.screenRecordingHint { SettingsNotice(message: Copy.screenRecordingHint,
//   button: hint.buttonTitle) { hint.action == .ask ? launcher.askForScreenRecording() : actions.openSettings(.screenRecording) } }`
// LauncherActions.SettingsPane: `.screenRecording` → …?Privacy_ScreenCapture.
// MenuBarShell: owns the second presenter; the refit tuple adds `launcher.screenRecordingHint`.
```

```swift
// MARK: Tests (the seams)

final class RecordingSystemActions: SystemActions {
    /// What the next `frontmostWindows()` answers; a test edits it between begin and lift (a window closes, an app
    /// stops answering: `windows: []`, the app changed).
    var windows: AppWindows = .none
    private(set) var windowReads = 0
    private(set) var raised: [WindowID] = []
}

final class InMemoryScreenRecording: ScreenRecording {
    init(granted: Bool = false)
    private(set) var requests = 0                       // prompts shown
    private(set) var captures: [[WindowID]] = []         // every request, in order
    func set(granted: Bool)                              // the TCC push, synchronous, on a real change only
    /// Defers stills until `deliverHeldPreviews()`; otherwise each `capturePreviews` delivers at once, while granted.
    func holdPreviews()
    func deliverHeldPreviews()
    /// A still for one window, out of order or after the swipe ended.
    func deliverPreview(for id: WindowID)
}

extension World {
    let screenRecording: InMemoryScreenRecording
    /// `app` frontmost with `windows` (name, minimised) as its windows, trust granted, started.
    static func windowWorld(app: String, windows: [(String, Bool)], accessGranted: Bool = true, screenRecording: Bool = true) -> World
    func window(_ name: String) -> WindowID
    func windows(without name: String) -> AppWindows
    /// Thumb at (10, 10), two fingers down, each slide in turn (millimetres, positive down), then the fingers lift.
    @discardableResult func windowSwipe(_ slidesMM: Double..., lift: Bool = true, on trackpad: Trackpad = .macBook14) -> TouchScript
}
// Fixtures: `fired/phases/swaps/perFrame` take `swipes: Set<SwipeAxis> = [.sideways, .vertical]`;
// TouchScript.tap gains `dragMM: (x: Double, y: Double)` for R1's drifting tap.
```

#### Module map

- **LauncherCore**: `Gesture` (`SwipeAxis`, `SwipePhase.began(axis)`), `GestureRecognizer` (axis-gated begin, axis-stored swipe), `PointerCurve`/`SwipeTravel` (two components, one chosen), `Selection` (new, the shared maths), `Switcher` (composes `Selection`), `Windows` (`WindowID`, `AppWindow`, `AppWindows`, `PreviewImage`), `WindowSwitcher` (+ `WindowRow`, `WindowLift`), `WindowColumnLayout`, `Ports` (`SystemActions` + 2, `ScreenRecording`), `Launcher` (one `open`, two derived switchers, the vertical paths, the hint), `Settings` (+2 fields), `Copy` (+ strings), `GestureRules` (`switcherMaxRows`).
- **LauncherPlatform**: `AppWindowReader` (new, confined AX + CG window list), `WorkspaceActions` (delegates), `TCCChangeListener` (new, confined `notify_register`), `SystemAccessibilityPermission` (uses the listener), `SystemScreenRecording` (new, confined SCK + preflight/request), `FrameStream` (began pattern match).
- **LauncherUI**: `WindowSwitcherPresenter`, `WindowSwitcherPanel`, `WindowSwitcherLook` (new), `SwitcherSection` (third row), `LauncherView` (hint), `LauncherActions` (`.screenRecording`), `MenuBarShell` (second presenter, refit).
- **Tests**: `InMemoryScreenRecording` (new), `RecordingSystemActions` (+3), `World` (+ window helpers), fixtures (axes), `SelectionTests` (the maths moved), `WindowSwitcherTests`, `WindowLiftTests`, `WindowColumnLayoutTests`, `CopyTests`, `SourcePolicyTests` rows, `PersistenceTests` (two fields, frozen record untouched), the flipped recognizer rows (how.md #32).
- **Source policy**: `Confined("AXUIElement", onlyIn: "AppWindowReader.swift")`, `Confined("CGWindowListCopyWindowInfo", "AppWindowReader.swift")`, `Confined("_AXUIElementGetWindow", "AppWindowReader.swift")`, `Confined("import ScreenCaptureKit", "SystemScreenRecording.swift")`, `Confined("CGPreflightScreenCaptureAccess", …)`, `Confined("CGRequestScreenCaptureAccess", …)`, `notify_register` moves to `TCCChangeListener.swift`; banned: `SCStream(`, `SCRecordingOutput`, `startCapture` ("previews are stills, never a stream or a recording"), `CGWindowListCreateImage`.
- **Docs**: `architecture.md` Privacy: two optional permissions; Accessibility also lists, raises and restores the frontmost app's windows during a window swipe; Screen Recording takes one still per listed window while a window switcher shows, in memory only, never a stream or a file; each API confined to one file by the scan (now true of `AXUIElement`). `domain-model.md`: the plan's new and changed terms; *Swipe setting* and *Click blocking* mention the window swipe; *Accessibility hint* scope widens.

#### Requirement coverage

| R | Carried by |
|---|---|
| R1 | `beginOrSpoil` (pair + `Move.axis` + `swipes.contains`), `.swipe(.began(.vertical))`; the drift tap stays under 3 mm by `drag` |
| R2 | `Swipe.axis` stored at begin; `.moved` takes only that component; a swipe never re-enters `beginOrSpoil` |
| R3 | `AppWindows` read at `.began`; `WindowSwitcher.init` (visible first, cut at `switcherMaxRows`); `let content` |
| R4 | `AppWindowReader.read` (subrole, CG on-screen = current Space, minimised by `kAXMinimized` alone); rows partitioned in `WindowSwitcher.init`; `WindowRow.isMinimised` → dimmed row with badge and icon |
| R5 | `WindowColumnLayout(rowCount:displayHeight:)` scale; `panel.layoutRows(topLeftOf: visibleFrame)`; panel config (never key, `ignoresMouseEvents`); `hide()` on `windowSwitcher == nil` |
| R6 | `Copy.windowName`; `PreviewImage` fitted inside 120 × 60; `previews` filling in via `preview(_:for:)`, icon until then; captured once at begin |
| R7 | `isScreenRecordingGranted` gate at `.began`; adapter preflight; `onChange` → `reconcile` |
| R8 | `screenRecordingHint` (nil when granted or setting off), `ScreenRecordingHint.action` from `settings.screenRecordingAsked`, `askForScreenRecording()`, `SettingsPane.screenRecording` |
| R9 | `Selection.follow/selected` (nearest, band), travel 0 at begin, `.cursor` y component at 100 points per row |
| R10 | `.moved` → `system.raise(row.id)` only on a change onto a visible row; closed window = adapter no-op; back to row 0 raises `front` |
| R11 | `WindowSwitcher.lift(given:)` plan (desired order, closed selected → no raises, minimised → raised/restored) |
| R12 | `WindowLift.playsHaptic`; one `.lightTick` per row crossed in `.moved`; no launch animation by construction |
| R13 | `Content.noWindows`, `app` nil → no icon; `Selection(count: 1)` bands both ends; `lift` returns `.nothing` for a notice |
| R14 | `Content.accessibilityNeeded` from `isAccessibilityGranted`; the existing Accessibility hint unchanged |
| R15 | `.swiping` blocking flags unchanged; cancel/end/rejoin unchanged; `.cancelled` → `open = nil` only |
| R16 | `Settings.isWindowSwipeOn`, `setWindowSwipe(on:)`, `Run.swipes: Set<SwipeAxis>`, `decodeIfPresent ?? true` |
| R17 | `PreviewImage` lives only in `WindowSwitcher.previews`; `open = nil` drops it; `panel.dropPreviews()` on hide; `.write(to:` banned |

### Synthesis decision

### Tradeoffs accepted

- We accept bitmap bytes in an `@Observable` model value (`WindowSwitcher.previews`, about 115 KB per window, at most ten) in exchange for previews that cross no framework type, a model that can say "icon until ready", and a seam a test can hold and release.
- We accept a second AX read at the lift (about 1 ms, plus one re-population of the handle table) in exchange for a minimal raise plan that is correct whatever the app did mid-swipe and for R11's closed-window rules falling out of one pure function.
- We accept both presenters waking on each other's switcher changes (both derive from one stored `open`; the idle one sees nil and returns) in exchange for "at most one switcher is open" being a property of the type.
- We accept changing every recognizer construction site from `swipes: Bool` to `swipes: Set<SwipeAxis>` in exchange for one gate that models both settings and admits no contradictory pair of flags.
- We accept a fixed 120 × 60 preview box with the still aspect-fitted inside, so a very wide window's preview is shorter than 60 pt, in exchange for no window geometry in the domain and no layout shift when a preview lands.
- We accept the AX adapter holding the latest read's handles (adapter state scoped to one swipe) in exchange for a port that carries only `WindowID` and a `raise` that is a no-op for anything not read.
- We accept `AXRaise` as the one lever, probed on TextEdit only, with the adapter clearing `kAXMinimized` first as belt and braces, in exchange for one effect method and no attribute-setting protocol on the port.
- We accept the model gating capture and the adapter preflighting again: the first decides state (no request means no previews to wait for), the second is the OS boundary that makes "never prompts" structural.
- We accept paying the CG window list's 52 ms first call at adapter init, off the main actor, in exchange for a documented front-to-back order and the only reliable current-Space test at the swipe.

### Alternatives considered

- **Previews as a shell-only concern**: `LauncherUI` captures with ScreenCaptureKit itself, keyed by `CGWindowID`, the model never hears of previews. Hides the bytes from the model, but exposes a permission API outside `LauncherPlatform` and the shell cannot preflight without a second file naming the call; "icon until ready", "never without permission" and "discarded at end" would have no test seam and no fake. Lost on testability and policy confinement.
- **A per-swipe session object** returned by `beginWindowSwipe()` with `raise`, `lift`, `windows` on it, the adapter keeping the snapshot. Deeper-looking, but it is a second object per swipe to fake, state split between model and adapter, and the lift would act on handles from begin instead of a fresh read, so a closed window and a changed app would be the adapter's problem instead of the pure plan's. Lost on locality.
- **One generic `Switcher<Row>`** instead of `Selection` composed by two values. The app switcher's `startsOnFrontmost` is stored and app-specific, the init takes `leavingOut`, and the two presenters would still be two; composition shares exactly the knowledge that is shared.
- **Lift = raise every listed window back to front, no second read**. Simplest, but up to ten AX calls on the main actor against an app that may be slow, and R11's "selected closed → no reordering" needs the read anyway.
- **A second `Recognition.Event` and state for the window swipe**. Two owners of one finger session; rejected by the task and why.md Avoid 1.

### Open questions and risks

- Is the vertical acceleration really the same multiplier on `dy` (F3, O1)? The sketch assumes symmetry; should the first hardware check compare a vertical slide's feel against a sideways one at the same tracking speed before 100 points per row is frozen?
- A minimised window may belong to another Space; restoring it on the lift would switch Spaces (F24). Should such windows be listed at all, given a minimised window's Space cannot be read, or is the switch acceptable because the user asked for that window?
- Should a lift that raises also close the launcher window, as a swipe lift does, or leave it since the user stayed in the same app?
- Is a 100 ms AX messaging timeout the right bound, and should a non-answering app show "No open windows" (as sketched) or nothing?
- macOS 15+'s periodic "bypass the system picker" alert for ScreenCaptureKit capture without the picker (F31): acceptable for a feature whose captures are a few stills per swipe, or does it push towards the picker or no previews?
- Does `CGRequestScreenCaptureAccess()` prompt again after a denial (O2)? The design persists "asked", so the answer changes nothing, but should the second press also re-request before opening System Settings?
- The window switcher's top-left corner follows `visibleFrame`, so a left-hand Dock shifts it right: intended?
- Risk: the window switcher flashes for two- and three-finger taps that drift vertically past 3 mm, as the app switcher already does sideways (Risk 3), and the window read plus capture request runs for each such flash.

### Next implementation step

Add `SwipeAxis`, `SwipePhase.began(_:)` and `swipes: Set<SwipeAxis>` to the recognizer with the flipped vertical-begin tests, since every later piece hangs off that one event.
