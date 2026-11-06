// Stress of WorkspaceActions.hideOtherApps's algorithm, copied verbatim except that `others` is limited to scratch apps,
// so nothing of the user's is ever hidden. Each step brings a scratch app forward, hides the others, then waits a
// random time; a short wait stands in for rapid gestures. After a settle the probe asks: is everything but the app in
// front hidden? It logs why any pending hide was dropped. Arg 1: steps. Arg 2: `current` or `fixed` algorithm.
import AppKit

let ids = ["com.apple.calculator", "com.apple.Dictionary", "com.apple.Chess", "com.apple.TextEdit"]
let paths = ["/System/Applications/Calculator.app", "/System/Applications/Dictionary.app",
             "/System/Applications/Chess.app", "/System/Applications/TextEdit.app"]
func short(_ id: String?) -> String { id?.split(separator: ".").last.map(String.init) ?? "nil" }
func running(_ i: Int) -> NSRunningApplication? { NSRunningApplication.runningApplications(withBundleIdentifier: ids[i]).first }
func pump(_ s: TimeInterval) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }

let steps = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 40 : 40
let fixed = CommandLine.arguments.count > 2 && CommandLine.arguments[2] == "fixed"
var droppedByOther = 0, falseAnswers = 0, leftPending = 0
var activationLog: [String] = []

/// The candidate: one goal; nothing hides until the goal is frontmost; later passes catch a hide that did not land.
@MainActor final class Reconciler {
    var goal: String?
    var serial = 0
    var observer: (any NSObjectProtocol)?
    var repaired = 0

    func hideOthers(than kept: String) {
        goal = kept
        serial += 1
        if observer == nil {
            observer = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
            ) { [weak self] note in
                let id = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
                MainActor.assumeIsolated { self?.activated(id) }
            }
            unhideObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didUnhideApplicationNotification, object: nil, queue: .main
            ) { [weak self] note in
                let id = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
                MainActor.assumeIsolated { self?.activated(id) }
            }
        }
        activated(kept)
        let mine = serial
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            MainActor.assumeIsolated { if self?.serial == mine { self?.goal = nil } }
        }
    }

    var unhideObserver: (any NSObjectProtocol)?

    /// Active is not enough: macOS activates a hidden app before it unhides it, and hiding the last visible app in that
    /// gap makes macOS activate a third app. So both must hold.
    func activated(_ id: String?) {
        guard id == goal, let goal, NSWorkspace.shared.frontmostApplication?.bundleIdentifier == goal,
            NSRunningApplication.runningApplications(withBundleIdentifier: goal).first?.isHidden == false
        else { return }
        arrived()
    }

    func arrived() {
        guard goal != nil else { return }
        sweep(first: true)
        let mine = serial
        for wait in [0.15, 0.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
                MainActor.assumeIsolated { if self?.serial == mine { self?.sweep(first: false) } }
            }
        }
    }

    func sweep(first: Bool) {
        guard let goal, NSWorkspace.shared.frontmostApplication?.bundleIdentifier == goal else { return }
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && !app.isTerminated
            && app.bundleIdentifier != goal && ids.contains(app.bundleIdentifier ?? "") && !app.isHidden {
            if !first { repaired += 1 }
            _ = app.hide()
        }
    }
}

@MainActor final class Hider {
    struct Pending { let app: NSRunningApplication; let kept: String; let observer: any NSObjectProtocol }
    var pending: Pending?

    func hide(_ app: NSRunningApplication) { if !app.hide() { falseAnswers += 1 } }

    func hideOthers(than kept: String) {
        forget()
        let others = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated && $0.bundleIdentifier != kept
                && ids.contains($0.bundleIdentifier ?? "")
        }
        let frontmost = NSWorkspace.shared.frontmostApplication
        let deferred = others.first { $0.processIdentifier == frontmost?.processIdentifier }
        let now = others.filter { $0.processIdentifier != deferred?.processIdentifier }
        Task { @MainActor in for other in now { self.hide(other) } }
        guard let deferred else { return }
        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let id = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated { self?.activated(id) }
        }
        pending = Pending(app: deferred, kept: kept, observer: observer)
    }

    func activated(_ id: String?) {
        guard let p = pending else { return }
        if id == p.kept {
            forget(); hide(p.app)
        } else if fixed {
            return  // Waits for the app being kept.
        } else {
            forget()
            droppedByOther += 1
            print("  DROPPED: wanted \(short(p.kept)), first activation was \(short(id)); \(short(p.app.bundleIdentifier)) stays up")
        }
    }

    func forget() {
        guard let p = pending else { return }
        NSWorkspace.shared.notificationCenter.removeObserver(p.observer)
        pending = nil
    }
}

for i in ids.indices where running(i) != nil { print("ABORT: \(ids[i]) already running"); exit(1) }
let original = NSWorkspace.shared.frontmostApplication
NSApplication.shared.setActivationPolicy(.accessory)
func open(_ i: Int) {
    let c = NSWorkspace.OpenConfiguration(); c.activates = true
    NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: paths[i]), configuration: c)
}
for i in ids.indices { open(i); pump(1.2) }

let maxBurst = CommandLine.arguments.count > 3 ? Int(CommandLine.arguments[3]) ?? 3 : 3
var timeline: [String] = []
var t0 = Date()
func mark(_ s: String) { timeline.append(String(format: "%4.0fms %@", Date().timeIntervalSince(t0) * 1000, s)) }
NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { n in
    mark("activated " + short((n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier))
}
NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didHideApplicationNotification, object: nil, queue: .main) { n in
    mark("hidden " + short((n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier))
}
NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didUnhideApplicationNotification, object: nil, queue: .main) { n in
    mark("unhidden " + short((n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier))
}
let hider = MainActor.assumeIsolated { Hider() }
let reconciler = MainActor.assumeIsolated { Reconciler() }
var rounds = 0, failures = 0, current = -1
var generator = SystemRandomNumberGenerator()
MainActor.assumeIsolated {
    for step in 0..<steps {
        // Bursts of two or three gestures, as rapid tapping does, then a settle and a check.
        let burst = Int.random(in: 1...maxBurst, using: &generator)
        timeline = []; t0 = Date()
        for _ in 0..<burst {
            var target = Int.random(in: 0..<ids.count, using: &generator)
            while target == current { target = Int.random(in: 0..<ids.count, using: &generator) }
            current = target
            mark("GESTURE " + short(ids[target]))
            open(target)
            if fixed { reconciler.hideOthers(than: ids[target]) } else { hider.hideOthers(than: ids[target]) }
            pump(TimeInterval.random(in: 0.02...0.35, using: &generator))
        }
        pump(1.0)
        rounds += 1
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let visible = ids.indices.filter { ids[$0] != front && running($0)?.isHidden == false }.map { short(ids[$0]) }
        if !visible.isEmpty || front != ids[current] {
            failures += 1
            print("FAIL round \(step): wanted \(short(ids[current])) front=\(short(front)) still visible=\(visible)")
            if failures <= 4 { timeline.forEach { print("    " + $0) } }
        }
    }
    if hider.pending != nil { leftPending = 1 }
    hider.forget()
}
MainActor.assumeIsolated { print("repairs by a later pass:", reconciler.repaired) }
print("mode=\(fixed ? "fixed" : "current") rounds=\(rounds) failed=\(failures) droppedByOtherActivation=\(droppedByOther) hideAnsweredFalse=\(falseAnswers) pendingAtEnd=\(leftPending)")
for i in ids.indices { running(i)?.forceTerminate() }
pump(1)
original?.activate()
pump(0.3)
print("restored front:", NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil")
