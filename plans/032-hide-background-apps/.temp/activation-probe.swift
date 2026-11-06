// Probe (R12): from an AppKit process like Trackpad Launcher's, what activation pushes does a cold launch produce,
// when does the launched app's first window appear relative to its activation, and what does a user switch to another
// app mid-launch look like? Touches only Calculator and Chess; aborts if either runs; quits only what it opened; restores
// the original front app.
import AppKit

let started = Date()
func t() -> String { String(format: "%.3f", Date().timeIntervalSince(started)) }
func log(_ s: String) { print("[\(t())] \(s)") }

let calcID = "com.apple.calculator", chessID = "com.apple.Chess"
let paths = [calcID: "/System/Applications/Calculator.app", chessID: "/System/Applications/Chess.app"]
func short(_ id: String?) -> String {
    switch id { case calcID: "Calc"; case chessID: "Chess"; case nil: "nil"; default: "OTHER(\(id!))" }
}
func app(_ id: String) -> NSRunningApplication? { NSRunningApplication.runningApplications(withBundleIdentifier: id).first }
func onScreenWindows(of pid: pid_t) -> Int {
    let all = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return all.filter { ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid && (($0[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0) == 0 }.count
}
func front() -> String { short(NSWorkspace.shared.frontmostApplication?.bundleIdentifier) }
func open(_ id: String) {
    let c = NSWorkspace.OpenConfiguration(); c.activates = true
    NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: paths[id]!), configuration: c)
}

for id in [calcID, chessID] where app(id) != nil { print("ABORT: \(id) already running"); exit(1) }
let original = NSWorkspace.shared.frontmostApplication

let nsapp = NSApplication.shared
nsapp.setActivationPolicy(.regular)
nsapp.finishLaunching()
let window = NSWindow(contentRect: CGRect(x: 320, y: 240, width: 400, height: 200), styleMask: [.titled, .closable], backing: .buffered, defer: false)
window.title = "activation probe"; window.isReleasedWhenClosed = false
window.makeKeyAndOrderFront(nil)
nsapp.activate()

let observer = NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
) { note in
    let a = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    log("  didActivate: \(short(a?.bundleIdentifier)) (front now \(front()))")
}

/// Waits until the app's first ordinary window is on screen (polled every 20 ms, probe only) or `limit` passes.
@MainActor func waitForWindow(of id: String, limit: Double) async -> Bool {
    let deadline = Date().addingTimeInterval(limit)
    while Date() < deadline {
        if let a = app(id), onScreenWindows(of: a.processIdentifier) > 0 { return true }
        try? await Task.sleep(for: .milliseconds(20))
    }
    return false
}

Task { @MainActor in
    try await Task.sleep(for: .milliseconds(800))
    log("probe app is front: \(front())")

    log("1. cold launch of Calc from the frontmost app, nothing else happens")
    open(calcID)
    let calcShown = await waitForWindow(of: calcID, limit: 6)
    log("  Calc window on screen: \(calcShown), front now \(front())")
    try await Task.sleep(for: .seconds(3))
    log("  3 s later front: \(front())")

    log("2. cold launch of Chess while this app is an accessory (settings window closed)")
    window.orderOut(nil)
    nsapp.setActivationPolicy(.accessory)
    try await Task.sleep(for: .milliseconds(500))
    log("  front before: \(front())")
    open(chessID)
    let chessShown = await waitForWindow(of: chessID, limit: 6)
    log("  Chess window on screen: \(chessShown), front now \(front())")
    try await Task.sleep(for: .seconds(3))
    log("  3 s later front: \(front())")

    app(chessID)?.terminate()
    try await Task.sleep(for: .seconds(2))
    log("3. cold launch of Chess, then the user clicks Calc in the Dock 150 ms later (activate from this process)")
    nsapp.setActivationPolicy(.regular)
    window.makeKeyAndOrderFront(nil)
    nsapp.activate()
    try await Task.sleep(for: .milliseconds(600))
    log("  front before: \(front())")
    open(chessID)
    try await Task.sleep(for: .milliseconds(150))
    let activated = app(calcID)?.activate() ?? false
    log("  Calc.activate() -> \(activated), front now \(front())")
    let chessShown2 = await waitForWindow(of: chessID, limit: 6)
    log("  Chess window on screen: \(chessShown2), front now \(front())")
    try await Task.sleep(for: .seconds(3))
    log("  3 s later front: \(front())")

    app(chessID)?.terminate()
    try await Task.sleep(for: .seconds(2))
    log("4. cold launch of Chess from an accessory, then the user clicks Calc 150 ms later")
    window.orderOut(nil)
    nsapp.setActivationPolicy(.accessory)
    try await Task.sleep(for: .milliseconds(500))
    open(chessID)
    try await Task.sleep(for: .milliseconds(150))
    let activated2 = app(calcID)?.activate() ?? false
    log("  Calc.activate() -> \(activated2), front now \(front())")
    let chessShown3 = await waitForWindow(of: chessID, limit: 6)
    log("  Chess window on screen: \(chessShown3), front now \(front())")
    try await Task.sleep(for: .seconds(3))
    log("  3 s later front: \(front())")

    log("5. open on an already running app (Calc) from an accessory: activations?")
    open(calcID)
    try await Task.sleep(for: .seconds(2))
    log("  front: \(front())")

    NSWorkspace.shared.notificationCenter.removeObserver(observer)
    for id in [calcID, chessID] { app(id)?.terminate() }
    try await Task.sleep(for: .milliseconds(1500))
    original?.activate()
    try await Task.sleep(for: .milliseconds(500))
    log("restored front: \(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil")")
    exit(0)
}
nsapp.run()
