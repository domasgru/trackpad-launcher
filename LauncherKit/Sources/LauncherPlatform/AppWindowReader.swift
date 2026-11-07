import AppKit
import ApplicationServices
import CoreGraphics
import LauncherCore

/// The frontmost app's windows, read through the Accessibility element API and the window server's window list, and
/// raised through the element API: with `LaunchWatch`, the only file that touches either. The element API defines which
/// windows exist (titles, roles, minimised, full screen); the window list orders the visible ones and tells which are
/// on this Space.
///
/// A window's number comes from the private `_AXUIElementGetWindow`, resolved once with `dlsym` from the image
/// AppKit already loaded; when a macOS drops it, or it fails for one window, that window is matched to the window list
/// by frame and title instead, and a window that matches none is left out.
@MainActor final class AppWindowReader {
    /// The process default for any element that sets none; every read here sets its own per call.
    static let messagingTimeout: Float = 0.2

    private let calls = AXWindowCalls()
    /// The windows the latest read listed: the only ones a raise may touch, so nothing on another Space is raised.
    private var listed: [WindowID: AXUIElement] = [:]
    /// The app timed out during the latest read or a raise since: no further calls go to it until the next read.
    private var isUnanswering = false

    /// Sets the messaging timeout once on the system-wide element, which makes it the process's default (set on any
    /// other element it covers that element only); and pays the window list's first-call cost (about 50 ms) off the
    /// main actor now rather than at the first window swipe.
    init() {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), Self.messagingTimeout)
        Task { await Self.warmWindowList() }
    }

    @concurrent private static func warmWindowList() async {
        _ = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
    }

    /// The frontmost app's read, held to `deadline`; replaces the raise handles with the listed windows' elements.
    func readFrontmost(within deadline: Duration) -> FrontmostWindows {
        let budget = ReadBudget(from: .now, within: deadline)
        listed = [:]
        isUnanswering = false
        guard let running = NSWorkspace.shared.frontmostApplication, let entry = RunningApp.entry(for: running)
        else { return .noApp }
        let pid = running.processIdentifier
        let launch = Self.launch(of: pid)
        if pid == ProcessInfo.processInfo.processIdentifier { return .app(entry, launch, .ownProcess) }
        let (read, elements) = Self.read(Target(pid: pid), budget: budget, calls: calls)
        listed = elements
        isUnanswering = read == .unanswered
        return .app(entry, launch, read)
    }

    /// The last first, each to the front of its app; a raised minimised window is restored. A closed window answers
    /// invalid-element and is skipped; a window the latest read did not list is skipped.
    func raise(_ frontToBack: [WindowID]) {
        for id in frontToBack.reversed() {
            guard !isUnanswering else { return }
            guard let element = listed[id] else { continue }
            if AXUIElementPerformAction(element, kAXRaiseAction as CFString) == .cannotComplete { isUnanswering = true }
        }
    }

    /// Which of these windows the window server still holds, on any Space, minimised or not. The window list describes
    /// only the numbers asked for, so this costs about 0.2 ms however many windows the Mac has.
    func openWindows(among ids: Set<WindowID>) -> Set<WindowID> {
        var pointers: [UnsafeRawPointer?] = ids.compactMap { UnsafeRawPointer(bitPattern: UInt($0.rawValue)) }
        guard !pointers.isEmpty,
            let array = CFArrayCreate(nil, &pointers, pointers.count, nil),
            let described = CGWindowListCreateDescriptionFromArray(array) as? [[String: Any]]
        else { return [] }
        return Set(
            described.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value }
                .map { WindowID(rawValue: $0) }
                .filter(ids.contains))
    }

    /// The process id with the kernel's start time for that process, which tells two launches of one app apart.
    /// `NSRunningApplication.launchDate` is no use: apps launched outside LaunchServices lack it.
    private static func launch(of pid: pid_t) -> AppLaunch {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var query: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&query, UInt32(query.count), &info, &size, nil, 0) == 0, size > 0 else {
            return AppLaunch("\(pid)")
        }
        let started = info.kp_proc.p_un.__p_starttime
        return AppLaunch("\(pid)-\(started.tv_sec).\(started.tv_usec)")
    }

    struct Target: Sendable {
        let pid: pid_t
    }

    /// One app's whole read, on the calling thread, through `calls`: kAXWindows; one multiple-attribute call per window
    /// (role, subrole, title, minimised, full screen, position, size); the window's number; the on-screen window list
    /// for order (and the full list only for the frame fallback when the number cannot be had). Before each call into
    /// the app, the element's messaging timeout is set to `budget.timeout(at: calls.now())`.
    /// - kAXWindows: success lists; no value is no windows; anything else is `.unanswered`.
    /// - A window's attributes: `cannotComplete` is `.unanswered`; any other failure skips that window.
    /// - A window's number: `cannotComplete` is `.unanswered`; any other failure falls back to `number(of:among:)`
    ///   over the one `calls.listedWindows(of:)` copy, taken only when needed; no single match leaves the window out.
    /// - No time left before a call, or a read `budget` does not admit when it ends: `.unanswered`, whatever was read.
    /// Returns the listed windows' elements, for the one caller that raises.
    nonisolated static func read<Calls: WindowCalls>(
        _ target: Target, budget: ReadBudget, calls: Calls
    ) -> (read: WindowRead, elements: [WindowID: Calls.Element]) {
        let unanswered: (read: WindowRead, elements: [WindowID: Calls.Element]) = (.unanswered, [:])
        /// Sets the element's timeout from what is left; false when nothing is.
        func prepare(_ element: Calls.Element) -> Bool {
            guard let timeout = budget.timeout(at: calls.now()) else { return false }
            calls.setTimeout(timeout, on: element)
            return true
        }

        let app = calls.appElement(target.pid)
        guard prepare(app) else { return unanswered }
        let elements: [Calls.Element]
        switch calls.windows(of: app) {
        case .success(let found): elements = found
        case .failure(.noValue): elements = []
        case .failure: return unanswered
        }

        var raw: [RawWindow] = []
        var rawElements: [Calls.Element] = []
        for element in elements {
            guard prepare(element) else { return unanswered }
            var window: RawWindow
            switch calls.attributes(of: element) {
            case .success(let attributes): window = attributes
            case .failure(.cannotComplete): return unanswered
            case .failure: continue
            }
            guard prepare(element) else { return unanswered }
            switch calls.number(of: element) {
            case .success(let number): window.number = number
            case .failure(.cannotComplete): return unanswered
            case .failure: window.number = nil
            }
            raw.append(window)
            rawElements.append(element)
        }
        if raw.contains(where: { $0.number == nil }) {
            let listedWindows = calls.listedWindows(of: target.pid)
            for i in raw.indices where raw[i].number == nil {
                raw[i].number = number(of: raw[i], among: listedWindows)
            }
        }
        let sorted = sort(raw, onScreen: calls.onScreenNumbers(of: target.pid))
        guard budget.admits(endedAt: calls.now()) else { return unanswered }

        var elementsByID: [WindowID: Calls.Element] = [:]
        for (window, element) in zip(raw, rawElements) {
            if let number = window.number { elementsByID[WindowID(rawValue: number)] = element }
        }
        var listed: [WindowID: Calls.Element] = [:]
        for window in sorted.visible + sorted.minimised { listed[window.id] = elementsByID[window.id] }
        return (.windows(AppWindows(visible: sorted.visible, minimised: sorted.minimised)), listed)
    }

    /// Which windows are listed, and in what order. Visible: role AXWindow, subrole AXStandardWindow, not minimised,
    /// on screen now (so on this Space), in the window list's order. Minimised: by the minimised flag alone, because a
    /// minimised window reports the AXDialog subrole, in the app's order. A window with no number is left out.
    nonisolated static func sort(
        _ windows: [RawWindow], onScreen: [UInt32]
    ) -> (visible: [AppWindow], minimised: [AppWindow]) {
        var standard: [UInt32: AppWindow] = [:]
        var minimised: [AppWindow] = []
        for window in windows {
            guard let number = window.number else { continue }
            if window.isMinimised {
                minimised.append(AppWindow(id: WindowID(rawValue: number), title: window.title))
            } else if window.role == "AXWindow", window.subrole == "AXStandardWindow" {
                standard[number] = AppWindow(
                    id: WindowID(rawValue: number), title: window.title, isFullScreen: window.isFullScreen)
            }
        }
        return (onScreen.compactMap { standard[$0] }, minimised)
    }

    /// The window's number without the private call: the one listed window with the same frame and, where the list
    /// names windows, the same title. nil when none or more than one matches, or the window has no frame.
    nonisolated static func number(of window: RawWindow, among listed: [ListedWindow]) -> UInt32? {
        guard let frame = window.frame else { return nil }
        let matches = listed.filter { $0.frame == frame && ($0.name.map { $0 == window.title } ?? true) }
        return matches.count == 1 ? matches[0].number : nil
    }
}

/// The read's calls into one app, and the clock: an internal seam with two adapters, the real `AXWindowCalls` over the
/// Accessibility element API, the private window number and the window list, and a scripted double in
/// `LauncherPlatformTests` that answers, refuses, stalls past the budget or advances the clock per call.
protocol WindowCalls: Sendable {
    associatedtype Element
    func now() -> Uptime
    /// Sets the element's messaging timeout for its next call (always positive: the budget never hands out zero).
    func setTimeout(_ seconds: Float, on element: Element)
    func appElement(_ pid: pid_t) -> Element
    func windows(of app: Element) -> Result<[Element], WindowCallError>
    /// The window's attributes; its number is not yet filled.
    func attributes(of window: Element) -> Result<RawWindow, WindowCallError>
    func number(of window: Element) -> Result<UInt32, WindowCallError>
    /// The pid's normal-layer windows on screen now, front to back.
    func onScreenNumbers(of pid: pid_t) -> [UInt32]
    /// Every normal-layer window of the pid, with frame and name: only for the frame fallback.
    func listedWindows(of pid: pid_t) -> [ListedWindow]
}

/// How a call into the app failed, parsed from the Accessibility error at the seam.
enum WindowCallError: Error, Equatable { case cannotComplete, noValue, other }

/// What is left of one read's deadline on the process's monotonic clock. Pure: tests pass the time.
struct ReadBudget: Equatable, Sendable {
    let deadline: Uptime

    init(from start: Uptime, within: Duration) { deadline = start + within }

    /// The messaging timeout for a call made at `now`: what is left, always positive; nil at or past the deadline, so no
    /// further call is made (a zero timeout would mean "the global 0.2 s" to Accessibility).
    func timeout(at now: Uptime) -> Float? {
        let timeout = Float(deadline.seconds - now.seconds)
        return timeout > 0 ? timeout : nil
    }

    /// Whether a read that ended at `now` answered in time.
    func admits(endedAt now: Uptime) -> Bool { now <= deadline }
}

/// The real calls: the Accessibility element API, the private window number and the window server's window list.
struct AXWindowCalls: WindowCalls {
    private typealias GetWindow = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError

    private let getWindow: GetWindow?

    private static let attributeNames = [
        kAXRoleAttribute, kAXSubroleAttribute, kAXTitleAttribute, kAXMinimizedAttribute, "AXFullScreen",
        kAXPositionAttribute, kAXSizeAttribute,
    ]

    /// Resolves the private window number once. Missing on a macOS that drops it: every number call then fails.
    init() {
        // RTLD_DEFAULT
        getWindow = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementGetWindow")
            .map { unsafeBitCast($0, to: GetWindow.self) }
    }

    func now() -> Uptime { .now }

    func setTimeout(_ seconds: Float, on element: AXUIElement) {
        AXUIElementSetMessagingTimeout(element, seconds)
    }

    func appElement(_ pid: pid_t) -> AXUIElement { AXUIElementCreateApplication(pid) }

    func windows(of app: AXUIElement) -> Result<[AXUIElement], WindowCallError> {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
        guard error == .success else { return .failure(Self.parse(error)) }
        guard let elements = value as? [AXUIElement] else { return .failure(.noValue) }
        return .success(elements)
    }

    func attributes(of window: AXUIElement) -> Result<RawWindow, WindowCallError> {
        var values: CFArray?
        let error = AXUIElementCopyMultipleAttributeValues(
            window, Self.attributeNames as CFArray, AXCopyMultipleAttributeOptions(rawValue: 0), &values)
        guard error == .success else { return .failure(Self.parse(error)) }
        guard let values = values as? [AnyObject] else { return .failure(.other) }
        return .success(Self.rawWindow(values))
    }

    func number(of window: AXUIElement) -> Result<UInt32, WindowCallError> {
        guard let getWindow else { return .failure(.other) }
        var number: CGWindowID = 0
        let error = getWindow(window, &number)
        return error == .success ? .success(number) : .failure(Self.parse(error))
    }

    /// The pid's normal-layer windows on screen now, front to back: on this Space, not minimised.
    func onScreenNumbers(of pid: pid_t) -> [UInt32] {
        Self.windowList([.optionOnScreenOnly, .excludeDesktopElements], of: pid).map(\.number)
    }

    /// Every normal-layer window of the pid the window server knows, minimised ones included, for matching by frame.
    func listedWindows(of pid: pid_t) -> [ListedWindow] {
        Self.windowList([.optionAll, .excludeDesktopElements], of: pid)
    }

    private static func parse(_ error: AXError) -> WindowCallError {
        switch error {
        case .cannotComplete: .cannotComplete
        case .noValue: .noValue
        default: .other
        }
    }

    /// The values in `attributeNames`' order; an attribute the window lacks comes back as an error value and reads as
    /// nil.
    private static func rawWindow(_ values: [AnyObject]) -> RawWindow {
        func value(_ index: Int) -> AnyObject? { index < values.count ? values[index] : nil }
        func axValue(_ index: Int, _ type: AXValueType) -> AXValue? {
            guard let object = value(index), CFGetTypeID(object) == AXValueGetTypeID() else { return nil }
            let axValue = object as! AXValue
            return AXValueGetType(axValue) == type ? axValue : nil
        }
        var origin = CGPoint.zero
        var extent = CGSize.zero
        let position = axValue(5, .cgPoint).flatMap { AXValueGetValue($0, .cgPoint, &origin) ? origin : nil }
        let size = axValue(6, .cgSize).flatMap { AXValueGetValue($0, .cgSize, &extent) ? extent : nil }
        return RawWindow(
            number: nil, title: value(2) as? String ?? "", role: value(0) as? String, subrole: value(1) as? String,
            isMinimised: value(3) as? Bool ?? false, isFullScreen: value(4) as? Bool ?? false,
            frame: position.flatMap { origin in size.map { CGRect(origin: origin, size: $0) } })
    }

    private static func windowList(_ options: CGWindowListOption, of pid: pid_t) -> [ListedWindow] {
        let all = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        return all.compactMap { info in
            guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
                (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                let number = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                let frame = CGRect(dictionaryRepresentation: bounds)
            else { return nil }
            return ListedWindow(number: number, frame: frame, name: info[kCGWindowName as String] as? String)
        }
    }
}

/// What the element API said about one window.
struct RawWindow: Sendable {
    var number: UInt32?
    let title: String
    let role: String?
    let subrole: String?
    let isMinimised: Bool
    let isFullScreen: Bool
    /// Top-left origin, in global display points, as the window list reports bounds.
    let frame: CGRect?
}

/// One entry of the window server's window list.
struct ListedWindow: Sendable {
    let number: UInt32
    let frame: CGRect
    /// nil without Screen Recording, which the window list needs to name windows.
    let name: String?
}
