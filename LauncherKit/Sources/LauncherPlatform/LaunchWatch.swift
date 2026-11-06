import AppKit
import ApplicationServices
import CoreGraphics
import LauncherCore

/// Watches one launch a gesture started, from macOS's answer to `openApplication` until `stop()`: the process's
/// finishing and ending by key-value observation, which macOS pushes for every kind of app, then one look at its
/// windows and, with Accessibility, its first window created later. Only the window list says a window is on screen: an
/// Accessibility window may be a hidden startup window, so it is a reason to look, never the answer. When it cannot be
/// told of the next window (no Accessibility, the app's Accessibility server not answering yet, as Things' is at
/// finishing, or a window that exists but does not show), it looks at the window list again every `relookInterval`
/// instead, until a window shows or `stop()`. Its time (the cap, the limit
/// once the app finished launching, the re-look interval) passes on its own `LaunchClock`, made when it starts, so it
/// runs with or without a bounce and costs nothing before the app is opened. Reports each fact at most once, nothing after `stop()`, and holds nothing once stopped. Every Accessibility call goes to the
/// app element it creates, whose messaging timeout it sets to `messagingTimeout` itself.
@MainActor final class LaunchWatch {
    static let messagingTimeout: Float = 0.2
    /// A window-list read takes about a millisecond and needs no permission.
    static let relookInterval = Duration.milliseconds(50)

    private let report: @MainActor (LaunchProgress) -> Void
    /// Made by `start(cap:)`.
    private var clock: LaunchClock?
    private var process: NSRunningApplication?
    private var observations: [NSKeyValueObservation] = []
    private var windowObserver: AXObserver?
    private var hasFinished = false
    private var hasGoneNowhere = false
    private var hasRunOut = false
    private var isStopped = false

    init(report: @escaping @MainActor (LaunchProgress) -> Void) {
        self.report = report
    }

    isolated deinit { stop() }

    /// macOS's answer, from any thread. Hops to the main actor with only the pid.
    nonisolated func opened(_ pid: pid_t?) {
        Task { @MainActor [weak self] in self?.adopt(pid) }
    }

    /// Runs the watch out at `cap` at the latest.
    func start(cap: Duration) {
        guard !isStopped, clock == nil else { return }
        let clock = LaunchClock()
        self.clock = clock
        clock.after(cap) { [weak self] in self?.runOut() }
    }

    /// From now on the watch runs out within `limit` at the latest, never later than its cap or an earlier limit: the
    /// first deadline to pass reports.
    func limit(to limit: Duration) {
        guard !isStopped else { return }
        clock?.after(limit) { [weak self] in self?.runOut() }
    }

    private func runOut() {
        guard !isStopped, !hasRunOut else { return }
        hasRunOut = true
        report(.ranOut)
    }

    /// Stops the clock, invalidates the observations and removes the window observer's run-loop source. Idempotent.
    func stop() {
        isStopped = true
        clock?.stop()
        clock = nil
        dropWindowObserver()
        observations.forEach { $0.invalidate() }
        observations = []
        process = nil
    }

    private func adopt(_ pid: pid_t?) {
        guard !isStopped else { return }
        guard let pid, let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated
        else { return wentNowhere() }
        process = app
        // Each handler hops to the main actor: KVO pushes on whichever thread changed the property.
        observations = [
            app.observe(\.isTerminated, options: [.initial, .new]) { [weak self] _, change in
                guard change.newValue == true else { return }
                Task { @MainActor [weak self] in self?.wentNowhere() }
            },
            app.observe(\.isFinishedLaunching, options: [.initial, .new]) { [weak self] _, change in
                guard change.newValue == true else { return }
                Task { @MainActor [weak self] in self?.finished(pid) }
            },
        ]
    }

    private func finished(_ pid: pid_t) {
        guard !isStopped, !hasFinished else { return }
        hasFinished = true
        report(.finishedLaunching)
        // The report may have ended the bounce.
        guard !isStopped else { return }
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, Self.messagingTimeout)
        let registration = register(on: element, pid: pid)
        var axWindows = 0
        if registration == .registered {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success {
                axWindows = (value as? [AXUIElement])?.count ?? 0
            }
        }
        switch Self.look(registration, axWindows: axWindows, listedWindows: Self.listedWindows(of: pid)) {
        case .shown:
            dropWindowObserver()
            report(.windowShown)
        case .watching: break
        case .relooking:
            dropWindowObserver()
            relookLater(pid)
        }
    }

    private func relookLater(_ pid: pid_t) {
        clock?.after(Self.relookInterval) { [weak self] in self?.relook(pid) }
    }

    private func relook(_ pid: pid_t) {
        guard !isStopped else { return }
        guard Self.listedWindows(of: pid) > 0 else { return relookLater(pid) }
        report(.windowShown)
    }

    /// Tries once to be told of the app's next window. Without the Accessibility permission this fails with
    /// `apiDisabled`; nothing checks trust first.
    private func register(on element: AXUIElement, pid: pid_t) -> Registration {
        var observer: AXObserver?
        let created = AXObserverCreate(pid, windowCreatedCallback, &observer)
        guard created == .success, let observer else { return created == .apiDisabled ? .noAccess : .notAnswering }
        let added = AXObserverAddNotification(
            observer, element, kAXWindowCreatedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
        guard added == .success else { return added == .apiDisabled ? .noAccess : .notAnswering }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        windowObserver = observer
        return .registered
    }

    private func dropWindowObserver() {
        guard let observer = windowObserver else { return }
        windowObserver = nil
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    fileprivate func windowCreated() {
        guard !isStopped, windowObserver != nil, let pid = process?.processIdentifier else { return }
        dropWindowObserver()
        relook(pid)
    }

    private func wentNowhere() {
        guard !isStopped, !hasGoneNowhere else { return }
        hasGoneNowhere = true
        report(.wentNowhere)
    }

    /// The pid's windows on screen now in the window list that a user can see. Needs no permission. Racy at finishing.
    nonisolated static func listedWindows(of pid: pid_t) -> Int {
        let all = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        let statusLevel = Int(CGWindowLevelForKey(.statusWindow))
        return all.filter { isVisibleWindow($0, of: pid, statusLevel: statusLevel) }.count
    }

    /// One window-list entry. Pure: a splash counts; a status-level helper, a transparent window and a sliver of a
    /// point or less do not.
    nonisolated static func isVisibleWindow(_ info: [String: Any], of pid: pid_t, statusLevel: Int) -> Bool {
        guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
            ((info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? statusLevel) < statusLevel,
            ((info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1) > 0,
            let bounds = info[kCGWindowBounds as String] as? [String: Any],
            let width = (bounds["Width"] as? NSNumber)?.doubleValue,
            let height = (bounds["Height"] as? NSNumber)?.doubleValue
        else { return false }
        return width > 1 && height > 1
    }

    enum Registration: Equatable { case registered, notAnswering, noAccess }
    enum Look: Equatable { case shown, watching, relooking }

    /// One look at a launching app's windows when it finished launching. Pure: a listed window is `.shown`. With none,
    /// an Accessibility window is one that does not show, and showing it creates nothing to be told of, so `.relooking`;
    /// no window at all while registered is `.watching`; otherwise `.relooking`.
    nonisolated static func look(_ registration: Registration, axWindows: Int, listedWindows: Int) -> Look {
        if listedWindows > 0 { return .shown }
        return registration == .registered && axWindows == 0 ? .watching : .relooking
    }
}

/// At file scope: a closure written inside the main-actor class would be main-actor isolated, and the runtime traps
/// if it is not called there. The source is on the main run loop, so it is.
private let windowCreatedCallback: AXObserverCallback = { _, _, _, refcon in
    guard let refcon else { return }
    let address = Int(bitPattern: refcon)
    MainActor.assumeIsolated {
        guard let pointer = UnsafeRawPointer(bitPattern: address) else { return }
        Unmanaged<LaunchWatch>.fromOpaque(pointer).takeUnretainedValue().windowCreated()
    }
}
