import CoreGraphics
import Dispatch
import LauncherCore
import Synchronization

@testable import LauncherPlatform

/// The placer's calls into apps, scripted. Each call costs milliseconds on the double's own clock (1 unless set), may
/// answer an error, and is recorded per process with the timeout set before it. A window applies macOS's probed rules:
/// a fixed size refuses a size write with an error other than `cannotComplete`; a size below the minimum takes the
/// minimum and one above the maximum takes the maximum; a position is taken as given.
/// Elements are `Ref`s: window 0 is the app, 1... its windows.
final class ScriptedPlacing: PlacingCalls {
    struct Ref: Sendable, Hashable {
        let pid: pid_t
        let window: Int
    }

    struct Window: Sendable {
        var frame: CGRect
        var isStandard = true
        var isMinimised = false
        var isFullScreen = false
        var minimumSize: CGSize?
        var maximumSize: CGSize?
        var isFixed = false

        init(_ frame: CGRect) { self.frame = frame }
    }

    struct App: Sendable {
        var windows: [Window]
        /// 1-based; nil: the app names no main window.
        var main: Int?

        init(windows: [Window], main: Int? = 1) {
            self.windows = windows
            self.main = main
        }
    }

    enum Write: Equatable, Sendable {
        case fullScreen(Bool)
        case position(CGPoint)
        case size(CGSize)
    }

    struct Touch: Equatable, Sendable {
        let write: Write
        let window: Int
    }

    struct Script: Sendable {
        var defaultCost = 1
        var costs: [String: Int] = [:]
        var errors: [String: WindowCallError] = [:]
        /// Added to the origin on the first state read after a write: what macOS may do.
        var drift: CGPoint?
    }

    private struct Hold {
        let release = DispatchSemaphore(value: 0)
        let reached: AsyncStream<Void>.Continuation
    }

    private struct Record {
        var elapsed = 0
        var apps: [pid_t: App]
        var timeouts: [pid_t: [Float]] = [:]
        var intoApp: [pid_t: [String]] = [:]
        var touches: [pid_t: [Touch]] = [:]
        var frames: [pid_t: [CGRect]] = [:]
        var calls: [String] = []
        var drifted = false
        var holds: [String: Hold] = [:]
    }

    private let script: Script
    private let record: Mutex<Record>
    private let hook: @Sendable (pid_t, String) -> Void

    init(_ apps: [pid_t: App], script: Script = Script(), hook: @escaping @Sendable (pid_t, String) -> Void = { _, _ in }) {
        self.script = script
        self.hook = hook
        record = Mutex(Record(apps: apps))
    }

    convenience init(_ window: Window, script: Script = Script(), hook: @escaping @Sendable (pid_t, String) -> Void = { _, _ in }) {
        self.init([1: App(windows: [window])], script: script, hook: hook)
    }

    func timeouts(_ pid: pid_t = 1) -> [Float] { record.withLock { $0.timeouts[pid] ?? [] } }
    func intoApp(_ pid: pid_t = 1) -> [String] { record.withLock { $0.intoApp[pid] ?? [] } }
    func writes(_ pid: pid_t = 1) -> [Write] { record.withLock { ($0.touches[pid] ?? []).map(\.write) } }
    func touched(_ pid: pid_t = 1) -> Set<Int> { record.withLock { Set(($0.touches[pid] ?? []).map(\.window)) } }
    func frames(_ pid: pid_t = 1) -> [CGRect] { record.withLock { $0.frames[pid] ?? [] } }
    /// Every call into any app, as "pid name", in the order they began.
    var calls: [String] { record.withLock { $0.calls } }

    func frame(of window: Int = 1, pid: pid_t = 1) -> CGRect {
        record.withLock { $0.apps[pid]!.windows[window - 1].frame }
    }

    /// What the user did meanwhile.
    func move(_ window: Int = 1, pid: pid_t = 1, to frame: CGRect) {
        record.withLock { $0.apps[pid]!.windows[window - 1].frame = frame }
    }

    /// Holds the next call of this name into this process until `release`; `reached` yields once the call is inside.
    func hold(_ name: String, pid: pid_t) -> (reached: AsyncStream<Void>, release: @Sendable () -> Void) {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        let hold = Hold(reached: continuation)
        record.withLock { $0.holds["\(pid) \(name)"] = hold }
        return (stream, { hold.release.signal() })
    }

    func now() -> Uptime { Uptime(seconds: Double(record.withLock { $0.elapsed }) / 1000) }

    func setTimeout(_ seconds: Float, on element: Ref) {
        record.withLock { $0.timeouts[element.pid, default: []].append(seconds) }
    }

    func appElement(_ pid: pid_t) -> Ref { Ref(pid: pid, window: 0) }

    /// Records the call, spends its cost, waits for a hold on it, runs the hook; answers the scripted error.
    private func enter(_ element: Ref, _ name: String) -> WindowCallError? {
        let hold: Hold? = record.withLock {
            $0.intoApp[element.pid, default: []].append(name)
            $0.calls.append("\(element.pid) \(name)")
            $0.elapsed += script.costs[name] ?? script.defaultCost
            return $0.holds.removeValue(forKey: "\(element.pid) \(name)")
        }
        if let hold {
            hold.reached.yield()
            hold.release.wait()
        }
        hook(element.pid, name)
        return script.errors[name]
    }

    func mainWindow(of app: Ref) -> Result<Ref?, WindowCallError> {
        if let error = enter(app, "mainWindow") { return .failure(error) }
        let main = record.withLock { $0.apps[app.pid]!.main }
        return .success(main.map { Ref(pid: app.pid, window: $0) })
    }

    func windows(of app: Ref) -> Result<[Ref], WindowCallError> {
        if let error = enter(app, "windows") { return .failure(error) }
        let count = record.withLock { $0.apps[app.pid]!.windows.count }
        return .success((0..<count).map { Ref(pid: app.pid, window: $0 + 1) })
    }

    func state(of window: Ref) -> Result<WindowState, WindowCallError> {
        if let error = enter(window, "state") { return .failure(error) }
        return .success(
            record.withLock {
                if let drift = script.drift, !$0.drifted, $0.touches[window.pid] != nil {
                    $0.drifted = true
                    $0.apps[window.pid]!.windows[window.window - 1].frame.origin.x += drift.x
                    $0.apps[window.pid]!.windows[window.window - 1].frame.origin.y += drift.y
                }
                let read = $0.apps[window.pid]!.windows[window.window - 1]
                return WindowState(
                    frame: read.frame, isFullScreen: read.isFullScreen, isStandard: read.isStandard,
                    isMinimised: read.isMinimised)
            })
    }

    func size(of window: Ref) -> Result<CGSize, WindowCallError> {
        if let error = enter(window, "size") { return .failure(error) }
        return .success(record.withLock { $0.apps[window.pid]!.windows[window.window - 1].frame.size })
    }

    private func write(_ write: Write, on window: Ref, name: String, apply: (inout Window) -> WindowCallError?) -> WindowCallError? {
        let scripted = enter(window, name)
        return record.withLock {
            $0.touches[window.pid, default: []].append(Touch(write: write, window: window.window))
            var error = scripted
            if error == nil { error = apply(&$0.apps[window.pid]!.windows[window.window - 1]) }
            $0.frames[window.pid, default: []].append($0.apps[window.pid]!.windows[window.window - 1].frame)
            return error
        }
    }

    func setFullScreen(_ on: Bool, of window: Ref) -> WindowCallError? {
        write(.fullScreen(on), on: window, name: "setFullScreen") {
            $0.isFullScreen = on
            return nil
        }
    }

    func setPosition(_ origin: CGPoint, of window: Ref) -> WindowCallError? {
        write(.position(origin), on: window, name: "setPosition") {
            $0.frame.origin = origin
            return nil
        }
    }

    func setSize(_ size: CGSize, of window: Ref) -> WindowCallError? {
        write(.size(size), on: window, name: "setSize") { window in
            if window.isFixed { return .other }
            var taken = size
            if let minimum = window.minimumSize {
                taken = CGSize(width: max(taken.width, minimum.width), height: max(taken.height, minimum.height))
            }
            if let maximum = window.maximumSize {
                taken = CGSize(width: min(taken.width, maximum.width), height: min(taken.height, maximum.height))
            }
            window.frame.size = taken
            return nil
        }
    }
}
