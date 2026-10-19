// Check P5 (after fan-out): does a Core Animation completion still fire on time when the panel holding the layer
// is entirely off every display, has an empty frame, or is moved off-screen mid-animation, or is ordered out?
// R6 lets the bounce row be cut off entirely at a display's top edge, so a clock layer in that panel must survive it.
import AppKit
import QuartzCore

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

final class Done: NSObject, CAAnimationDelegate {
    let label: String; let start = CACurrentMediaTime()
    init(_ label: String) { self.label = label }
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        print(String(format: "%@: stopped after %.1f ms (expected 2000) finished=%@", label, (CACurrentMediaTime() - start) * 1000, flag ? "true" : "false"))
    }
}
func panel(_ frame: NSRect) -> NSPanel {
    let p = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    p.isOpaque = false; p.backgroundColor = .clear; p.ignoresMouseEvents = true; p.level = .screenSaver
    p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    let v = NSView(frame: NSRect(origin: .zero, size: frame.size)); v.wantsLayer = true; p.contentView = v
    p.orderFrontRegardless()
    return p
}
func hold(_ label: String, on layer: CALayer) {
    let a = CABasicAnimation(keyPath: "opacity"); a.fromValue = 1; a.toValue = 1; a.duration = 2
    a.delegate = Done(label)
    layer.add(a, forKey: "clock")
}

let top = NSScreen.screens.map(\.frame.maxY).max()!
let above = panel(NSRect(x: 100, y: top + 50, width: 60, height: 60))        // entirely above every display
let empty = panel(NSRect(x: 100, y: 100, width: 0, height: 0))               // empty frame
let moved = panel(NSRect(x: 100, y: 100, width: 60, height: 60))            // moved off-screen mid-way
let orderedOut = panel(NSRect(x: 100, y: 100, width: 60, height: 60))       // ordered out mid-way
print("above isVisible=\(above.isVisible) onActiveSpace=\(above.isOnActiveSpace) frame=\(above.frame)")
print("empty isVisible=\(empty.isVisible) frame=\(empty.frame)")

DispatchQueue.main.async {
    hold("(a) panel entirely above every display", on: above.contentView!.layer!)
    hold("(b) panel with an empty frame", on: empty.contentView!.layer!)
    hold("(c) panel moved off-screen at 0.5 s", on: moved.contentView!.layer!)
    hold("(d) panel ordered out at 0.5 s", on: orderedOut.contentView!.layer!)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        moved.setFrameOrigin(NSPoint(x: 100, y: top + 50))
        orderedOut.orderOut(nil)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        for p in [above, empty, moved, orderedOut] { p.close() }
        exit(0)
    }
}
app.run()
