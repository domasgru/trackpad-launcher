// Probe after the plan review. (1) R7: a swap-shaped series with the hide in the same turn as the open, the frontmost
// app hidden last, reporting the whole ⌘-Tab order unfiltered: does a third app ever get between the two? (2) The cost
// of hide() on a visible app, on an already hidden one, and of the isHidden read. (3) R17: does a panel with
// canHide = false ordered in while this app is hidden show, with defer true and false? (4) unhideWithoutActivation
// after the window was ordered out: does the window stay out, and is the app no longer hidden? Touches only Calculator,
// Dictionary and Chess; aborts if any runs; quits only what it opened; restores the original front app.
import AppKit

typealias CopyOrder = @convention(c) (UInt32) -> Unmanaged<CFArray>?
typealias CopyInfo = @convention(c) (Int32, CFTypeRef, CFArray?) -> Unmanaged<CFDictionary>?
let copyOrder = unsafeBitCast(dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_LSCopyApplicationArrayInFrontToBackOrder"), to: CopyOrder.self)
let copyInfo = unsafeBitCast(dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_LSCopyApplicationInformation"), to: CopyInfo.self)

// Calculator was in use when this ran, so the two others stand in: index 0 is Dictionary, 2 is Chess, 1 unused.
let ids = ["com.apple.Dictionary", "com.apple.Dictionary", "com.apple.Chess"]
let paths = ["/System/Applications/Dictionary.app", "/System/Applications/Dictionary.app", "/System/Applications/Chess.app"]
let started = Date()
func t() -> String { String(format: "%.3f", Date().timeIntervalSince(started)) }
func log(_ s: String) { print("[\(t())] \(s)") }
func app(_ i: Int) -> NSRunningApplication? { NSRunningApplication.runningApplications(withBundleIdentifier: ids[i]).first }
func fullOrder() -> [String] {
    guard let serials = copyOrder(0xFFFF_FFFE)?.takeRetainedValue() as? [CFTypeRef] else { return [] }
    return serials.compactMap { serial in
        let info = copyInfo(-2, serial, ["LSDisplayName", "ApplicationType"] as CFArray)?.takeRetainedValue() as? [String: Any]
        guard info?["ApplicationType"] as? String == "Foreground" else { return nil }
        return info?["LSDisplayName"] as? String
    }
}
func front() -> String { NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil" }
func open(_ i: Int) {
    let c = NSWorkspace.OpenConfiguration(); c.activates = true
    NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: paths[i]), configuration: c)
}
func onScreenWindows(ofPID pid: pid_t) -> Int {
    let all = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return all.filter { ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid }.count
}
func makePanel(defer deferred: Bool, canHide: Bool) -> NSPanel {
    let content = NSView(frame: CGRect(x: 0, y: 0, width: 160, height: 100))
    content.wantsLayer = true
    content.layer!.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.7).cgColor
    let panel = NSPanel(contentRect: CGRect(x: 120, y: 120, width: 160, height: 100), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: deferred)
    panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
    panel.ignoresMouseEvents = true; panel.level = .screenSaver
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    panel.hidesOnDeactivate = false; panel.animationBehavior = .none; panel.isReleasedWhenClosed = false
    panel.contentView = content
    panel.canHide = canHide
    return panel
}

for i in ids.indices where app(i) != nil { print("ABORT: \(ids[i]) already running"); exit(1) }
let original = NSWorkspace.shared.frontmostApplication
let nsapp = NSApplication.shared
nsapp.setActivationPolicy(.accessory)
nsapp.finishLaunching()

Task { @MainActor in
    // (1) R7.
    for i in ids.indices { open(i); try await Task.sleep(for: .seconds(2)) }
    log("start: front=\(front()) order=\(fullOrder())")
    let swaps = [(0, 2), (2, 0), (0, 2), (2, 0)]
    for (target, other) in swaps {
        open(target)
        // Same turn: the non-frontmost scratch app first, the frontmost one last.
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let victims = [other].compactMap(app).filter { !$0.isHidden }
        let ordered = victims.sorted { a, _ in a.processIdentifier != frontPID }
        for v in ordered { _ = v.hide() }
        try await Task.sleep(for: .milliseconds(600))
        log("same-turn swap to \(ids[target].split(separator: ".").last!): front=\(front()) order=\(fullOrder().prefix(5))")
    }
    // The other order, frontmost first, once.
    open(0)
    if let chess = app(2), !chess.isHidden { _ = chess.hide() }
    try await Task.sleep(for: .milliseconds(600))
    log("same-turn, frontmost hidden first, to Calculator: front=\(front()) order=\(fullOrder().prefix(5))")

    // (2) Costs. Dictionary is hidden by now; Chess may be; make Calc visible and front.
    open(0); try await Task.sleep(for: .milliseconds(600))
    open(2); try await Task.sleep(for: .milliseconds(800))
    if let chess = app(2), let calc = app(0) {
        var t0 = DispatchTime.now().uptimeNanoseconds
        let hidden = calc.isHidden
        log(String(format: "isHidden read: %.3f ms (%d)", Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e6, hidden ? 1 : 0))
        t0 = DispatchTime.now().uptimeNanoseconds
        _ = calc.hide()
        log(String(format: "hide() on a visible background app: %.3f ms", Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e6))
        try await Task.sleep(for: .milliseconds(300))
        t0 = DispatchTime.now().uptimeNanoseconds
        _ = calc.hide()
        log(String(format: "hide() on an already hidden app: %.3f ms", Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e6))
        t0 = DispatchTime.now().uptimeNanoseconds
        _ = chess.hide()
        log(String(format: "hide() on the frontmost app: %.3f ms", Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e6))
        try await Task.sleep(for: .milliseconds(600))
        log("after hiding the frontmost with no open: front=\(front()) order=\(fullOrder().prefix(5))")
    }

    // (3) Panels ordered in while this app is hidden.
    nsapp.setActivationPolicy(.regular)
    let window = NSWindow(contentRect: CGRect(x: 320, y: 240, width: 400, height: 200), styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.title = "review probe"; window.isReleasedWhenClosed = false
    window.makeKeyAndOrderFront(nil)
    nsapp.activate()
    try await Task.sleep(for: .milliseconds(600))
    nsapp.hide(nil)
    try await Task.sleep(for: .milliseconds(400))
    let me = ProcessInfo.processInfo.processIdentifier
    log("hidden: isHidden=\(nsapp.isHidden) window.visible=\(window.isVisible) onScreen=\(onScreenWindows(ofPID: me))")
    let deferred = makePanel(defer: true, canHide: false)
    deferred.orderFrontRegardless()
    try await Task.sleep(for: .milliseconds(300))
    log("panel (defer true, canHide false) ordered in while hidden: visible=\(deferred.isVisible) onScreen=\(onScreenWindows(ofPID: me))")
    let immediate = makePanel(defer: false, canHide: false)
    immediate.setFrameOrigin(CGPoint(x: 300, y: 120))
    immediate.orderFrontRegardless()
    try await Task.sleep(for: .milliseconds(300))
    log("panel (defer false, canHide false) ordered in while hidden: visible=\(immediate.isVisible) onScreen=\(onScreenWindows(ofPID: me))")
    let hideable = makePanel(defer: true, canHide: true)
    hideable.setFrameOrigin(CGPoint(x: 480, y: 120))
    hideable.orderFrontRegardless()
    try await Task.sleep(for: .milliseconds(300))
    log("panel (defer true, canHide true) ordered in while hidden: visible=\(hideable.isVisible) onScreen=\(onScreenWindows(ofPID: me))")
    deferred.orderOut(nil); immediate.orderOut(nil); hideable.orderOut(nil)

    // (4) The closed branch: orderOut, accessory, unhideWithoutActivation.
    window.orderOut(nil)
    nsapp.setActivationPolicy(.accessory)
    nsapp.unhideWithoutActivation()
    try await Task.sleep(for: .milliseconds(400))
    log("closed then unhideWithoutActivation: isHidden=\(nsapp.isHidden) window.visible=\(window.isVisible) front=\(front())")
    let later = makePanel(defer: true, canHide: false)
    later.orderFrontRegardless()
    try await Task.sleep(for: .milliseconds(300))
    log("panel ordered in after that: visible=\(later.isVisible) onScreen=\(onScreenWindows(ofPID: me))")
    later.orderOut(nil)

    for i in ids.indices { app(i)?.terminate() }
    try await Task.sleep(for: .milliseconds(1500))
    original?.activate()
    try await Task.sleep(for: .milliseconds(400))
    log("restored front: \(front())")
    exit(0)
}
nsapp.run()
