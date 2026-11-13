import AppKit
import ApplicationServices
import LauncherCore
import Synchronization

/// Places a split gesture's front windows in the halves of a display's usable area, and raises the second app's: the
/// one file that sets a window's attributes (position, size, full screen) or raises it for a split, through the
/// Accessibility element API.
///
/// Each placing is one GCD work item, never the cooperative pool, so a call into an app that does not answer blocks
/// only its own thread. One process's work items run in order on a serial queue of that process; different apps run in
/// parallel. A newer placing of the same process stops an older one before its next call. No element leaves a work
/// item and nothing hops back to the main actor: no outcome ever leaves this file.
@MainActor final class FrontWindowPlacer {
    nonisolated static let budget = Duration.milliseconds(500)

    /// Per process, behind one `Mutex`: the latest ticket, written on the main actor; and the half and frame its last
    /// completed placing left, written by that process's work items, which run one at a time.
    private let tickets = PlacingTickets()
    private let concurrent = DispatchQueue(label: "launcher.window-placing", qos: .userInitiated, attributes: .concurrent)
    private var queues: [pid_t: DispatchQueue] = [:]

    private let screens: @MainActor () -> PlacingScreens
    private let process: @MainActor (BundleID) -> pid_t?
    private let now: @Sendable () -> Uptime
    private let perform: @Sendable (pid_t, SplitHalves, SplitSide, CGRect?, ReadBudget, () -> Bool) -> Outcome
    private let raiseWindow: @Sendable (pid_t, ReadBudget) -> Outcome
    private let finished: @Sendable (BundleID, Outcome) -> Void

    /// The real placer: `AXPlacingCalls`, the screens from `NSScreen`, the running copy from `NSRunningApplication`.
    convenience init() {
        self.init(
            calls: AXPlacingCalls(),
            screens: {
                let all = NSScreen.screens
                var visible: [DisplayID: CGRect] = [:]
                for screen in all {
                    if let id = screen.displayID { visible[id] = screen.visibleFrame }
                }
                return PlacingScreens(primary: all.first?.frame ?? .zero, visible: visible)
            },
            process: { app in
                NSRunningApplication.runningApplications(withBundleIdentifier: app.rawValue)
                    .first { !$0.isTerminated }?.processIdentifier
            })
    }

    /// Tests inject the calls, the screens and the process lookup, and hear each work item end through `finished`, on
    /// the work item's thread.
    init<Calls: PlacingCalls>(
        calls: Calls, screens: @escaping @MainActor () -> PlacingScreens,
        process: @escaping @MainActor (BundleID) -> pid_t?,
        finished: @escaping @Sendable (BundleID, Outcome) -> Void = { _, _ in }
    ) {
        self.screens = screens
        self.process = process
        self.finished = finished
        now = { calls.now() }
        perform = { pid, halves, side, previous, budget, isLatest in
            Self.place(pid, in: halves, side: side, previous: previous, budget: budget, calls: calls, isLatest: isLatest)
        }
        raiseWindow = { pid, budget in Self.raise(pid, budget: budget, calls: calls) }
    }

    /// Main actor: the display by number (gone: nothing), `SplitHalves`, the app's running copy from `process` (none, or
    /// this process: nothing), a new ticket; then one work item on that process's serial queue. Returns at once,
    /// answering whether it dispatched a work item; the port ignores the answer.
    @discardableResult func place(_ app: BundleID, in half: ScreenHalf) -> Bool {
        let read = screens()
        guard let visible = read.visible[half.display], let pid = otherProcess(app) else { return false }
        let halves = SplitHalves(visible: visible, primary: read.primary)
        let ticket = tickets.issue(for: pid)
        let budget = ReadBudget(from: now(), within: Self.budget)
        let tickets = tickets, perform = perform, finished = finished
        queue(for: pid).async {
            let previous = tickets.remembered(for: pid, in: half)
            let outcome = perform(pid, halves, half.side, previous, budget) { tickets.isLatest(ticket, for: pid) }
            if case .placed(let frame) = outcome { tickets.remember(frame, in: half, for: pid) }
            finished(app, outcome)
        }
        return true
    }

    /// Raises the app's front window, the one `place` would place, over every other app's windows but the active
    /// app's: a split's second app comes to front this way, without the focus, before the first app activates. One
    /// work item on the process's serial queue, so it follows any placing already queued and never stops one: it takes
    /// no ticket. `then` runs on the main actor once the raise is done, within the budget whatever the app does, or at
    /// once when there is nothing to raise. Returns at once, answering whether it dispatched.
    @discardableResult func raise(
        _ app: BundleID, then: @escaping @MainActor @Sendable () -> Void = {}
    ) -> Bool {
        guard let pid = otherProcess(app) else {
            then()
            return false
        }
        let budget = ReadBudget(from: now(), within: Self.budget)
        let raise = raiseWindow, finished = finished
        queue(for: pid).async {
            finished(app, raise(pid, budget))
            DispatchQueue.main.async { then() }
        }
        return true
    }

    /// The app's running copy, unless it is none or this process.
    private func otherProcess(_ app: BundleID) -> pid_t? {
        guard let pid = process(app), pid != ProcessInfo.processInfo.processIdentifier else { return nil }
        return pid
    }

    private func queue(for pid: pid_t) -> DispatchQueue {
        let queue = queues[pid] ?? DispatchQueue(label: "launcher.window-placing.\(pid)", target: concurrent)
        queues[pid] = queue
        return queue
    }

    /// One window's whole placing, on the calling thread. Each call into the app gets what is left of `budget` as its
    /// messaging timeout; `cannotComplete`, or no time left, ends it with no further call. `previous`: the frame this
    /// process's last completed placing into the same half left.
    ///
    /// - The window is the app's main window, else the first listed window that is standard and not minimised.
    /// - Already in the half, or still at `previous`, and not in full screen: left alone.
    /// - Full screen is left first, then the position is written, then the size. A refused exit or position ends it;
    ///   a refused size carries on, and the window keeps the size it allows.
    /// - A right-half window narrower or wider than the half is moved so its right edge meets the half's.
    nonisolated static func place<Calls: PlacingCalls>(
        _ pid: pid_t, in halves: SplitHalves, side: SplitSide, previous: CGRect?, budget: ReadBudget, calls: Calls,
        isLatest: () -> Bool
    ) -> Outcome {
        let half = halves[side]
        /// Sets the element's timeout from what is left; the outcome that ends the placing when it cannot.
        func prepare(_ element: Calls.Element) -> Outcome? {
            guard isLatest() else { return .superseded }
            guard let timeout = budget.timeout(at: calls.now()) else { return .unanswered }
            calls.setTimeout(timeout, on: element)
            return nil
        }

        let window: Calls.Element
        switch frontWindow(of: pid, calls: calls, prepare: prepare) {
        case .ended(let outcome): return outcome
        case .found(let found): window = found
        }

        if let ended = prepare(window) { return ended }
        let state: WindowState
        switch calls.state(of: window) {
        case .failure(.cannotComplete): return .unanswered
        case .failure: return .noWindow
        case .success(let read): state = read
        }
        if !state.isFullScreen, state.frame == half || state.frame == previous { return .alreadyThere }

        if state.isFullScreen {
            if let ended = prepare(window) { return ended }
            if let error = calls.setFullScreen(false, of: window) { return error == .cannotComplete ? .unanswered : .refused }
        }
        if let ended = prepare(window) { return ended }
        if let error = calls.setPosition(half.origin, of: window) { return error == .cannotComplete ? .unanswered : .refused }
        if let ended = prepare(window) { return ended }
        if calls.setSize(half.size, of: window) == .cannotComplete { return .unanswered }

        if let ended = prepare(window) { return ended }
        let taken: CGSize
        switch calls.size(of: window) {
        case .failure(.cannotComplete): return .unanswered
        case .failure: taken = half.size
        case .success(let size): taken = size
        }
        var origin = half.origin
        if side == .right, taken.width != half.width {
            origin = CGPoint(x: half.maxX - taken.width, y: half.minY)
            if let ended = prepare(window) { return ended }
            if calls.setPosition(origin, of: window) == .cannotComplete { return .unanswered }
        }

        guard isLatest() else { return .superseded }
        guard let timeout = budget.timeout(at: calls.now()) else { return .placed(CGRect(origin: origin, size: taken)) }
        calls.setTimeout(timeout, on: window)
        if case .success(let left) = calls.state(of: window) { return .placed(left.frame) }
        return .placed(CGRect(origin: origin, size: taken))
    }

    /// The front window's raise, on the calling thread, under the same budget rule as `place`.
    nonisolated static func raise<Calls: PlacingCalls>(_ pid: pid_t, budget: ReadBudget, calls: Calls) -> Outcome {
        func prepare(_ element: Calls.Element) -> Outcome? {
            guard let timeout = budget.timeout(at: calls.now()) else { return .unanswered }
            calls.setTimeout(timeout, on: element)
            return nil
        }
        let window: Calls.Element
        switch frontWindow(of: pid, calls: calls, prepare: prepare) {
        case .ended(let outcome): return outcome
        case .found(let found): window = found
        }
        if let ended = prepare(window) { return ended }
        switch calls.raise(window) {
        case nil: return .raised
        case .cannotComplete?: return .unanswered
        case .some: return .refused
        }
    }

    private enum FrontWindow<Element> {
        case found(Element)
        case ended(Outcome)
    }

    /// The window a placing or a raise acts on: the app's main window, else the first listed window that is standard
    /// and not minimised. `prepare` runs before each call and may end the search.
    nonisolated private static func frontWindow<Calls: PlacingCalls>(
        of pid: pid_t, calls: Calls, prepare: (Calls.Element) -> Outcome?
    ) -> FrontWindow<Calls.Element> {
        let app = calls.appElement(pid)
        if let ended = prepare(app) { return .ended(ended) }
        switch calls.mainWindow(of: app) {
        case .failure(.cannotComplete): return .ended(.unanswered)
        case .success(let main?): return .found(main)
        case .success(nil), .failure: break
        }
        if let ended = prepare(app) { return .ended(ended) }
        let listed: [Calls.Element]
        switch calls.windows(of: app) {
        case .failure(.cannotComplete): return .ended(.unanswered)
        case .failure: return .ended(.noWindow)
        case .success(let found): listed = found
        }
        for candidate in listed {
            if let ended = prepare(candidate) { return .ended(ended) }
            switch calls.state(of: candidate) {
            case .failure(.cannotComplete): return .ended(.unanswered)
            case .failure: continue
            case .success(let state):
                if state.isStandard, !state.isMinimised { return .found(candidate) }
            }
        }
        return .ended(.noWindow)
    }

    /// For tests and the remembered frame; it never leaves the file's callers.
    enum Outcome: Equatable { case placed(CGRect), alreadyThere, raised, noWindow, refused, unanswered, superseded }
}

/// What the placer reads of the displays: the primary display's frame and each display's `visibleFrame`, AppKit global.
struct PlacingScreens: Equatable {
    let primary: CGRect
    let visible: [DisplayID: CGRect]
}

/// The two halves of a display's usable area in the Accessibility API's coordinates: global points, origin at the
/// primary display's top-left, y down. Pure; these rectangles never leave the placer.
struct SplitHalves: Equatable {
    let left: CGRect
    let right: CGRect

    /// `visible`: the display's `visibleFrame`; `primary`: the primary display's frame; both AppKit global, y up. The
    /// usable area is trimmed inward to whole points, and the left half takes the odd point.
    init(visible: CGRect, primary: CGRect) {
        let minX = visible.minX.rounded(.up)
        let minY = (primary.maxY - visible.maxY).rounded(.up)
        let width = visible.maxX.rounded(.down) - minX
        let height = (primary.maxY - visible.minY).rounded(.down) - minY
        let leftWidth = (width / 2).rounded(.up)
        left = CGRect(x: minX, y: minY, width: leftWidth, height: height)
        right = CGRect(x: minX + leftWidth, y: minY, width: width - leftWidth, height: height)
    }

    subscript(side: SplitSide) -> CGRect { side == .left ? left : right }
}

/// The placer's calls into one app: an internal seam with two adapters, the real `AXPlacingCalls` and a scripted double
/// in `LauncherPlatformTests`.
protocol PlacingCalls: Sendable {
    associatedtype Element
    func now() -> Uptime
    /// Sets the element's messaging timeout for its next call (always positive).
    func setTimeout(_ seconds: Float, on element: Element)
    func appElement(_ pid: pid_t) -> Element
    /// nil: the app names no main window.
    func mainWindow(of app: Element) -> Result<Element?, WindowCallError>
    func windows(of app: Element) -> Result<[Element], WindowCallError>
    func state(of window: Element) -> Result<WindowState, WindowCallError>
    func size(of window: Element) -> Result<CGSize, WindowCallError>
    func setFullScreen(_ on: Bool, of window: Element) -> WindowCallError?
    func setPosition(_ origin: CGPoint, of window: Element) -> WindowCallError?
    func setSize(_ size: CGSize, of window: Element) -> WindowCallError?
    /// Brings the window in front of its app's other windows and of every other app's, but the active app's.
    func raise(_ window: Element) -> WindowCallError?
}

/// One multiple-attribute read: frame, full screen, subrole and minimised.
struct WindowState: Equatable, Sendable {
    let frame: CGRect
    let isFullScreen: Bool
    let isStandard: Bool
    let isMinimised: Bool
}

/// The latest ticket of each process, and the half and frame its last completed placing left.
final class PlacingTickets: Sendable {
    private struct Entry {
        var ticket = 0
        var remembered: (half: ScreenHalf, frame: CGRect)?
    }

    private let entries = Mutex<[pid_t: Entry]>([:])

    /// Main actor: the only writer of tickets.
    func issue(for pid: pid_t) -> Int {
        entries.withLock {
            $0[pid, default: Entry()].ticket += 1
            return $0[pid]!.ticket
        }
    }

    func isLatest(_ ticket: Int, for pid: pid_t) -> Bool { entries.withLock { $0[pid]?.ticket == ticket } }

    /// The frame the process's last completed placing into this same half left.
    func remembered(for pid: pid_t, in half: ScreenHalf) -> CGRect? {
        entries.withLock { entries in
            guard let remembered = entries[pid]?.remembered, remembered.half == half else { return nil }
            return remembered.frame
        }
    }

    /// Only the process's own work items, which run one at a time.
    func remember(_ frame: CGRect, in half: ScreenHalf, for pid: pid_t) {
        entries.withLock { $0[pid, default: Entry()].remembered = (half, frame) }
    }
}

/// The real calls: the Accessibility element API.
struct AXPlacingCalls: PlacingCalls {
    private static let stateNames = [
        kAXPositionAttribute, kAXSizeAttribute, "AXFullScreen", kAXSubroleAttribute, kAXMinimizedAttribute,
    ]

    func now() -> Uptime { .now }

    func setTimeout(_ seconds: Float, on element: AXUIElement) {
        AXUIElementSetMessagingTimeout(element, seconds)
    }

    func appElement(_ pid: pid_t) -> AXUIElement { AXUIElementCreateApplication(pid) }

    func mainWindow(of app: AXUIElement) -> Result<AXUIElement?, WindowCallError> {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(app, kAXMainWindowAttribute as CFString, &value)
        switch error {
        case .success:
            guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return .success(nil) }
            return .success((value as! AXUIElement))
        case .noValue, .attributeUnsupported: return .success(nil)
        default: return .failure(Self.parse(error))
        }
    }

    func windows(of app: AXUIElement) -> Result<[AXUIElement], WindowCallError> {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
        guard error == .success else { return .failure(Self.parse(error)) }
        guard let elements = value as? [AXUIElement] else { return .failure(.noValue) }
        return .success(elements)
    }

    func state(of window: AXUIElement) -> Result<WindowState, WindowCallError> {
        var values: CFArray?
        let error = AXUIElementCopyMultipleAttributeValues(
            window, Self.stateNames as CFArray, AXCopyMultipleAttributeOptions(rawValue: 0), &values)
        guard error == .success else { return .failure(Self.parse(error)) }
        guard let values = values as? [AnyObject], values.count == Self.stateNames.count,
            let origin = Self.point(values[0]), let size = Self.size(values[1])
        else { return .failure(.other) }
        return .success(
            WindowState(
                frame: CGRect(origin: origin, size: size), isFullScreen: values[2] as? Bool ?? false,
                isStandard: values[3] as? String == kAXStandardWindowSubrole,
                isMinimised: values[4] as? Bool ?? false))
    }

    func size(of window: AXUIElement) -> Result<CGSize, WindowCallError> {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &value)
        guard error == .success else { return .failure(Self.parse(error)) }
        guard let value, let size = Self.size(value) else { return .failure(.other) }
        return .success(size)
    }

    func setFullScreen(_ on: Bool, of window: AXUIElement) -> WindowCallError? {
        Self.failure(
            AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, on ? kCFBooleanTrue : kCFBooleanFalse))
    }

    func setPosition(_ origin: CGPoint, of window: AXUIElement) -> WindowCallError? {
        var origin = origin
        guard let value = AXValueCreate(.cgPoint, &origin) else { return .other }
        return Self.failure(AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value))
    }

    func setSize(_ size: CGSize, of window: AXUIElement) -> WindowCallError? {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return .other }
        return Self.failure(AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value))
    }

    func raise(_ window: AXUIElement) -> WindowCallError? {
        Self.failure(AXUIElementPerformAction(window, kAXRaiseAction as CFString))
    }

    private static func parse(_ error: AXError) -> WindowCallError {
        switch error {
        case .cannotComplete: .cannotComplete
        case .noValue: .noValue
        default: .other
        }
    }

    private static func failure(_ error: AXError) -> WindowCallError? { error == .success ? nil : parse(error) }

    private static func point(_ object: AnyObject) -> CGPoint? {
        guard CFGetTypeID(object) == AXValueGetTypeID() else { return nil }
        let value = object as! AXValue
        var point = CGPoint.zero
        return AXValueGetType(value) == .cgPoint && AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    private static func size(_ object: AnyObject) -> CGSize? {
        guard CFGetTypeID(object) == AXValueGetTypeID() else { return nil }
        let value = object as! AXValue
        var size = CGSize.zero
        return AXValueGetType(value) == .cgSize && AXValueGetValue(value, .cgSize, &size) ? size : nil
    }
}
