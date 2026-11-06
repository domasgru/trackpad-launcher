// Probe (R14–R17, R10–R11 clock): an AppKit process with a Dock icon hides itself with NSApp.hide while a
// non-activating overlay panel with canHide = false stays up; its window comes back at the same frame on unhide; the
// close/reopen sequence the shell runs works from the hidden state; and Core Animation deadlines complete on (a) a
// detached layer, (b) a layer in a panel never ordered in, (c) a layer in a 1 × 1 ordered-in panel, (d) a layer in the
// overlay panel while the app is hidden. Touches no other app; restores the original front app.
import AppKit
import QuartzCore

let started = Date()
func t() -> String { String(format: "%.3f", Date().timeIntervalSince(started)) }
func log(_ s: String) { print("[\(t())] \(s)") }

final class Stop: NSObject, CAAnimationDelegate {
    let label: String
    let added = Date()
    init(_ label: String) { self.label = label }
    func animationDidStop(_ animation: CAAnimation, finished: Bool) {
        print("[\(t())] deadline '\(label)' stopped finished=\(finished) after \(String(format: "%.3f", Date().timeIntervalSince(added))) s")
    }
}
var stops: [Stop] = []
func deadline(on layer: CALayer, _ seconds: Double, _ label: String) {
    let a = CABasicAnimation(keyPath: "opacity")
    a.fromValue = Float(1); a.toValue = Float(1); a.duration = seconds
    let stop = Stop(label); stops.append(stop); a.delegate = stop
    layer.add(a, forKey: label)
}
func makePanel(_ frame: CGRect, canHide: Bool) -> (NSPanel, CALayer) {
    let content = NSView(frame: CGRect(origin: .zero, size: frame.size))
    content.wantsLayer = true
    let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
    panel.ignoresMouseEvents = true; panel.level = .screenSaver
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    panel.hidesOnDeactivate = false; panel.animationBehavior = .none; panel.isReleasedWhenClosed = false
    panel.contentView = content
    panel.canHide = canHide
    return (panel, content.layer!)
}

let original = NSWorkspace.shared.frontmostApplication
let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.finishLaunching()

let window = NSWindow(contentRect: CGRect(x: 320, y: 240, width: 400, height: 260), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
window.title = "self-hide probe"; window.isReleasedWhenClosed = false
window.makeKeyAndOrderFront(nil)
app.activate()

let (overlay, overlayLayer) = makePanel(CGRect(x: 100, y: 100, width: 200, height: 120), canHide: false)
overlay.contentView!.layer!.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.6).cgColor
overlay.orderFrontRegardless()
let (plainPanel, _) = makePanel(CGRect(x: 320, y: 100, width: 200, height: 120), canHide: true)
plainPanel.contentView!.layer!.backgroundColor = NSColor.systemRed.withAlphaComponent(0.6).cgColor
plainPanel.orderFrontRegardless()

let detached = CALayer()
let (neverShown, neverShownLayer) = makePanel(CGRect(x: 0, y: 0, width: 1, height: 1), canHide: false)
let (tiny, tinyLayer) = makePanel(CGRect(x: 0, y: 0, width: 1, height: 1), canHide: false)
tiny.orderFrontRegardless()

Task { @MainActor in
    try await Task.sleep(for: .milliseconds(600))
    log("before hide: NSApp.isHidden=\(app.isHidden) window.visible=\(window.isVisible) overlay.visible=\(overlay.isVisible) plain.visible=\(plainPanel.isVisible) frame=\(window.frame)")
    log("front=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil")")
    deadline(on: detached, 1.0, "a detached layer")
    deadline(on: neverShownLayer, 1.0, "b never-shown panel")
    deadline(on: tinyLayer, 1.0, "c 1x1 shown panel")
    deadline(on: overlayLayer, 1.0, "d overlay panel, added before hide")
    try await Task.sleep(for: .milliseconds(100))

    app.hide(nil)
    try await Task.sleep(for: .milliseconds(400))
    log("after NSApp.hide: NSApp.isHidden=\(app.isHidden) current.isHidden=\(NSRunningApplication.current.isHidden) window.visible=\(window.isVisible) overlay.visible=\(overlay.isVisible) plain.visible=\(plainPanel.isVisible) policy=\(app.activationPolicy().rawValue)")
    log("front now=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil")")
    deadline(on: overlayLayer, 0.5, "e overlay panel, added while hidden")
    deadline(on: tinyLayer, 0.5, "f 1x1 shown panel, added while hidden")
    try await Task.sleep(for: .milliseconds(1500))

    // Does makeKeyAndOrderFront + activate alone unhide?
    window.makeKeyAndOrderFront(nil)
    app.activate()
    try await Task.sleep(for: .milliseconds(500))
    log("after makeKeyAndOrderFront+activate: isHidden=\(app.isHidden) window.visible=\(window.isVisible) frame=\(window.frame) front=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil")")
    if app.isHidden {
        app.unhide(nil)
        try await Task.sleep(for: .milliseconds(400))
        log("after NSApp.unhide: isHidden=\(app.isHidden) window.visible=\(window.isVisible) frame=\(window.frame)")
    }

    // NSRunningApplication.current.hide() on self.
    let answer = NSRunningApplication.current.hide()
    try await Task.sleep(for: .milliseconds(400))
    log("after current.hide() -> \(answer): isHidden=\(app.isHidden) window.visible=\(window.isVisible) overlay.visible=\(overlay.isVisible)")

    // The shell's close while hidden (Dock's Quit), then a reopen: orderOut, accessory; regular, unhide, front, activate.
    window.orderOut(nil)
    app.setActivationPolicy(.accessory)
    try await Task.sleep(for: .milliseconds(400))
    log("closed while hidden: isHidden=\(app.isHidden) policy=\(app.activationPolicy().rawValue) window.visible=\(window.isVisible)")
    app.setActivationPolicy(.regular)
    app.unhide(nil)
    window.makeKeyAndOrderFront(nil)
    app.activate()
    try await Task.sleep(for: .milliseconds(600))
    log("reopened: isHidden=\(app.isHidden) window.visible=\(window.isVisible) frame=\(window.frame) front=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil")")

    // Hide while accessory (window closed): harmless?
    window.orderOut(nil)
    app.setActivationPolicy(.accessory)
    app.hide(nil)
    try await Task.sleep(for: .milliseconds(400))
    log("hidden while accessory: isHidden=\(app.isHidden) overlay.visible=\(overlay.isVisible)")
    app.setActivationPolicy(.regular)
    app.unhide(nil)
    window.makeKeyAndOrderFront(nil)
    app.activate()
    try await Task.sleep(for: .milliseconds(600))
    log("reopened after accessory hide: isHidden=\(app.isHidden) window.visible=\(window.isVisible) front=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil")")

    window.orderOut(nil); overlay.orderOut(nil); plainPanel.orderOut(nil); tiny.orderOut(nil)
    app.setActivationPolicy(.accessory)
    original?.activate()
    try await Task.sleep(for: .milliseconds(400))
    log("restored front: \(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil")")
    exit(0)
}
app.run()
