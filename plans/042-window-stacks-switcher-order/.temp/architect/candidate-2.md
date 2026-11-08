## Design

### Problem

Three behaviours land on two switchers whose shape assumes the opposite of each: the app switcher's row is final at begin and has no per-swipe identity, yet stacks need up to ten window counts that arrive asynchronously, each within 0.2 s, read off the main actor (the main actor is never blocked by a multi-app read, the frame thread never waits, timers are banned, Accessibility and the window list are confined to two files). The window switcher lists windows in z-order and the lift rule, the haptic and `frontWindow` all assume "row 0 is the front window", yet R7 wants an order the model remembers between swipes, which the model has never done. And the one parse `Content.init?` quietly folds "no app, did not answer, own process, no permission, full-screen front, fewer than two" into one decline, yet R10 to R13 want zero and one window to be a window swipe with a card while a partial or late read still declines exactly as the setting-off slide does. The grounding adds hard facts: window numbers are never reused (F19), an off-Space window vanishes from the Accessibility list but stays in the window server's full list (F21), a hidden app's document windows report `AXDialog` and leave the on-screen list but keep their full-screen button (F12), per-element messaging timeouts cap a call at a remaining budget (F9), and one hung app holds only its own GCD thread (F8).

The shape below puts one window-counting rule in `LauncherCore` that both the stacks and the window switcher consume, one `AppWindowsReader` in `LauncherPlatform` whose single pipeline serves the synchronous frontmost read and the off-main per-app counts, one `WindowOrders` value in the model that owns the order's whole lifecycle, and a `Body` on `WindowSwitcher` that is either rows or the card.

### Usage (caller's view)

**The model, at a swipe's begin.** It builds the row as today, then asks the system to count, and forgets about time.

```swift
// Launcher.swipe(.began)
guard shown == nil, activity.isActive else { return }
let running = runningApps()                       // also prunes orders of apps that quit
serials += 1
guard let switcher = Switcher(frontmost: running.frontmost, running: running.apps,
                              leavingOut: settings.assignedBundleIDs, serial: serials, trackpad: event.trackpad)
else { return }
shown = .apps(switcher)
// R3: nothing is read without Accessibility; the window swipe setting plays no part.
guard isAccessibilityGranted else { return }
system.countWindows(of: switcher.row) { [unowned self] app, read in
    guard case .apps(var open)? = shown, open.serial == switcher.serial else { return }   // ended, cancelled, replaced, next swipe: dropped
    open.learn(read, of: app)                                                             // first answer per app wins; later ones ignored
    shown = .apps(open)
}
```

**The model, at a window swipe's begin.** One synchronous read, held to 0.2 s inside the adapter; one verdict; the confirm stays inside `onEvent`.

```swift
// Launcher.windowSwipe(.began)
guard activity.isActive else { return }
let read = system.frontmostWindows()
guard let body = WindowSwitcher.Body(read, orders: &windowOrders) else { return }   // decline: exactly the setting-off slide
hardware.confirmWindowSwipe(on: event.trackpad)
guard shown == nil else { return }
serials += 1
shown = .windows(WindowSwitcher(app: read.app!, body: body, showsPreviews: isScreenRecordingGranted,
                                serial: serials, trackpad: event.trackpad))

// Launcher.windowSwipe(.ended)
shown = nil
guard case .list = open.body else { return }      // the card: no read, no raise, no haptic, no hide
let lift = open.lift(now: system.frontmostWindows())
...as today
```

**The app switcher's presenter.** It lays out once per serial and plays a rise for each slot whose count has just arrived.

```swift
// SwitcherPresenter.render
if switcher.serial != shownSerial { open(switcher) }                       // shownStacks = all .pending
let stacks = switcher.stacks
for index in stacks.indices where shownStacks[index] == .pending, case .stack(let stack) = stacks[index] {
    panel.showStack(stack, at: index, rise: reduceMotion() ? nil : .shipped)   // once per swipe; selection moves never reach here
}
shownStacks = stacks
panel.show(position:selected:animatesSize:)                                  // the implicit 1.12 grow, now on each slot's container
```

**A test, R4's slow app.** The fake answers Safari inside the call and holds Mail until the test says so.

```swift
let world = World.switcherWorld(apps: ["Safari", "Mail", "Notes"])
world.system.windows.set(visible: ["A", "B"], for: "Safari")
world.system.windows.set(visible: ["C", "D"], for: "Mail", answering: .held)
world.swipe(3.5, lift: false)
#expect(world.launcher.switcher?.stacks == [.stack(WindowStack(icons: 2)), .pending, .alone])
world.system.windows.answer("Mail")                 // 150 ms later, in the story
#expect(world.launcher.switcher?.stacks[1] == .stack(WindowStack(icons: 2)))
world.system.windows.giveUp("Mail")                 // a second report: ignored, the count holds for the swipe
```

### Shape

**Data first.** One read of one app's windows is `AppWindows` (visible front to back, minimised in app order, and `elsewhere`: the window server's other numbers for the app, so an off-Space window is known to be open without being listed). A read's outcome is `WindowRead`: `.listed(AppWindows)`, `.unanswered` (a timeout, a partial list, an immediate cannot-complete: the three cases R13 declines), `.ownProcess`. `WindowListing(AppWindows)` is **the one rule for what the window switcher would list**: a full-screen front window is the only window, other full-screen windows are left out, and `count` is what a stack shows; both the stacks (`WindowStack(windows: listing.count)`) and the window switcher (`Body(read)`) consume it, so R2 holds by construction (per model-the-domain). `WindowStack` is 2 to 4 icons by construction (nil below two, capped in `init`), so a view cannot draw a wrong stack (per type-system-discipline). The order is `WindowOrders`, one struct the model holds: `[URL: [WindowID]]`, whose only mutation is `reconcile(app, with: AppWindows)`: prune ids the window server no longer knows (closed, or gone with a relaunch: numbers are never reused, F19), set today's list when empty (first swipe, relaunch), append new ids at the end; nothing else touches it. The selection start is a `SwitcherSelection(count:startingAt:)` initialiser, since `follow` works on deltas. `WindowSwitcher.Body` is `.list(WindowList)` or `.card(NoWindowsCard)`; the list keeps `visibleFrontToBack` (the begin z-order) apart from the rows (the display order), which is what lets `lift(now:)` restate today's rule unchanged against a reordered list. The card's offset is a pure function of the one-item selection's clamped travel, so R11's turn-at-once comes from `follow` for free and the 6 pt cap is one constant.

**Flow.** Swipe begin: the model builds `Switcher` (now with a `serial` and `stacks: [SlotStack]` beside the fixed row) and calls `SystemActions.countWindows(of:then:)`. `WorkspaceActions` resolves each entry to a running process by bundle id plus location (two copies of one bundle are two entries with two locations, so no collision), reports `.ownProcess` for itself at once, and hands the rest to `AppWindowsReader.count`, which runs **one dispatch block per app** so a hung app holds only its own thread (F8; a cooperative-pool group would queue behind hung apps on small machines), each block running the one pipeline `collect(pid:isHidden:budget:)`. **The deadline lives in the adapter and is the Accessibility call itself**: before every call the element's messaging timeout is set to what remains of 0.2 s on the process's monotonic clock (F9); a spent budget, a cannot-complete or a partial loop all come out `.unanswered`. No timer, no clock in the model, nothing can arrive after the budget. Each block hops its `WindowRead` to the main actor; the model's closure drops anything for a swipe that is not the one shown (per make-operations-idempotent). The same pipeline, run on the main actor with the same budget, is the frontmost read: it keeps the raise handles and bounds the main actor at about 0.2 s worst case, which today's slow-app path did not (F8: up to (1 + 2N) × 0.2 s). Hidden apps (open question 1, settled): with `isHidden`, `sort` counts an `AXWindow` as a document window when its subrole is standard **or it has a full-screen button** (F12, the one probed signal), in Accessibility order; the frontmost app is never hidden, so the window switcher's rows are untouched. Window swipe begin: `Body(read, orders:)` decides rows, card or decline inside `onEvent`; a decline is `return` before `confirm`, exactly the setting-off slide (Preserve 3). Trackpad Launcher frontmost (open question 4, settled): `.ownProcess` reads as one window and shows the card, like any app. The lift raises only ids the second read listed (`AppWindows.listed`, never `elsewhere`), so Preserve 1 holds in the type: an off-Space id can be in the order but never in a row, a target or a raise.

**Rendering.** `SwitcherPanel` gets one container layer per slot (position at the slot's centre, the selection transform on it) holding the copies then the front icon last, so copies draw behind, grow with the selection and shrink with the row; `StackLayout` gives each copy's scale and centre rise purely (6 pt peek per layer at the icon's top edge, 92/84/76 %). `showStack(at:rise:)` adds the copies at the front icon's height with the model value already at rest and plays `StackRise`'s keyframes on `position.y` with a staggered `beginTime`, keyed `"rise"`; it leaves nothing behind, and the per-render implicit action is on the container's `transform`, a different layer and key, so selection moves never touch it. `WindowSwitcherPanel` gains a `NoWindowsCardView` (icon slot as a row's, bold title, two-line regular message) and `showCard(offset:)` sets its position with actions disabled per render; `render(nil)` animates it back over the dismiss fade. Reduce motion is injected into both presenters (the `GearView` precedent) so a bench can check the rise, its absence, and the card's stillness.

**Depth.** The public surface grows by one port member (`countWindows`), one read shape (`WindowRead`/`AppWindows`), one `Body`, one `stacks` array and one `serial`. Behind it: pid resolution, hidden detection, concurrency, the budget, the parse, the count rule, the order's lifecycle, the selection start, the pick of ten, the lift against a reordered list, the geometry and the curves. What stays exposed is only what a view must draw. The adapter never sees `WindowStack`, the model never sees a pid or a clock, the view never sees a read.

**Module map.** `LauncherCore`: `AppWindows`, `WindowRead`, `FrontmostWindows` (reshaped), `WindowListing`, `WindowStack`, `SlotStack`, `Switcher` (+`serial`, `stacks`, `learn`), `StackLayout`, `StackRise`, `WindowOrders`, `WindowSwitcher.Body`, `NoWindowsCard`, `SwitcherSelection(count:startingAt:)`, `WindowRaises` (the renamed `WindowStack` enum, since the glossary now uses that name), `Copy` additions, `SystemActions.countWindows`, `Launcher` deltas. `LauncherPlatform`: `AppWindowsReader` (replaces `FrontmostAppWindows` in the same confined file), `WorkspaceActions.countWindows`. `LauncherUI`: `SwitcherPresenter`, `SwitcherPanel` (slot containers, `showStack`), `WindowSwitcherPresenter`, `WindowSwitcherPanel` (+`NoWindowsCardView`, `showCard`), both presenters take a `reduceMotion` reader. Tests: `FakeWindows` becomes per-app with held answers, Spaces and quits; `RecordingSystemActions.countWindows`; `SwitcherBench` and `WindowSwitcherBench` in `LauncherUITests`.

```swift
// MARK: LauncherCore: the read and the one listing rule

/// One app's windows as one read found them. Visible: on the current Space, front to back, helpers left out.
/// Minimised: in the app's order. `elsewhere`: the other windows the window server still holds for the app (on other
/// Spaces, full-screen siblings, helpers): open, so they keep their place in the app's window order, but never listed and
/// never raised.
public struct AppWindows: Equatable, Sendable {
    public let visible: [AppWindow]
    public let minimised: [AppWindow]
    public let elsewhere: Set<WindowID>
    /// What a raise may name: visible and minimised, never `elsewhere`.
    public var listed: Set<WindowID> { fatalError("not implemented") }
    /// Every window the app still has, whatever its Space: what the window order keeps.
    public var known: Set<WindowID> { fatalError("not implemented") }
}

/// The outcome of reading one app.
public enum WindowRead: Equatable, Sendable {
    case listed(AppWindows)
    /// Not within 0.2 s, a partial list, or an immediate refusal: R13 declines, R1 shows the icon alone.
    case unanswered
    /// Trackpad Launcher itself, never read: its settings window is its one window.
    case ownProcess
}

/// The frontmost app's read.
public enum FrontmostWindows: Equatable, Sendable {
    case noApp
    case app(AppEntry, WindowRead)
    public var app: AppEntry? { fatalError("not implemented") }
}

/// What the window switcher lists for an app, from one read: the one rule for the stacks and the rows (R2).
/// A full-screen front window is the only window; other full-screen windows are left out; nothing is cut yet.
public struct WindowListing: Equatable, Sendable {
    public let front: AppWindow?          // nil when every window is minimised
    public let others: [AppWindow]        // visible behind the front, front to back
    public let minimised: [AppWindow]
    public init(_ windows: AppWindows) { fatalError("not implemented") }
    public var count: Int { fatalError("not implemented") }
    /// Visible front to back: the begin z-order the lift restores.
    public var visibleFrontToBack: [WindowID] { fatalError("not implemented") }
    /// R9: the ten by today's rule: the front window, the other visible ones front to back, then minimised ones.
    public func pick(_ limit: Int = GestureRules.windowSwitcherMaxRows) -> [AppWindow] { fatalError("not implemented") }
}

// MARK: LauncherCore: the stacks

/// A window stack: 2 to 4 icons, one per window up to the cap. nil below two windows.
public struct WindowStack: Equatable, Sendable {
    public static let maxIcons = 4
    public let icons: Int
    public init?(windows: Int) { fatalError("not implemented") }   // nil when windows < 2; icons = min(windows, 4)
    public var copies: Int { icons - 1 }
}

/// One slot's stack as the swipe knows it. `.pending` until its app answers; fixed once it has.
public enum SlotStack: Equatable, Sendable {
    case pending
    /// Zero or one window, the own process, or no answer within 0.2 s.
    case alone
    case stack(WindowStack)
    /// From a read: `.listed` counts through `WindowListing`; `.unanswered` and `.ownProcess` are `.alone`.
    init(_ read: WindowRead) { fatalError("not implemented") }
}

public struct Switcher: Equatable, Sendable {
    public let row: [AppEntry]
    /// One per row slot. Every slot starts `.pending`; `learn` fills a slot once.
    public private(set) var stacks: [SlotStack]
    /// The switchers shown since launch: tells one swipe's switcher from the next, so the presenter lays out once per
    /// swipe and a count for one swipe never shows in another.
    public let serial: Int
    public package(set) var selection: SwitcherSelection
    public let trackpad: TrackpadID
    package init?(frontmost: AppEntry?, running: [AppEntry], leavingOut: Set<BundleID>, serial: Int, trackpad: TrackpadID) {
        fatalError("not implemented")
    }
    /// The slot whose app is at `app.url` takes `read`, if it is still `.pending`. A second report, or one for an app not
    /// in the row, changes nothing: counts are read once per swipe and hold.
    package mutating func learn(_ read: WindowRead, of app: AppEntry) { fatalError("not implemented") }
}

/// Where a stack's copies sit behind the front icon, at rest, in a row drawn at `scale`: the nearest copy first. A copy
/// `k` layers back is `copyScales[k]` of the icon and its top edge peeks `fullPeek × (k + 1) × scale` above the icon's.
public struct StackLayout: Equatable, Sendable {
    public static let copyScales = [0.92, 0.84, 0.76]
    public static let fullPeek = 6.0
    public struct Copy: Equatable, Sendable {
        /// Side as a share of the icon's side.
        public let scale: Double
        /// How far above the front icon's centre this copy's centre sits, in points at the row's scale:
        /// peek + (iconSide − copySide) / 2.
        public let centreRise: Double
    }
    public let copies: [Copy]
    public init(_ stack: WindowStack, scale: Double) { fatalError("not implemented") }
}

/// The rise: each copy starts at the front icon's height and reaches its place over `duration` with a soft ease-out
/// (1 − (1 − p)³), copy `k` starting `k × stagger` later. Once per swipe; in place at once with Reduce motion.
public struct StackRise: Equatable, Sendable {
    public var duration = 0.3
    public var stagger = 0.04
    public static let shipped = StackRise()
    /// Share of the rise reached `t` seconds after the stack appears by the copy `index` layers back; 0 before its start.
    public func progress(of index: Int, at t: Double) -> Double { fatalError("not implemented") }
    /// Sampled for Core Animation, as `PickAnimation.keyframes`: key times and shares, for one copy.
    public func keyframes(of index: Int, perSecond: Double) -> (keyTimes: [Double], shares: [Double]) {
        fatalError("not implemented")
    }
    public func totalDuration(copies: Int) -> Double { fatalError("not implemented") }
}

// MARK: LauncherCore: the window order

/// Every running app's window order, by the app's location, held for as long as Trackpad Launcher runs. Set by the
/// first window swipe into an app as today's list; afterwards only `reconcile` changes it: a window the window server
/// no longer knows leaves (closed, or gone with a relaunch: numbers are never reused), a new one joins at the end, and
/// an order that emptied starts again as today's list. Never saved. Memory is bounded by `retain`, which forgets apps
/// that no longer run, and by the pruning at every reconcile.
public struct WindowOrders: Equatable, Sendable {
    private var orders: [URL: [WindowID]] = [:]
    public init() {}
    /// The app's order after this read: pruned to `windows.known`; set to visible then minimised when empty; new visible
    /// windows appended back to front (the newest, which is in front, last), then new minimised ones in app order.
    public mutating func reconcile(_ app: AppEntry, with windows: AppWindows) -> [WindowID] { fatalError("not implemented") }
    /// Forgets every app `running` does not contain. Called with each running-apps read the model makes.
    public mutating func retain(_ running: RunningApps) { fatalError("not implemented") }
}

extension SwitcherSelection {
    /// Starts on item `start` (clamped): travel `start × 12` with nothing reported yet, so `follow` moves from there.
    package init(count: Int, startingAt start: Int) { fatalError("not implemented") }
}

// MARK: LauncherCore: the window switcher's body, the card, the lift

public struct WindowSwitcher: Equatable, Sendable {
    /// Two to ten rows in the app's window order, or the card.
    public enum Body: Equatable, Sendable {
        case list(WindowList)
        case card(NoWindowsCard)
    }

    /// The rows, top to bottom, in the app's window order, from the R9 pick; and the begin z-order for the lift.
    public struct WindowList: Equatable, Sendable {
        public let rows: [Row]
        /// The picked visible windows, front to back, as the window swipe began. The front window is its first.
        public let visibleFrontToBack: [WindowID]
        public var frontWindow: WindowID? { visibleFrontToBack.first }
        /// The front window's row; 0 when every row is minimised (R8).
        public var startRow: Int { fatalError("not implemented") }
    }

    public let app: AppEntry
    public let body: Body
    public package(set) var selection: SwitcherSelection
    public let serial: Int
    public let trackpad: TrackpadID
    public let showsPreviews: Bool

    /// A list's selection counts its rows and starts on `startRow`; a card's is a one-item selection, which rubber-bands
    /// at both ends and never crosses an item, so no light tick ever plays for it.
    package init(app: AppEntry, body: Body, showsPreviews: Bool, serial: Int, trackpad: TrackpadID) {
        fatalError("not implemented")
    }

    /// Empty for the card.
    public var rows: [Row] { fatalError("not implemented") }
    public var previewWindows: [WindowID] { fatalError("not implemented") }   // [] for the card
    public var frontWindow: WindowID? { fatalError("not implemented") }
    public var selectedVisibleWindow: WindowID? { fatalError("not implemented") }
    /// The card's offset now, in points, positive downwards: `NoWindowsCard.offset(travelMM:)` of the selection's
    /// travel. 0 for a list.
    public var cardOffset: Double { fatalError("not implemented") }
}

extension WindowSwitcher.Body {
    /// The one parse from the frontmost read to what the window swipe shows, and so whether the slide is a window
    /// swipe at all. nil declines: no app, or no answer within 0.2 s (a partial read included). `.ownProcess` is one
    /// window. Otherwise `WindowListing` counts: 0 → `.card(.noOpenWindows)`, 1 → `.card(.noOtherWindows)`, else the
    /// R9 pick, listed in the app's order after `orders.reconcile`. Rows are titled as today (`Copy.untitledWindow`,
    /// `WindowTitleRule`) by their 1-based row.
    package init?(_ read: FrontmostWindows, orders: inout WindowOrders) { fatalError("not implemented") }
}

/// The window switcher's single card for an app with zero or one window.
public struct NoWindowsCard: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case noOtherWindows, noOpenWindows }
    public let kind: Kind
    /// Bold: "No other windows" / "No open windows".
    public var title: String { fatalError("not implemented") }
    /// Regular: "‹App› has no other windows on this desktop." / "‹App› has no windows on this desktop."
    public func message(appName: String) -> String { fatalError("not implemented") }

    /// How far the card sits from rest, in points, positive downwards. `travelMM` is the one-item selection's travel:
    /// movement since the last change of direction, already clamped to ±`switcherMaxOvershoot` steps by `follow`.
    /// Damped and clamped: sign × cap × (1 − (1 − min(|t| / band, 1))²), reaching `cap` at the band's edge.
    public static let cap = 6.0
    public static func offset(travelMM: Double) -> Double { fatalError("not implemented") }
}

extension Copy {
    public static let noOtherWindowsTitle = "No other windows"
    public static let noOpenWindowsTitle = "No open windows"
    public static func noOtherWindows(_ appName: String) -> String { fatalError("not implemented") }
    public static func noWindows(_ appName: String) -> String { fatalError("not implemented") }
}

/// Renamed from `WindowStack`: the glossary's window stack is now the icons behind an app's icon. Body unchanged.
public enum WindowRaises {
    public static func raises(current: [WindowID], target: [WindowID]) -> [WindowID] { fatalError("not implemented") }
}

extension WindowSwitcher {
    /// Only for a list; `.nothing` for the card. As today, against the list: `now` not this app, or unanswered: nothing.
    /// Selected closed: no raises, haptic iff a window is in front now and it is not `frontWindow`. Otherwise the target
    /// is the selected window, then `visibleFrontToBack` without it, minus any `now` does not list (`AppWindows.listed`,
    /// never `elsewhere`); haptic iff selected != frontWindow. Lifting on the front window, wherever its row, restores
    /// the begin z-order silently.
    public func lift(now: FrontmostWindows) -> WindowLift { fatalError("not implemented") }
}

// MARK: LauncherCore: the port and the model

@MainActor public protocol SystemActions: AnyObject {
    // ...as today, plus:

    /// Counts the windows of `apps` for the switcher's stacks, away from the main actor, each app on its own so a slow
    /// or hung one delays no other. Returns at once. Calls `report` on the main actor at most once per app, inside this
    /// call or later, within about 0.2 s of it: `.listed` when the app answered in time, `.unanswered` when it did not
    /// (a partial answer included), `.ownProcess` for Trackpad Launcher. An app no longer running is `.unanswered`.
    /// Reads only; never touches the handles `raiseWindows` uses. Needs Accessibility; the caller checks.
    func countWindows(of apps: [AppEntry], then report: @escaping @MainActor (AppEntry, WindowRead) -> Void)

    /// The frontmost app's windows, read now on the main actor and held to 0.2 s in all: the only windows a later
    /// `raiseWindows` may name, until the next read. `.app(_, .unanswered)` when it did not finish in time.
    func frontmostWindows() -> FrontmostWindows
}

@MainActor @Observable public final class Launcher {
    // ...as today, plus:
    /// One counter for both switchers' serials.
    @ObservationIgnored private var serials = 0
    /// The one thing the model keeps from a window read between window swipes.
    @ObservationIgnored private var windowOrders = WindowOrders()

    /// Every running-apps read the model makes, so orders of apps that quit are forgotten wherever the read happens.
    private func runningApps() -> RunningApps { fatalError("not implemented") }   // let r = system.runningApps(); windowOrders.retain(r); return r

    private func swipe(_ event: SwipeEvent) {
        // .began: as Usage. .moved/.ended/.cancelled: as today.
        fatalError("not implemented")
    }

    private func windowSwipe(_ event: SwipeEvent) {
        // .began: as Usage. .moved: as today (crossed is 0 for a card, so no tick and no raise).
        // .ended: shown = nil; card → return (R12: no read, no raise, no haptic, no hide); list → as today.
        // .cancelled: shown = nil.
        fatalError("not implemented")
    }
}

// MARK: LauncherPlatform

/// Replaces `FrontmostAppWindows` in its confined file: one pipeline over the Accessibility element API and the window
/// list that reads any app's windows within a budget. On the main actor it reads the frontmost app and keeps its raise
/// handles; off it, one dispatch block per app, it counts for the stacks and keeps nothing.
@MainActor final class AppWindowsReader {
    /// The whole of one app's read, every call included.
    static let budget = Duration.milliseconds(200)
    static let processWideTimeout: Float = 0.2   // the default for every element, as today; LaunchWatch sets its own

    private var listed: [WindowID: AXUIElement] = [:]
    private var isUnanswering = false

    init() { fatalError("not implemented") }   // as today: process-wide timeout, dlsym, warm the window list off main

    /// The frontmost app, on the main actor, within `budget`. Replaces the raise handles.
    func readFrontmost() -> FrontmostWindows { fatalError("not implemented") }

    func raise(_ frontToBack: [WindowID]) { fatalError("not implemented") }   // as today

    /// One global-queue block per process; each hops its `WindowRead` to the main actor through `report`. Elements made
    /// in a block die in it: only the Sendable read crosses.
    nonisolated func count(_ processes: [(app: AppEntry, pid: pid_t, isHidden: Bool)],
                           report: @escaping @MainActor (AppEntry, WindowRead) -> Void) {
        // TODO: for each: DispatchQueue.global(qos: .userInteractive).async {
        //   let read = Self.collect(pid:, isHidden:, budget: Self.budget, now: { Uptime.now }).read
        //   DispatchQueue.main.async { MainActor.assumeIsolated { report(app, read) } } }
        fatalError("not implemented")
    }

    /// What one read keeps: the outcome, and the elements by number for the main-actor caller.
    struct Collected { let read: WindowRead; let elements: [WindowID: AXUIElement] }

    /// The pipeline both paths share. Before every call into the app the element's messaging timeout is set to what
    /// remains of `budget` on the process clock (`remaining`), so the read returns within the budget or as `.unanswered`:
    /// a cannot-complete, a spent budget mid-loop, or any window left unread is `.unanswered`, never a partial list.
    /// Then one window-list copy (`optionAll`, this pid, layer 0: `isOnScreen` orders the visible, the rest is
    /// `elsewhere`) and `sort`.
    nonisolated static func collect(pid: pid_t, isHidden: Bool, budget: Duration, now: () -> Uptime) -> Collected {
        fatalError("not implemented")
    }

    /// The timeout for the next call: `budget` less what has passed since `started`; nil once spent. Pure, tested.
    nonisolated static func remaining(of budget: Duration, started: Uptime, now: Uptime) -> Float? {
        fatalError("not implemented")
    }

    /// Which windows are listed and how. Shown app: as today (standard subrole, not minimised, on screen, in the
    /// window list's order). Hidden app (F12): a document window is an `AXWindow` whose subrole is standard or which has
    /// a full-screen button, not minimised, in the app's order, since none is on screen. Minimised: the flag alone.
    /// Every other numbered window is `elsewhere`. Pure, tested over probe facts.
    nonisolated static func sort(_ windows: [RawWindow], onScreen: [UInt32], known: Set<UInt32>, isHidden: Bool)
        -> AppWindows { fatalError("not implemented") }
}

struct RawWindow: Sendable {
    // ...as today, plus:
    let hasFullScreenButton: Bool   // "AXFullScreenButton" joins the one multi-attribute call
}

struct ListedWindow: Sendable {
    // ...as today, plus:
    let isOnScreen: Bool            // kCGWindowIsOnscreen: one optionAll copy gives order and existence
}

extension WorkspaceActions {
    /// Resolves each entry to its running process by bundle identifier and location (so two copies of one bundle stay
    /// apart), reports `.ownProcess` for this process and `.unanswered` for an entry no process matches at once, and
    /// hands the rest to the reader with their hidden state.
    public func countWindows(of apps: [AppEntry], then report: @escaping @MainActor (AppEntry, WindowRead) -> Void) {
        fatalError("not implemented")
    }
}

// MARK: LauncherUI

final class SwitcherPresenter {
    /// Injected so a bench can play the rise or hold it still; the shell passes the live read.
    init(launcher: Launcher, reduceMotion: @escaping () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion })
    private var shownSerial: Int?            // replaces `laidOutRow`
    private var shownStacks: [SlotStack] = []
    private func render(_ switcher: Switcher?)   // as Usage; nil dismisses
}

final class SwitcherPanel: OverlayPanel {
    /// One container per slot, positioned at (centreX, centreY), its sublayers the copies then the front icon last; the
    /// selection transform (the implicit 0.12 s grow) goes on the container, so a stack grows and shrinks as one.
    func layoutRow(_ images: [NSImage], layout: SwitcherRowLayout, on screen: NSRect, scale: CGFloat)
    /// Adds `StackLayout(stack, scale: layout.scale)`'s copies behind slot `index`'s icon, each sharing the icon's
    /// image, at rest with actions disabled. With `rise`, each copy also gets a keyframe animation on `position.y`
    /// from the icon's centre to its rest, `StackRise.keyframes`, `beginTime` staggered, `fillMode = .backwards`,
    /// keyed "rise"; it is removed on completion and leaves nothing behind, since the model value is already at rest.
    func showStack(_ stack: WindowStack, at index: Int, rise: StackRise?)
    func show(position: CGFloat, selected: Int, animatesSize: Bool)   // transforms the containers, as it did the icons
}

final class WindowSwitcherPresenter {
    init(launcher: Launcher, reduceMotion: @escaping () -> Bool = { ... })
    // render: a new serial lays out `.list` as today or `.card` through `panel.layCard`; every render then either
    // `show(position:selected:)` for a list or `showCard(offset: reduceMotion() ? 0 : switcher.cardOffset)` for a card;
    // render(nil) with a card shown first `panel.settleCard()` then `dismiss()`.
}

final class WindowSwitcherPanel: OverlayPanel {
    /// The card in a one-row panel (`WindowColumnLayout(rowCount: 1, …)`): the icon centred in a row's preview slot,
    /// the bold title and the regular message in the title column, the message on up to two lines, cut short at the
    /// end. Rows hidden, highlight hidden, no previews awaited.
    func layCard(_ card: NoWindowsCard, appName: String, icon: NSImage, layout: WindowColumnLayout, topLeft: NSPoint)
    /// The card's position, `offset` points below its resting place, set with actions disabled per render.
    func showCard(offset: Double)
    /// Back to rest over the dismiss fade's 150 ms (at once under Reduce motion), beside `dismiss()`.
    func settleCard()
}

// MARK: Tests (LauncherCoreTests)

/// Per-app windows, by the app's location; one fixed, never reused `WindowID` per (app generation, name).
@MainActor final class FakeWindows {
    enum Answering { case now, held, never }
    /// `otherSpace`: open but on another Space, so known and never listed.
    func set(visible: [String], minimised: [String] = [], otherSpace: [String] = [], fullScreenFront: Bool = false,
             untitled: Set<String> = [], answering: Answering = .now, for app: String)
    func open(_ title: String, in app: String); func close(_:in:); func minimise(_:in:); func restore(_:in:)
    func moveToOtherSpace(_:in:); func moveBack(_:in:)
    /// The app quits: its windows and their numbers are gone; a later `set` for it mints new numbers.
    func quit(_ app: String)
    /// A held app answers now with its windows as they are; `giveUp` answers `.unanswered`. Either is a no-op for an
    /// app without a pending report.
    func answer(_ app: String); func giveUp(_ app: String)
    /// Trackpad Launcher's own entry reads `.ownProcess`.
    var ownApp: AppEntry?
    private(set) var reads: Int, raised: [[WindowID]], countRequests: [[AppEntry]]
    func read(frontmost: AppEntry?) -> FrontmostWindows
    func count(_ apps: [AppEntry], report: @escaping @MainActor (AppEntry, WindowRead) -> Void)   // .now inline, .held stored, .never nothing
    func raise(_ frontToBack: [WindowID])
}
```

**Tests and seams.** R1 to R4 run at `World` → `launcher.switcher` (`stacks`, `serial`) with `FakeWindows` per app: `.now` answers inside the call (the stack on the begin frame), `.held` plus `answer` is the slow app, `.never` or `giveUp` the unanswering one, `answer` after `lift` the dropped late one, `open` mid-swipe the fixed count; `countRequests.isEmpty` without Accessibility (R3). The adapter's budget rule and `sort` with `isHidden` are pure statics in `LauncherPlatformTests` over probe facts; the real deadline against hung apps stays a manual check as 012 chose. R5 and R6: `StackLayout`, `StackRise` pure; a `SwitcherBench` drives `SwitcherPanel` with `reduceMotion` injected and reads `animation(forKey: "rise")` per copy (present once after `showStack`, absent after `show`, absent with Reduce motion), and the containers' transforms. R7 to R9: `WindowOrders.reconcile` pure (open, close, minimise, Space move and back, quit via `known` emptying), and `World.windowWorld` scenarios through `windowSwitcher?.rows` and `selection.selected` with `quit`, `moveToOtherSpace`, `relaunch`. R10 to R13: `World` with 0 or 1 window: `windowSwipeAnswers == [true]`, `body == .card`, lift with `raised.isEmpty`, `feedback.isEmpty`, `hidesOthers.isEmpty`; `.never`, `.noApp` and no Accessibility still equal the setting-off world; `NoWindowsCard.offset` pure; a `WindowSwitcherBench` checks the card's position per `showCard` and its stillness under Reduce motion. Inverted: `WindowSwipeNeedsTwoWindowsTests` (the 0, 1 and full-screen listings now show a card; the setting-off comparison keeps `.noActiveApp` and gains `.notAnswering`), `SettingsWindowAsAppTests.slidingDownOverTheSettingsWindowIsNoWindowSwipe` (a card for Trackpad Launcher), `WindowSwitchingTests.liftingOnAnotherWindow…` (rows stay, `selected == 2`), `WindowSwitcherOnScreenTests` begin test (`selected == startRow`), `aWindowThatOpensMidSlide…` (a card, then rows), and every `raised.count == 1` on an empty lift stays for lists only.

**Docs.** `docs/domain-model.md`: the plan's terms, plus *window order* (set by the first window swipe, kept until the app quits or Trackpad Launcher stops, never saved; an off-Space window keeps its place), *frontmost app* (Trackpad Launcher frontmost shows the card), *feedback* (a lift on the card is silent). `docs/architecture.md` Shape: `Launcher` keeps each running app's window order between window swipes, the one thing it holds from a read. Concurrency: a swipe's begin counts the row's apps' windows off the main actor, one dispatch block per app, through the Accessibility API, and only each app's `WindowRead` hops back; every read, the frontmost one on the main actor included, is held to 0.2 s by setting each call's messaging timeout to what remains of the budget on the process's monotonic clock, the second stamp-and-compare deadline beside the lift window. Privacy: Accessibility is also used "to count the windows of the apps in the switcher's row when a swipe begins"; "the Accessibility element API with the window list to two (the switchers' window read and the launch watch)".

### Synthesis decision

### Tradeoffs accepted

- We accept that the 0.2 s budget lives in the adapter as messaging timeouts plus a monotonic-clock stamp, in exchange for a model with no clock, no timer anywhere, and a fake that delivers answers inline; the architecture doc names it as the second stamp-and-compare deadline beside the lift window.
- We accept one dispatch block per app (over a `@concurrent` task group) in exchange for a hung app holding only its own thread, which is what R4 promises on a Mac with fewer cores than row apps; the doc's "explicitly concurrent functions" sentence gains this case.
- We accept that a partial frontmost read is `.unanswered`, which also makes the lift's second read `.nothing` (silent, no raises) where today it would raise from a partial list, in exchange for R13 holding and one outcome mapping.
- We accept counting a hidden app's document windows by subrole-or-full-screen-button in Accessibility order, with no Space test, in exchange for stacks that exist at all under *Hide background apps*; the rule is one branch of one pure `sort`.
- We accept a per-app order that can drift from the user's sense of the windows (clicks and ⌘` never reorder it) because R7 asks for exactly that, and we accept the first swipe after a cold start missing stacks for apps whose first Accessibility read costs over 0.2 s (F7), rather than warming Accessibility at launch.
- We accept renaming the `WindowStack` enum to `WindowRaises` so the glossary's new term has one meaning in code.
- We accept storing `elsewhere` in every `AppWindows` though only the frontmost read uses it, in exchange for one read shape and one window-list copy per read.

### Alternatives considered

- **Counts kept in `LauncherUI`, as previews are.** The presenter would run the reads and the model would never know. Hides the arrival from the model, but exposes Accessibility, pids and the 0.2 s rule to the shell, puts the one count rule beside the window switcher's in two modules, and leaves R3's "nothing is read without Accessibility" and R4's scenarios without a `swift test` seam. Lost on depth and testability.
- **A pid on `AppEntry`.** Would let the model name processes and the adapter skip resolution. Exposes process identity to every caller of a type that is about bundles on disk, and the model needs none of it. The adapter resolves by bundle id and location instead, as `AppIcons` already does.
- **Never prune the order, let absent ids ride.** Scenarios pass observably except the relaunch, which lists the new windows in append order instead of today's list, and memory grows with every closed window. `known` from one `optionAll` copy costs nothing extra and makes relaunch and off-Space one rule.
- **A `LaunchClock` deadline per swipe that drops late counts.** Honest about Core Animation's clock, but it adds a window per swipe and a second mechanism beside the messaging timeout that already bounds the call; a late count then has two gates. The per-element budget alone cannot let a late answer through, so one gate suffices.
- **A `Content` with an optional row count that the view interprets as the card.** Keeps the type but admits a one-row "list"; `Body` makes the card unrepresentable as rows, so the lift and the capture cannot reach it.

### Open questions and risks

- Default taken: Trackpad Launcher frontmost shows the card ("Trackpad Launcher has no other windows on this desktop."). Should it decline instead, as 021 and 025 chose? One case in `Body.init?`.
- Default taken: new windows join the order back to front (the newest, in front, last). Should two windows opened between swipes join front first? One line in `reconcile`.
- Risk: whether a hidden app's Accessibility list omits its other-Space windows (F12 notes it is unprobed); if not, a hidden app's stack can over-count. Would a probe before S1 be worth it?
- Risk: setting per-element messaging timeouts from a non-main thread is probed only on the main thread (F9) while concurrent reads were probed under the process-wide timeout (F6). Should the first slice probe the combination?
- Default taken: the card's message wraps to two lines in the 200 pt title column beside a full-width icon slot. Should the card use a narrower slot so most messages fit one line?
- Default taken: the card's offset is `6 × (1 − (1 − |t| / 3)²)` of the clamped travel, so it reaches the cap at the band's edge; in cursor travel that is about 25 cursor points for 6 pt. Feel to check by hand, one constant to change.
- Risk: the first and last slots' copies pass within a few points of the radius-34 corner clip when selected (F34, on paper). Check on screen in S2; the fix would be a smaller top layer or a touch less peek.
- Should `retain(running:)` stay, given `known`-pruning alone carries every scenario and it only bounds memory for apps that quit and never relaunch?

### Next implementation step

Add `AppWindows`, `WindowRead`, the reshaped `FrontmostWindows` and `WindowListing` to `LauncherCore`, make `AppWindowsReader.collect` and `sort(…, known:, isHidden:)` produce them with the budget rule, and move `FakeWindows` to per-app windows, so every later slice builds on the one read shape.
