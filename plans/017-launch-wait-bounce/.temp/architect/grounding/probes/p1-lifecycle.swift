// Probe P1: the timeline of every push signal macOS gives about an app a gesture launches,
// against when its first window is really on screen.
// Usage: p1-lifecycle <app bundle path> [--twice] [--hold S] [--keep] [-- app arguments...]
// Launches the app as WorkspaceActions.bringToFront does (openApplication, activates = true),
// records (ms since the call): the completion handler, workspace notifications, KVO on
// runningApplications / isFinishedLaunching / isTerminated, AX notifications (when trusted),
// and, for measurement only, polls the window list every 2 ms for the first on-screen window.
// Quits the app afterwards unless it was already running or --keep is given.
import AppKit
import ApplicationServices

var argv = Array(CommandLine.arguments.dropFirst())
var appArgs: [String] = []
if let dash = argv.firstIndex(of: "--") { appArgs = Array(argv[(dash + 1)...]); argv = Array(argv[..<dash]) }
let path = argv[0]
let twice = argv.contains("--twice")
let keep = argv.contains("--keep")
let hold = argv.firstIndex(of: "--hold").map { Double(argv[$0 + 1])! } ?? 5
let url = URL(fileURLWithPath: path)
let bundleID = Bundle(url: url)?.bundleIdentifier ?? "?"
let wasRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty

let t0 = CACurrentMediaTime()
func ms() -> String { String(format: "%7.1f ms", (CACurrentMediaTime() - t0) * 1000) }
func log(_ s: String) { print("\(ms())  \(s)"); fflush(stdout) }
print("app=\(bundleID) wasRunning=\(wasRunning) twice=\(twice) args=\(appArgs) AXTrusted=\(AXIsProcessTrusted())")

final class Observer: NSObject {
    var target: NSRunningApplication?
    var kvo: [NSKeyValueObservation] = []
    var axObserver: AXObserver?
    var axAttempts = 0
    var firstAnyWindow = false
    var firstLayer0Window = false
    var poll: DispatchSourceTimer?

    func adopt(_ app: NSRunningApplication, via: String) {
        guard target == nil else { return }
        target = app
        log("adopted pid \(app.processIdentifier) via \(via); isFinishedLaunching=\(app.isFinishedLaunching) activationPolicy=\(app.activationPolicy.rawValue)")
        kvo.append(app.observe(\.isFinishedLaunching, options: [.new]) { a, _ in
            DispatchQueue.main.async { log("KVO isFinishedLaunching -> \(a.isFinishedLaunching)") } })
        kvo.append(app.observe(\.isTerminated, options: [.new]) { a, _ in
            DispatchQueue.main.async { log("KVO isTerminated -> \(a.isTerminated)") } })
        kvo.append(app.observe(\.isActive, options: [.new]) { a, _ in
            DispatchQueue.main.async { log("KVO isActive -> \(a.isActive)") } })
        if AXIsProcessTrusted() { tryAX() }
    }

    func tryAX() {
        guard let app = target, !app.isTerminated else { return }
        let pid = app.processIdentifier
        axAttempts += 1
        var obs: AXObserver?
        let created = AXObserverCreate(pid, { _, element, name, _ in
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
            var subrole: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
            log("AX \(name) role=\(role as? String ?? "-") subrole=\(subrole as? String ?? "-")")
        }, &obs)
        guard created == .success, let obs else { log("AXObserverCreate error \(created.rawValue)"); return }
        let element = AXUIElementCreateApplication(pid)
        var errors: [String] = []
        var ok = 0
        for name in [kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification] {
            let r = AXObserverAddNotification(obs, element, name as CFString, nil)
            if r == .success || r == .notificationAlreadyRegistered { ok += 1 } else { errors.append("\(name)=\(r.rawValue)") }
        }
        if ok == 3 {
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
            axObserver = obs
            var windows: CFTypeRef?
            let w = AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &windows)
            log("AX observer registered after \(axAttempts) attempt(s); AXWindows now: err=\(w.rawValue) count=\((windows as? [AnyObject])?.count ?? -1)")
        } else {
            if axAttempts == 1 || axAttempts % 50 == 0 { log("AX add attempt \(axAttempts) failed: \(errors.joined(separator: ", "))") }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.005) { self.tryAX() }
        }
    }

    func startPolling() {
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: .milliseconds(2))
        t.setEventHandler { [weak self] in self?.pollWindows() }
        t.resume()
        poll = t
    }

    func pollWindows() {
        guard let pid = target?.processIdentifier else {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first { adopt(app, via: "poll of runningApplications(withBundleIdentifier:)") }
            return
        }
        guard !(firstAnyWindow && firstLayer0Window) else { return }
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let mine = list.filter { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }
        if !firstAnyWindow, let w = mine.first {
            firstAnyWindow = true
            log("WINDOWLIST first on-screen window: layer=\(w[kCGWindowLayer as String] ?? "?") alpha=\(w[kCGWindowAlpha as String] ?? "?") bounds=\(w[kCGWindowBounds as String] ?? "?")")
        }
        if !firstLayer0Window, let w = mine.first(where: { ($0[kCGWindowLayer as String] as? Int) == 0 }) {
            firstLayer0Window = true
            log("WINDOWLIST first on-screen layer-0 window: alpha=\(w[kCGWindowAlpha as String] ?? "?") bounds=\(w[kCGWindowBounds as String] ?? "?")")
        }
    }
}

let observer = Observer()
let ws = NSWorkspace.shared
let center = ws.notificationCenter
func app(_ n: Notification) -> NSRunningApplication? { n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
for (name, label) in [(NSWorkspace.willLaunchApplicationNotification, "willLaunch"),
                      (NSWorkspace.didLaunchApplicationNotification, "didLaunch"),
                      (NSWorkspace.didActivateApplicationNotification, "didActivate"),
                      (NSWorkspace.didTerminateApplicationNotification, "didTerminate")] {
    center.addObserver(forName: name, object: nil, queue: .main) { n in
        guard let a = app(n), a.bundleIdentifier == bundleID else { return }
        log("NOTE \(label) pid \(a.processIdentifier) isFinishedLaunching=\(a.isFinishedLaunching)")
        observer.adopt(a, via: label)
    }
}
let runningKVO = ws.observe(\.runningApplications, options: [.new, .old]) { _, change in
    let added = (change.newValue ?? []).filter { $0.bundleIdentifier == bundleID }
    let removed = (change.oldValue ?? []).filter { $0.bundleIdentifier == bundleID }
    DispatchQueue.main.async {
        for a in added { log("KVO runningApplications insert pid \(a.processIdentifier) isFinishedLaunching=\(a.isFinishedLaunching)"); observer.adopt(a, via: "runningApplications KVO") }
        for a in removed { log("KVO runningApplications remove pid \(a.processIdentifier)") }
    }
}

func open(_ label: String) {
    let config = NSWorkspace.OpenConfiguration()
    config.activates = true
    config.arguments = appArgs
    ws.openApplication(at: url, configuration: config) { app, error in
        let isMain = Thread.isMainThread
        DispatchQueue.main.async {
            if let error = error as NSError? {
                log("COMPLETION(\(label)) error domain=\(error.domain) code=\(error.code) \(error.localizedDescription) [mainThread=\(isMain)]")
            } else if let app {
                log("COMPLETION(\(label)) pid \(app.processIdentifier) isFinishedLaunching=\(app.isFinishedLaunching) [mainThread=\(isMain)]")
                observer.adopt(app, via: "completion")
            }
        }
    }
    let now = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    log("openApplication(\(label)) returned; runningApplications(withBundleIdentifier:) count=\(now.count) finished=\(now.map(\.isFinishedLaunching))")
}

observer.startPolling()
open("first")
if twice {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
        open("second")
    }
}
DispatchQueue.main.asyncAfter(deadline: .now() + hold) {
    let all = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    log("END instances=\(all.count) pids=\(all.map(\.processIdentifier)) finished=\(all.map(\.isFinishedLaunching))")
    if !wasRunning && !keep {
        for a in all { a.terminate() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            for a in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) { a.forceTerminate() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { exit(0) }
        }
    } else {
        exit(0)
    }
}
_ = runningKVO
RunLoop.main.run()
