# Candidate 1: plan 042 (window stacks, a stable window order, the no-windows card)

## Design

### Problem

Three behaviours land on switchers that decide everything once, at a slide's start, and keep it for the slide's life.

**Stacks** need the window counts of up to ten apps. Today the only window reader reads only the frontmost app, synchronously on the main actor, and every read replaces its raise handles (F1). Plan 012 rejected an async read for the window swipe (Change 3). A count must equal what the window switcher would list for that app (R2). It must arrive without the switcher waiting (R4), each app within 0.2 s and with no timer. The 0.2 s messaging timeout bounds one call, not one read: a slow app can take (1 + 2N) × 0.2 s (F8). Hidden apps' document windows report `AXDialog` and are missing from the on-screen list (F12).

**A stable window order** is the first window state the model keeps across slides (F23). Three facts make it hard:
- To the Accessibility read, an off-Space window looks exactly like a closed one (F21).
- No app-quit push reaches the model (F22).
- "Row 0 is the front window" is built into `WindowList`, `frontWindow` and the lift's z-order restore (F24).

**The card** inverts the two-or-more rule. Today that rule also quietly filters out the own process, timeouts and partial reads (F18). The read must now tell these cases apart, and the start's verdict must still be given inside the `onEvent` call (F27).

The design keeps these invariants:
- A raise names only ids from the latest frontmost read.
- A declined slide is exactly the setting-off slide.
- The lift is computed from a second read.
- A silent lift has no side effect, so nothing hides.
- The frame thread never waits.
- Accessibility (AX) and the window list stay in two files.
- Core imports Foundation and Observation only.
- Every port keeps exactly two adapters.
- There are no timers.

### Usage (caller's view)

The model reads windows in two ways, and both answer in one shared vocabulary: `WindowRead` and its one `windowCount`.

```swift
// README: window reads, from the model (LauncherCore)
//
// A slide up or down: one synchronous read, held to 0.2 s, decides it and brings the app's window order up to date.
//   let read = system.frontmostWindows(within: GestureRules.windowReadDeadline)
//   windowOrders.list(read)          // nil: no window swipe; otherwise the rows in the app's order, or the card
//
// A swipe: the row shows first, then each row app's windows are read away from the main actor. Each app answers once,
// within 0.2 s or as `.unanswered`, and a count lands only in the switcher it was read for.
//   system.readWindows(of: switcher.row, within: GestureRules.windowReadDeadline) { slot, read in ... }
//
// Both reads count through `WindowRead.windowCount`, so the stacks and the window switcher can never count differently (R2).
```

Call site 1, `Launcher.swipe(.began)` and the count landing:

```swift
case .began:
    guard shown == nil, activity.isActive else { return }
    let running = system.runningApps()
    guard let switcher = Switcher(
        frontmost: running.frontmost, running: running.apps, leavingOut: settings.assignedBundleIDs,
        serial: switchersBegun + 1, trackpad: event.trackpad) else { return }
    switchersBegun += 1
    shown = .apps(switcher)                                   // R4: the row is up before any read starts
    guard isAccessibilityGranted else { return }              // R3: no window can be read
    let serial = switcher.serial
    system.readWindows(of: switcher.row, within: GestureRules.windowReadDeadline) { [unowned self] slot, read in
        counted(read, at: slot, swipe: serial)
    }

/// A count lands only in the switcher it was read for, once per slot; an ended, cancelled, reconciled or later
/// swipe's switcher drops it.
private func counted(_ read: WindowRead, at slot: Int, swipe serial: Int) {
    guard case .apps(var open)? = shown, open.serial == serial, open.take(read, at: slot) else { return }
    shown = .apps(open)
}
```

Call site 2, `Launcher.windowSwipe`:

```swift
case .began:
    guard activity.isActive,
          let content = windowOrders.list(system.frontmostWindows(within: GestureRules.windowReadDeadline))
    else { return }                                           // R13: no app, or no answer within 0.2 s
    hardware.confirmWindowSwipe(on: event.trackpad)
    guard shown == nil else { return }
    switchersBegun += 1
    shown = .windows(WindowSwitcher(content, showsPreviews: isScreenRecordingGranted, serial: switchersBegun,
                                    trackpad: event.trackpad))
case .moved(let travel):                                      // unchanged: the card's one-item selection never ticks
    ...
case .ended:
    guard case .windows(let open)? = shown, open.trackpad == event.trackpad else { return }
    shown = nil
    guard !open.isCard else { return }                        // R12: no read, no raise, no haptic, no hide
    let lift = open.lift(now: system.frontmostWindows(within: GestureRules.windowReadDeadline))
    if lift.playsHaptic { hardware.playFeedback(.gesture, on: event.trackpad) }
    system.raiseWindows(lift.raises)
    if lift.playsHaptic { hideOtherApps(than: open.app.bundleID) }
```

Call site 3, the views (LauncherUI):

```swift
// SwitcherPresenter.render
if switcher.serial != laidOutSerial { open(switcher) }        // keyed by the swipe, never by the row (F33, F37)
for slot in switcher.row.indices {
    let copies = stackLayout.copies(forWindows: switcher.windowCounts[slot])
    guard copies.count > shownCopies[slot] else { continue }  // a count lands once per swipe, so a stack rises once
    panel.addStack(at: slot, copies: copies, rises: !reduceMotion())
    shownCopies[slot] = copies.count
}
panel.show(position: ..., selected: ..., animatesSize: !reduceMotion())

// WindowSwitcherPresenter.render
switch switcher.content.list {
case .rows: panel.show(position: selection.position, selected: selection.selected) // + today's spring
case .card: panel.moveCard(by: reduceMotion() ? 0 : switcher.cardOffset ?? 0, animated: !reduceMotion())
}
```

Call site 4, a model test at the high seam:

```swift
let world = World.switcherWorld(apps: ["Safari", "Mail", "Notes"], accessGranted: true)
world.windows(of: "Safari").set(visible: ["S1", "S2"])
world.windows(of: "Mail").set(visible: ["M1", "M2"])
world.windows(of: "Mail").holdsCountAnswers = true            // a slow app: the test answers it
world.swipe(3.5, lift: false)
#expect(world.launcher.switcher?.windowCounts == [2, nil, 0])
world.answerCountReads(of: "Mail")                            // "150 ms later"
#expect(world.launcher.switcher?.windowCounts == [2, 2, 0])
```

### Shape

**Data shapes first, per model-the-domain.**

*The read.* `WindowRead` is a three-case sum: `.windows(AppWindows)`, `.unanswered` and `.ownProcess`. The swipe start's verdict, the lift and the stacks all switch over it exhaustively, per type-system-discipline.
- A partial read, a read past its deadline, missing Accessibility and an app that has quit are all `.unanswered`. That closes open question 5.
- `AppWindows` gains `elsewhere`: the app's windows the window server still holds that are not listed (another Space, a full-screen Space, helpers).

*The count.* `WindowRead.windowCount` (`Int?`) is the one count rule. It is built on `WindowPick`, today's R9 pick: the front window, the other visible windows front to back, then the minimised ones, ten at most, and a full-screen front window alone.
- The stacks take the count as their size.
- `WindowOrders.list` reads the same count for its choice: two or more gives rows, otherwise the card.
- R2 therefore holds by construction.
- The platform's one `sort` is shared by both reads, so panels and other Spaces drop out before Core sees anything.

*Hidden apps (settles open question 1).* `sort` gains one branch, used only for a hidden app: a window counts as visible when it is an `AXWindow`, not minimised, not full screen, and has a full-screen button. The hidden-app probe (F12) separated document windows from panels by exactly this.
- The frontmost app is never hidden, so the window switcher's own read is unchanged.
- The stacks therefore count what a window swipe into the app would list once the app is in front.

*The order (settles open question 2).* `WindowOrders` holds `[URL: [WindowID]]` inside `Launcher` and is updated only at a window swipe's start.
- A remembered id that is neither listed nor in `elsewhere` has closed, and leaves the order.
- An id in `elsewhere` keeps its place and is not listed.
- Listed windows the order lacks join at its end, in the order they opened (window numbers only ever increase, F19).
- An order with nothing left is set as today's list. That one rule covers the first window swipe, a relaunch (every old number is gone) and a Trackpad Launcher restart (no state).
- So "the app quitting forgets it" holds with no quit push. Window numbers are never reused, so a quit app's order empties itself at its next read.
- The update is idempotent, per make-operations-idempotent.
- The stacks read never writes an order. Only "the first window swipe into an app sets its order".

*The switcher contents.* `WindowSwitcher.List` is either `.rows(Rows)` or `.card(NoWindowsCard)`.
- `Rows` holds the rows in the app's order, `frontWindow`, and the begin z-order (`zOrder`), kept apart from the display order so the lift still restores "the selected window, the one that was in front, then the others as before" (Risk 3).
- The selection starts on the front window's row, or on row 0 (R8).
- The card is a one-item window switcher. Its existing one-item selection already forgets the overshoot at a turn and already crosses nothing, so no light tick plays. `cardOffset` is a pure mapping of that selection's `stretch`, held rather than sprung: eased, and at most 6 pt either way (R11).

*Stacks in the model.* `Switcher` gains `serial` and `windowCounts: [Int?]`, keyed by slot so two copies of one bundle never collide (F3). `take` fills an unknown slot once, so a count read at the begin holds for the swipe (R4).

*Stack shape.* `WindowStackLayout` sits beside `SwitcherRowLayout`. From a window count it gives the copies:
- each copy's side (92, 84, 76 % of the icon),
- its rise above the icon's centre (6 pt × layer × the row's scale),
- its delay (40 ms per layer).

The cap of four icons is derived from the copy table (`copyScales.count + 1`), so there is one source of truth for it.

**Where things live.**

*The 0.2 s budget* is a Core constant, `GestureRules.windowReadDeadline`, and both port calls receive it as an argument, as `bringToFrontWatching` receives `cap:`. The adapter enforces it with the pure `ReadBudget` (settles open question 3):
- Before each call into the app, the element's messaging timeout is set to what is left of the budget (F9).
- A read that ends after the deadline counts as `.unanswered`, so a late answer can never get through.
- Nothing fires at the deadline: an app that has not answered simply stays unknown.

This is the same "stamped on the monotonic clock, nothing fires" shape the lift window already uses.

*The frontmost read* stays synchronous on the main actor (012's decision), now held to 0.2 s in all.

*The stacks read* runs one GCD work item per app, not the cooperative pool. A blocked call holds its thread for up to the budget, and it must not hold up the other reads (F8). Only `Sendable` reads hop back. AX elements never leave the frontmost path, which alone keeps raise handles (Preserve 1).

*Deadline and test handles.*
- The model holds no clock.
- The test twin answers each app at once, holds an answer for the test to release later, or answers `.unanswered` (the adapter's verdict for "not within 0.2 s").
- `ReadBudget` takes the time as an argument, so platform tests drive the clock.

**Depth.**
- The port grows by one call. `readWindows` hides process lookup, own-process detection, the hidden rule, the budget, the threads and the hop back.
- `WindowOrders.list` is one method that hides the pick, the whole lifecycle of the order, card versus rows, the row order and the selection start.
- `Launcher` keeps its shape, with no new branches beyond the card's silent lift. Per boundary-discipline, the decision logic is pure and the shell is thin.

**What the design deliberately does not do:**
- No AX observers.
- No count ever decides whether a slide is a window swipe or what a lift does (Avoid 3).
- No warm-up reads at launch.
- Nothing is saved.
- Nothing is reordered mid-swipe.
- No new push for an app quitting.

**Module map.**

| Module | New or changed |
|---|---|
| `LauncherCore` | `AppWindows`, `WindowRead`, `FrontmostWindows` (reshaped), `WindowPick`, `WindowOrders`, `WindowSwitcher` (`List`, `Rows`, `NoWindowsCard`, `cardOffset`), `Switcher` (`serial`, `windowCounts`), `WindowStackLayout`, `RaiseOrder` (the old `WindowStack`, renamed to free the glossary word), `SwitcherSelection.init(count:startingAt:)`, `GestureRules.windowReadDeadline`, `Copy` (four strings), `SystemActions` (two members), `Launcher` |
| `LauncherPlatform` | `AppWindowReader` (the old `FrontmostAppWindows`, renamed, with its file and its confinement entry), `ReadBudget`, `RawWindow.hasFullScreenButton`, `WorkspaceActions` |
| `LauncherUI` | `SwitcherPresenter`/`SwitcherPanel` (keyed by serial, one container per slot, `addStack`), `WindowSwitcherPresenter`/`WindowSwitcherPanel` (card mode, `NoWindowsCardView`), `reduceMotion` injected as `GearView` does |
| App target | nothing |
| Tests | per-app `FakeWindows` with `elsewhere` and `holdsCountAnswers`, the `readWindows` twin, `World` helpers |

```swift
// MARK: - LauncherCore: what a read says

/// One app's windows as one read found them.
public struct AppWindows: Equatable, Sendable {
    /// Its windows on the current Space, front to back; for a hidden app, its document windows, which show when it
    /// is shown again. Panels, palettes, sheets and other helpers are left out.
    public let visible: [AppWindow]
    /// Its minimised windows, in the order the app lists them.
    public let minimised: [AppWindow]
    /// Its other windows the window server still holds: on another Space or a full-screen Space (helpers too). They
    /// keep their place in the app's window order; they are never listed and never raised.
    public let elsewhere: Set<WindowID>

    public init(visible: [AppWindow], minimised: [AppWindow], elsewhere: Set<WindowID> = [])
}

/// What one read of one app's windows came to.
public enum WindowRead: Equatable, Sendable {
    /// Every call into the app answered within the read's deadline.
    case windows(AppWindows)
    /// No answer within the deadline, a call that could not complete partway (what was read so far is dropped), no
    /// Accessibility, or the app no longer running.
    case unanswered
    /// Trackpad Launcher itself, which is never read: its one window is the settings window.
    case ownProcess
}

/// One read of the frontmost app's windows.
public enum FrontmostWindows: Equatable, Sendable {
    case noApp
    case app(AppEntry, WindowRead)
}

extension WindowRead {
    /// How many windows a window swipe into the app lists (R2): `WindowPick`'s count, at most ten; one for Trackpad
    /// Launcher's settings window; nil when the app did not answer. The one count both the stacks and the window
    /// switcher's choice between rows and the card read.
    public var windowCount: Int? {
        switch self {
        case .windows(let windows): WindowPick(windows).count
        case .ownProcess: 1
        case .unanswered: nil
        }
    }
}

/// The windows a window swipe into the app lists, picked from one answered read (R2, R9): the window in front, the
/// other visible windows front to back, then the minimised ones in the app's order, `windowSwitcherMaxRows` at most. A
/// full-screen front window is picked alone, minimised ones included out; other full-screen windows never.
struct WindowPick: Equatable, Sendable {
    let front: AppWindow?
    let others: [AppWindow]
    let minimised: [AppWindow]

    init(_ windows: AppWindows) {
        // TODO: today's `Content.init?` cut, without the two-row guard:
        //   front = visible.first; if front.isFullScreen { others = [], minimised = [] }
        //   others = visible.dropFirst().filter { !$0.isFullScreen }.prefix(limit - 1)
        //   minimised = windows.minimised.prefix(limit - (front == nil ? 0 : 1) - others.count)
        fatalError("not implemented")
    }

    var count: Int { (front == nil ? 0 : 1) + others.count + minimised.count }
    /// The picked visible windows, front to back: what a lift on the front window restores.
    var zOrder: [WindowID] { ((front.map { [$0] } ?? []) + others).map(\.id) }
    var windows: [AppWindow] { (front.map { [$0] } ?? []) + others + minimised }
}

// MARK: - LauncherCore: the window order

/// Each app's window order, kept for as long as the app and Trackpad Launcher run, never saved. Owned by `Launcher`;
/// written only when a window swipe starts. The stacks' reads never touch it.
package struct WindowOrders: Equatable, Sendable {
    private var orders: [URL: [WindowID]] = [:]

    package init() {}

    /// What a slide up or down shows, from the read at its start. First it brings the app's order up to date with an
    /// answered read. Returns nil (no window swipe, R13) for no frontmost app and for an app that did not answer. Returns
    /// the card (R10) for a count of zero or one: no windows, one window, a lone minimised one, a full-screen front
    /// window, or Trackpad Launcher itself. Otherwise returns the rows: the R9 pick in the app's order, the front window's
    /// row noted. Idempotent: the same read twice leaves the same order and gives the same content.
    package mutating func list(_ read: FrontmostWindows) -> WindowSwitcher.Content? {
        // TODO:
        //   guard case .app(let app, let windowRead) = read, let count = windowRead.windowCount else { return nil }
        //   if case .windows(let windows) = windowRead { orders[app.url] = Self.updated(orders[app.url] ?? [], with: windows) }
        //   guard count >= 2, case .windows(let windows) = windowRead else {
        //       return Content(app: app, list: .card(NoWindowsCard(count == 0 ? .noWindows : .oneWindow, of: app)))
        //   }
        //   let pick = WindowPick(windows); let order = orders[app.url]!
        //   rows = pick.windows sorted by order.firstIndex(of:), titled as today (untitled: "‹App› — Window N", N its row)
        //   return Content(app: app, list: .rows(Rows(rows:, frontWindow: pick.front?.id, zOrder: pick.zOrder)))
        fatalError("not implemented")
    }

    /// The app's order now; [] before its first window swipe and once every remembered window has closed.
    package func order(of app: AppEntry) -> [WindowID] { orders[app.url] ?? [] }

    /// The order brought up to date with one answered read. Pure.
    /// - Remembered windows that are neither listed nor `elsewhere` have closed (window numbers are never reused, so
    ///   after a relaunch every remembered number is gone): they leave, and the rest keep their places.
    /// - Listed windows the order lacks join at its end, in the order they opened (rising window numbers).
    /// - An order with nothing left is set as today's list instead: the front window, the other visible windows front to
    ///   back, then the minimised ones. That is the first window swipe, a relaunch, and a Trackpad Launcher restart.
    static func updated(_ order: [WindowID], with windows: AppWindows) -> [WindowID] {
        // TODO:
        //   let listed = windows.visible + windows.minimised
        //   let open = Set(listed.map(\.id)).union(windows.elsewhere)
        //   let kept = order.filter(open.contains)
        //   guard !kept.isEmpty else { return (windows.visible + windows.minimised).map(\.id) }   // today's list
        //   return kept + listed.map(\.id).filter { !kept.contains($0) }.sorted { $0.rawValue < $1.rawValue }
        fatalError("not implemented")
    }
}

// MARK: - LauncherCore: the window switcher, rows or the card

public struct WindowSwitcher: Equatable, Sendable {
    /// What one window swipe shows, fixed at its start.
    public struct Content: Equatable, Sendable {
        public let app: AppEntry
        public let list: List
    }

    public enum List: Equatable, Sendable {
        /// Two to ten windows, in the app's window order.
        case rows(Rows)
        /// Zero or one window: the no-windows card in place of the rows.
        case card(NoWindowsCard)
    }

    public struct Rows: Equatable, Sendable {
        /// Top to bottom, in the app's window order. `Row` is unchanged: visible or minimised, with its title.
        public let rows: [Row]
        /// The app's window in front when the window swipe began; nil when every listed window is minimised. The
        /// selection starts on its row (R8).
        public let frontWindow: WindowID?
        /// The listed visible windows, front to back, at the start: a lift restores this order behind the selected
        /// window. Kept apart from the row order, which no longer follows the z-order.
        let zOrder: [WindowID]
    }

    public enum Row: Equatable, Sendable { /* unchanged */ }

    public let content: Content
    /// Rows: one item per row, starting on the front window's row (row 0 when there is none). The card: one item, so it
    /// rubber-bands both ways and crosses nothing, so no light tick plays.
    public package(set) var selection: SwitcherSelection
    /// The switchers begun since launch, either kind: tells one window swipe's switcher from the next.
    public let serial: Int
    public let trackpad: TrackpadID
    public let showsPreviews: Bool

    package init(_ content: Content, showsPreviews: Bool, serial: Int, trackpad: TrackpadID) {
        // TODO: rows: SwitcherSelection(count: rows.count, startingAt: rows.firstIndex { $0.window == frontWindow } ?? 0)
        //       card: SwitcherSelection(count: 1)
        fatalError("not implemented")
    }

    public var app: AppEntry { content.app }
    public var isCard: Bool { if case .card = content.list { true } else { false } }
    /// [] for the card.
    public var rows: [Row] { if case .rows(let rows) = content.list { rows.rows } else { [] } }
    /// The visible rows while `showsPreviews`; never for the card.
    public var previewWindows: [WindowID] { fatalError("not implemented") }
    public var frontWindow: WindowID? { if case .rows(let rows) = content.list { rows.frontWindow } else { nil } }
    /// nil on a minimised row and on the card.
    public var selectedVisibleWindow: WindowID? { fatalError("not implemented") }
    /// The card's offset from rest, in points, positive down: the one-item selection's rubber band, held while the
    /// fingers hold. nil for rows.
    public var cardOffset: Double? { isCard ? NoWindowsCard.offset(stretch: selection.stretch) : nil }
}

/// The window switcher's single card for an app with zero or one window (R10). It shows the app's icon on the left,
/// a bold first line and a regular second line.
public struct NoWindowsCard: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case noWindows, oneWindow }

    public let kind: Kind
    /// "No open windows" / "No other windows".
    public let title: String
    /// "‹App› has no windows on this desktop." / "‹App› has no other windows on this desktop."
    public let message: String

    package init(_ kind: Kind, of app: AppEntry) {
        // TODO: from Copy.noOpenWindows*/Copy.noOtherWindows* with app.name
        fatalError("not implemented")
    }

    /// The most the card moves from rest, either way.
    public static let maxOffset = 6.0

    /// The card's offset for a one-item selection's `stretch`: maxOffset × stretch / the stretch at full overshoot.
    /// The selection keeps travel within a quarter row of rest and, when the fingers turn, restarts it from the turn.
    /// So the offset follows the movement since the last change of direction, damped by the rubber band's curve, never
    /// past 6 pt, and turns at once (R11). Pure.
    public static func offset(stretch: Double) -> Double {
        // TODO: maxOffset * stretch / SwitcherSelection.fullStretch
        fatalError("not implemented")
    }
}

extension WindowSwitcher {
    /// The lift, from the start's rows and a second read (012's rules, restated against the order). Pure.
    /// - The card, no app, another app, no answer or Trackpad Launcher: `.nothing`.
    /// - The selected window has closed (or left this Space): no raises; the haptic plays iff a window is in front now
    ///   and it is not `frontWindow`.
    /// - Otherwise the target is the selected window, then `zOrder` without it and without any window not listed now.
    ///   The raises are `RaiseOrder.raises(current: visible now, target:)`. The haptic plays iff the selected window is
    ///   not `frontWindow`, which covers restoring a minimised one. Every raised id comes from the second read, so
    ///   nothing on another Space is ever raised (Preserve 1).
    public func lift(now: FrontmostWindows) -> WindowLift { fatalError("not implemented") }
}

/// Today's `WindowStack.raises(current:target:)`, renamed so "window stack" means what the glossary says.
public enum RaiseOrder {
    public static func raises(current: [WindowID], target: [WindowID]) -> [WindowID] { /* unchanged */ fatalError() }
}

extension SwitcherSelection {
    /// Starts on item `start` (clamped): travel is `start` steps along, and nothing has been reported yet, so the next
    /// `follow` moves by the frame's own travel.
    package init(count: Int, startingAt start: Int) { fatalError("not implemented") }

    /// `stretch` at the full overshoot (a quarter item): the most the rubber band shows, about 0.111 items.
    public static var fullStretch: Double { fatalError("not implemented") }
}

// MARK: - LauncherCore: stacks in the app switcher

public struct Switcher: Equatable, Sendable {
    public let row: [AppEntry]
    /// The switchers begun since launch, either kind: the presenter lays out once per swipe and keys the rise on it.
    public let serial: Int
    /// Each slot's window count, as a window swipe into its app would list (R2), once its app answered. nil until
    /// then, and for the whole swipe if it never does (R4). Read once when the swipe begins; a known count never
    /// changes. Keyed by slot: two copies of one bundle are two slots.
    public private(set) var windowCounts: [Int?]
    public package(set) var selection: SwitcherSelection
    public let trackpad: TrackpadID
    private let startsOnFrontmost: Bool

    package init?(frontmost: AppEntry?, running: [AppEntry], leavingOut: Set<BundleID>, serial: Int, trackpad: TrackpadID)

    /// Fills an unknown slot from its app's read: true when that changed the switcher. A known slot, an unanswered read
    /// and a slot out of range change nothing.
    @discardableResult package mutating func take(_ read: WindowRead, at slot: Int) -> Bool {
        // TODO: guard windowCounts.indices.contains(slot), windowCounts[slot] == nil, let count = read.windowCount
        fatalError("not implemented")
    }
}

/// Where a window stack's copies sit behind an icon of `row`'s size, measured from the icon's centre with y up. The
/// front icon is the lone icon, unchanged, so the row's spacing, the highlight and the panel stay as they are (R5).
/// Copies grow with the selected icon because they live in its slot, whose transform the panel scales.
public struct WindowStackLayout: Equatable, Sendable {
    /// Each copy's side as a share of the icon's, nearest first. One copy per extra window.
    public static let copyScales = [0.92, 0.84, 0.76]
    /// The most icons a stack holds: the icon and one copy per scale.
    public static var maxIcons: Int { copyScales.count + 1 }
    /// How far each copy's top edge sits above the top edge of the one in front, at full size.
    public static let fullPeek = 6.0
    /// The rise: seconds, the delay between neighbouring copies, and a soft ease-out as cubic Bézier control points.
    public static let riseDuration = 0.3
    public static let riseStagger = 0.04
    public static let riseCurve: [Double] = [0.25, 1.0, 0.5, 1.0]

    public let row: SwitcherRowLayout
    public init(row: SwitcherRowLayout) { self.row = row }

    public struct Copy: Equatable, Sendable {
        /// Side, in points.
        public let side: Double
        /// Centre at rest, above the icon's centre: (icon + peek × layer − side) / 2 at full size, × the row's scale.
        /// The rise starts at 0, exactly behind the icon.
        public let rise: Double
        /// Seconds after the stack appears that this copy starts rising: the nearest first.
        public let delay: Double
    }

    /// Nearest first. None while the count is unknown or below two; one per extra window, three at most (R1).
    public func copies(forWindows count: Int?) -> [Copy] { fatalError("not implemented") }
}

// MARK: - LauncherCore: rules, strings, ports

extension GestureRules {
    /// The most one read of one app's windows may take, from the moment it is asked for (R4, R13). Both reads carry
    /// it; the adapter holds every call into the app to what is left of it.
    package static let windowReadDeadline = Duration.milliseconds(200)
}

extension Copy {
    public static let noOtherWindowsTitle = "No other windows"
    public static func noOtherWindowsMessage(of app: String) -> String { "\(app) has no other windows on this desktop." }
    public static let noOpenWindowsTitle = "No open windows"
    public static func noOpenWindowsMessage(of app: String) -> String { "\(app) has no windows on this desktop." }
}

@MainActor public protocol SystemActions: AnyObject {
    // ... every other member unchanged ...

    /// The frontmost app's windows, read now on the main actor and held to `deadline` in all. Each call into the app
    /// waits at most what is left of it, and a read that runs past it is `.unanswered`, so this returns within
    /// about `deadline`. Never reads Trackpad Launcher (`.ownProcess`). The windows it lists are the only ones a later
    /// `raiseWindows` may name, until the next read.
    func frontmostWindows(within deadline: Duration) -> FrontmostWindows

    /// Reads each app's windows away from the main actor, each on its own and each held to `deadline` from this call,
    /// and returns at once. `answer` runs on the main actor exactly once per slot of `apps`, in no set order. A slow or
    /// hung app delays no other. An app that did not answer in time, stopped answering partway, or no longer runs gets
    /// `.unanswered`; Trackpad Launcher gets `.ownProcess`. These reads replace nothing `raiseWindows` uses, and
    /// nothing they list is ever raised.
    func readWindows(
        of apps: [AppEntry], within deadline: Duration,
        answer: @escaping @Sendable @MainActor (_ slot: Int, _ read: WindowRead) -> Void)

    /// Unchanged: raises ids of the latest `frontmostWindows` read only.
    func raiseWindows(_ frontToBack: [WindowID])
}

// MARK: - LauncherCore: Launcher, the changed state

// @ObservationIgnored private var switchersBegun = 0          // replaces windowSwipesBegun; both kinds take a serial
// /// Each app's window order. Written only by `windowSwipe(.began)`; survives reconciles; never saved.
// @ObservationIgnored private var windowOrders = WindowOrders()
// The doc comment on `windowSwitcher` ("it always shows") becomes true again.

// MARK: - LauncherPlatform

/// The switchers' window reads and raises: the frontmost app's on the main actor, whose listed windows a raise may
/// name; and the switcher row's away from it, which are only counted. One of the two files allowed the Accessibility
/// element API and the window list (renamed from `FrontmostAppWindows`; the confinement entry follows the name).
@MainActor final class AppWindowReader {
    /// The process default for any element that sets none. Every read here sets its own per call.
    static let messagingTimeout: Float = 0.2
    private var listed: [WindowID: AXUIElement] = [:]
    private var isUnanswering = false

    /// Unchanged: the process default, the private window number resolved once into a Sendable holder, and the
    /// window list warmed away from the main actor.
    init() { fatalError("not implemented") }

    /// The frontmost app's read, held to `deadline`; replaces the raise handles with the listed windows' elements.
    func readFrontmost(within deadline: Duration) -> FrontmostWindows {
        // TODO: listed = [:]; isUnanswering = false
        //   frontmost via NSWorkspace → .noApp; own pid → .app(entry, .ownProcess)
        //   let (read, elements) = Self.read(Target(pid, isHidden: false), budget: ReadBudget(from: .now, within: deadline))
        //   listed = elements; isUnanswering = read == .unanswered
        fatalError("not implemented")
    }

    /// Unchanged.
    func raise(_ frontToBack: [WindowID]) { fatalError("not implemented") }

    /// One GCD work item per app, never the cooperative pool: a call into a hung app holds its thread for what is left
    /// of the deadline, and that must hold up no other read and no other concurrent work. Each work item resolves its
    /// app's process from `AppEntry.url` (`NSRunningApplication` is thread safe), reads, and hops only the `Sendable`
    /// read to the main actor.
    nonisolated static func readEach(
        _ apps: [AppEntry], within deadline: Duration,
        answer: @escaping @Sendable @MainActor (Int, WindowRead) -> Void
    ) {
        // TODO: let budget = ReadBudget(from: .now, within: deadline)   // one deadline for every app, from the call
        //   for (slot, app) in apps.enumerated() { DispatchQueue.global(qos: .userInitiated).async {
        //       let read: WindowRead = Target(app).map { $0.isOwn ? .ownProcess : read($0, budget: budget).read } ?? .unanswered
        //       Task { @MainActor in answer(slot, read) } } }
        fatalError("not implemented")
    }

    /// One app's whole read, on the calling thread. It makes these calls: kAXWindows; one multiple-attribute call per
    /// window (role, subrole, title, minimised, full screen, position, size, full-screen button); the private window
    /// number; the window list on screen (order) and in all (`elsewhere`, and the frame fallback). Before each call into
    /// the app, the element's messaging timeout is set to `budget.timeout(at: .now)`. No time left, any error but
    /// success from a call into the app, or a read that `budget` does not admit when it ends, gives `.unanswered`, whatever
    /// was read so far (R13's partial read). Returns the listed windows' elements, for the one caller that raises.
    nonisolated static func read(_ target: Target, budget: ReadBudget)
        -> (read: WindowRead, elements: [WindowID: AXUIElement]) { fatalError("not implemented") }

    /// Which windows are listed, and in what order. Pure; tested with probe facts.
    /// - Shown app: an AXWindow/AXStandardWindow, not minimised, on screen, in the window list's order (unchanged).
    /// - Hidden app: an AXWindow, not minimised, not full screen, with a full-screen button, in the app's order. Its
    ///   document windows report AXDialog and leave the on-screen list, but keep that button, which panels lack (F12).
    /// - Minimised: by the flag alone, in the app's order (unchanged). A window with no number is left out.
    nonisolated static func sort(_ windows: [RawWindow], onScreen: [UInt32], appIsHidden: Bool)
        -> (visible: [AppWindow], minimised: [AppWindow]) { fatalError("not implemented") }

    struct Target: Sendable {
        let pid: pid_t
        let isHidden: Bool
        let isOwn: Bool
        /// The running copy at `app.url` (the location spelling every read shares); nil when none runs.
        init?(_ app: AppEntry) { fatalError("not implemented") }
    }
}

/// What is left of one read's deadline, on the process's monotonic clock. Pure: tests pass the time.
struct ReadBudget: Equatable, Sendable {
    let deadline: Uptime
    init(from start: Uptime, within: Duration) { deadline = start + within }
    /// The messaging timeout for a call made at `now`; nil once the deadline has passed, so no further call is made.
    func timeout(at now: Uptime) -> Float? { fatalError("not implemented") }
    /// Whether a read that ended at `now` answered in time; a read that did not is `.unanswered`.
    func admits(endedAt now: Uptime) -> Bool { now <= deadline }
}

// WorkspaceActions: frontmostWindows(within:) → windows.readFrontmost(within:);
//                   readWindows(of:within:answer:) → AppWindowReader.readEach(_:within:answer:).
// RawWindow gains `hasFullScreenButton: Bool` (the attribute's value is an element).

// MARK: - LauncherUI

final class SwitcherPresenter {
    /// `reduceMotion` is read at each render (default: the system's setting), injectable for a bench, as `GearView` does.
    init(launcher: Launcher, reduceMotion: @escaping () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion })
    private var laidOutSerial: Int?                 // replaces laidOutRow: a new swipe is a new serial (F37 moot)
    private var stackLayout: WindowStackLayout
    private var shownCopies: [Int] = []             // per slot of laidOutSerial's switcher
}

final class SwitcherPanel: OverlayPanel {
    /// One container layer per slot at (centreX(at:), centreY), holding its copies first and its icon last: copies draw
    /// behind the icon, since sublayers draw above their parent's contents. `show` sets the 1.12 grow on the container
    /// (the same implicit 0.12 s action as today), so the whole stack grows with the icon and shrinks with the row.
    private var slots: [CALayer] = []

    func layoutRow(_ images: [NSImage], layout: SwitcherRowLayout, on screen: NSRect, scale: CGFloat)
    func show(position: CGFloat, selected: Int, animatesSize: Bool)

    /// Inserts `copies` behind the slot's icon, sharing its bitmap, at rest. With `rises` set, each copy's
    /// `position.y` animates from the icon's centre on the render server, using `WindowStackLayout`'s duration, curve
    /// and delay (`beginTime` with backwards fill, so a delayed copy waits hidden behind the icon), keyed "rise". Nothing
    /// else writes a copy's position, and the per-render grow writes the container's transform, so selection moves never
    /// replay or cut the rise (R6). Without `rises`, the copies are in place at once (Reduce motion).
    func addStack(at slot: Int, copies: [WindowStackLayout.Copy], rises: Bool)
}

final class WindowSwitcherPanel: OverlayPanel {
    /// The card in place of the rows: one row's frame of `WindowColumnLayout(rowCount: 1, …)`. The app's icon sits in
    /// the preview slot. The title column holds the bold title (13 pt) and the message (12 pt regular, wrapping onto a
    /// second line, then cut short at its end). The highlight is the card's plate. No capture is started.
    func lay(card: NoWindowsCard, icon: NSImage, layout: WindowColumnLayout, topLeft: NSPoint)
    /// Moves the card (its plate and content) `offset` points down from rest, inside the panel's 8 pt padding. With
    /// `animated` set, a 0.1 s implicit action is used, so the jump through rest at a turn reads as a quick move.
    func moveCard(by offset: Double, animated: Bool)
    /// Back to rest over the dismiss fade's 150 ms on the render server; at once without `animated`. A no-op unless a
    /// card is laid out. Called from `render(nil)` just before `dismiss()`.
    func settleCard(animated: Bool)
}

// MARK: - Tests: the twins and handles (LauncherCoreTests)

// RecordingSystemActions
//   func windows(of app: AppEntry) -> FakeWindows      // one per running location; ids from one shared rising counter
//   var windows: FakeWindows { windows(of: frontmost) } // today's tests keep working
//   var ownApp: AppEntry?                              // a read of it is `.ownProcess` (World.openSettings sets it)
//   private(set) var frontmostDeadlines: [Duration]
//   private(set) var countReads: [CountReadRequest]     // every readWindows call
//   readWindows: snapshots each app's read at the call (the swipe's begin); answers at once unless that app's
//     FakeWindows.holdsCountAnswers; `.unanswered` when it does not answer.
// CountReadRequest
//   let apps: [AppEntry]; let deadline: Duration; let reads: [WindowRead]
//   func answer(_ slot: Int, with read: WindowRead? = nil)   // late: the snapshot; `.unanswered`: missed the deadline
// FakeWindows gains
//   moveToAnotherSpace(_:), returnToThisSpace(_:)            // feeds `elsewhere`
//   var answers: Bool                                        // false: `.unanswered` for both reads
//   var holdsCountAnswers: Bool
// World gains
//   windows(of name:), answerCountReads(of name:, with:), quit(_ name:), relaunchApp(_ name:)  // fresh window numbers
```

**Test seams and handles.**
- **R1–R4** run at `World` through `launcher.switcher.windowCounts`, with the `readWindows` twin and per-app `FakeWindows`. The handles: at once, held then released (a slow app), never released, `.unanswered` (no answer within 0.2 s). Every count stays unknown without the grant. A window opens or closes after the begin. The setting is off. Two copies of one bundle. A full-screen front window. A held answer released after a lift, a cancel, a reconcile or the next swipe must be dropped.
- **R2 and the deadline** also run at platform pure tests: `sort` with the hidden and shown facts from the probes, and `ReadBudget` with a driven clock. Real hung, slow, cold and hidden apps are a manual check against a stopped fixture, as in `probe_budget`.
- **R5–R6** run in pure `WindowStackLayout` tests and in a `SwitcherBench` (in `LauncherUITests`, with Reduce motion injected). The bench checks: one container per slot, with the copies before the icon; the rise animations' keys, begin times and curve; nothing new on a selection move; no animation with Reduce motion.
- **R7–R9** run at `World` through `windowSwitcher.rows` and `.selection`, with `FakeWindows` handles: open, close, minimise, raise (a click), another Space and back, quit and relaunch with fresh numbers, and `relaunch()` of the launcher. They are backed by pure `WindowOrders.updated` tests.
- **R10–R13** run at `World` with the card's kind and copy. A lift on the card makes no `raiseWindows` call and plays no pulse and no hide. A cancel is silent. For no frontmost app and for no answer, the whole outcome is compared with the setting-off world (today's `Outcome` test). Trackpad Launcher frontmost shows the card. Pure `NoWindowsCard.offset` tests: a 40 mm slide gives at most 6 pt, and a turn takes effect at once. A `WindowSwitcherBench` checks the card's offset and settle.

**Tests this design inverts:**
- In `WindowSwipeNeedsTwoWindowsTests`:
  - `aSlideDownIsAWindowSwipeOnlyWhenTheReadListsTwoOrMoreRows`: rows, card or decline; only not answering declines.
  - `withFewerThanTwoWindowsASlideDownBehavesExactlyAsWithTheWindowSwipeOff`: its fronts become no active app and not answering; the one-window, no-windows and full-screen fronts move to the card tests.
  - `aWindowThatOpensMidSlide…`: the card stays a card; the next slide lists Letter, Draft, with Draft selected.
- `SettingsWindowAsAppTests.slidingDownOverTheSettingsWindowIsNoWindowSwipe`: now the one-window card.
- `WindowSwitchingTests.liftingOnAnotherWindowKeepsItInFront…NextWindowSwipeStartsThere`: Docs, Mail, News, with row 2 selected (`G/why.md` Change 2).
- `FrontmostAppWindowsSortTests`: renamed, with `appIsHidden` added.
- The `Confined` entries for the renamed file.

**Docs once this lands.**

`docs/domain-model.md`:
- New entries: *Window stack*, *No-windows card*, *Window order*.
- *Window swipe*: it exists for zero or one window too. It is no window swipe only with no frontmost app, no answer within 0.2 s, the setting off, or no Accessibility.
- *Window switcher*: the app's order, the selection on the front window, two to ten rows or the card, and the card's silent lift.
- *Front window*: not always the first row.
- *Switcher*: stacks.
- *Tap*: the window-swipe clause.
- *Frontmost app*: a slide over Trackpad Launcher shows the card.
- *Feedback*: the card's lift and cancel are silent.

`docs/architecture.md`:
- **Shape**: `Launcher` keeps each app's window order between window swipes, never saved. This reverses 012's "no window state between window swipes".
- **Concurrency**:
  - The frontmost read is held to 0.2 s in all.
  - A swipe reads the row's apps' windows off the main actor, one GCD work item per app. This is named as the exception to the cooperative pool: blocking IPC must not hold a pool thread. Only the reads hop back.
  - A window read's deadline is carried into each call as its messaging timeout and checked on the monotonic clock when the read ends; nothing fires at it. It joins the lift window as a deadline outside Core Animation's clock.
- **Privacy**: Accessibility is also used "to count the windows of the apps in the switcher's row when a swipe begins". The confinement sentence names the app window reader and the launch watch.

### Synthesis decision

### Tradeoffs accepted

- We accept that the first swipe after an app or Trackpad Launcher starts may miss a cold app's stack (cold reads reach 204 ms, F7). In exchange we get a hard 0.2 s bound and no reading of other apps at launch.
- We accept one GCD work item per app read, a named exception to "concurrent work runs on the cooperative pool". In exchange, a hung app delays no other read on any core count.
- We accept a quit app's order lingering, a few window numbers per app and never saved, until that app's next window swipe empties it. In exchange we need no app-quit push and no always-on terminate observer.
- We accept that once every remembered window of an app has closed, its next window swipe starts a fresh order (today's list). By window numbers alone this cannot be told from a relaunch, which R7 requires to start fresh.
- We accept that new windows join in creation order, taken from rising window numbers (probed, F19, not documented).
- We accept one more system-wide window-list copy per read (the full list, about 0.5 ms warm). In exchange we get an exact closed-versus-elsewhere for the order.
- We accept a probed but undocumented signal for hidden apps' document windows, the full-screen button. In exchange, stacks still show with *Hide background apps* on.
- We accept that the card's reach is the switchers' rubber band (a quarter row of travel to the 6 pt cap). In exchange, "turn at once" and "no tick" are one rule shared with both switchers; a factor in `offset(stretch:)` would separate them.
- We accept that a slide under the anchored thumb over a zero- or one-window app no longer scrolls while the setting is on (Change 2, at the human's request).
- We accept renaming `FrontmostAppWindows` to `AppWindowReader` and `WindowStack` to `RaiseOrder`, plus the confinement edit. In exchange, the names say what they own and the glossary word means one thing.

### Alternatives considered

- **Counts kept in `LauncherUI`, like previews.** The UI would gain a shell-injected count reader, because it cannot import Platform, and it would hold all of R2 to R4: whom to read, the permission, the own process, dropping stale answers. That spreads model policy into a view with no model test seam. The deep port call hides that same work behind one member.
- **A model-held deadline** (a clock port plus a "timed out" push, or arrival stamps compared in the model). This makes the interface larger and creates a second copy of the 0.2 s rule, because the adapter must still hold each call to the budget to stop a slow read early. Nothing needs to fire at the deadline: a late app just stays unknown.
- **An order keyed by process, with an app-quit push** (a terminate observer, or a pid in `AppEntry`). Forgetting at quit would be exact, but this adds a push, an observer that runs whenever gestures do, and a process identity in Core. It still cannot tell closed windows from off-Space ones without the full window list, and the full-list prune alone gives both.
- **The order inside the adapter** (the reader returns windows already ordered). The order would be hidden from the model, but then the selection start, the R9 pick and the lift would all depend on adapter state, and the in-memory twin would need a second copy of the order rule. This loses on locality and testability.
- **A dedicated card-offset integrator** (a clamped running sum, continuous through rest at a turn). It would feel smoother at a turn, but it needs its own state and its own turn rule beside the selection's, and "movement since the last change of direction" is literally the one-item selection's rule.

### Open questions and risks

- Does a hidden app's Accessibility window list leave out its windows on other Spaces, as the frontmost app's does (F12 left this unprobed)? Default: hidden apps count by the full-screen-button rule. This needs a manual check, and the branch in `sort` is cheap to remove.
- Is a card for Trackpad Launcher's own settings window right ("No other windows / Trackpad Launcher has no other windows on this desktop.")? The default follows R10, which has no exemption. Declining instead would be one case in `WindowOrders.list`.
- Is a message that wraps onto a second line (12 pt, 200 pt column) acceptable for "two lines of text"? Long app names cannot fit on one line at any reasonable width (open question 7).
- Should a turn on the card jump through rest (the default: the literal "movement since the last change of direction", softened by a 0.1 s implicit action), or glide continuously?
- Should the copies start centred behind the icon (the default) or bottom-aligned with it? Both are hidden at the start; this is one number in `WindowStackLayout`.
- Is it acceptable that background Accessibility reads run concurrently with main-thread raises and with `LaunchWatch`? It was probed (280 reads, no mismatch, F6), but no source states it is safe.
- How do apps that answer the window list with an error other than "cannot complete" (non-AppKit apps that do not implement Accessibility) behave? Under this design they are `.unanswered`: no stack, and no card. Finder with no windows must still read as zero (manual check).
- Two running copies of one bundle at one location would share an order key. This was judged too rare to model.

### Next implementation step

Reshape the read types in `LauncherCore` (`AppWindows`, `WindowRead`, `FrontmostWindows`, `WindowPick`, `windowCount`) and write `WindowOrders.list` test-first, through the inverted `WindowSwipeNeedsTwoWindowsTests` and new order scenarios on a per-app `FakeWindows`.
