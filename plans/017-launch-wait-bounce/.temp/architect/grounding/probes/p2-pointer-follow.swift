// Probe P2: can an unpermissioned process follow the pointer by push, and what does each step cost?
// 1. Installs NSEvent global and local monitors for mouse moves and drags (no Input Monitoring here:
//    CGPreflightListenEventAccess is false in this context).
// 2. Posts 60 synthetic mouse-moved events at the pointer's current location (zero motion, so the
//    pointer does not move) and counts what each monitor receives, with the delay from the event's
//    timestamp to the handler.
// 3. Times moving a small click-through panel with setFrameOrigin, and moving a layer inside a
//    display-sized panel with actions disabled, 2000 times each.
// Leaves nothing behind: the panels close, the pointer never moves.
import AppKit
import QuartzCore

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

var global: [Double] = []
var local: [Double] = []
func delay(_ e: NSEvent) -> Double { (ProcessInfo.processInfo.systemUptime - e.timestamp) * 1000 }
let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
let g = NSEvent.addGlobalMonitorForEvents(matching: mask) { e in global.append(delay(e)) }
let l = NSEvent.addLocalMonitorForEvents(matching: mask) { e in local.append(delay(e)); return e }
print("global monitor installed:", g != nil, " local:", l != nil, " listenAccess:", CGPreflightListenEventAccess())

func panel(_ frame: NSRect) -> NSPanel {
    let p = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    p.isOpaque = false; p.backgroundColor = .clear; p.ignoresMouseEvents = true; p.level = .screenSaver
    p.hasShadow = false; p.animationBehavior = .none
    p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    let v = NSView(frame: NSRect(origin: .zero, size: frame.size)); v.wantsLayer = true
    p.contentView = v
    return p
}

DispatchQueue.main.async {
    // Step 2: synthetic zero-motion moves.
    let here = CGEvent(source: nil)!.location   // Quartz coordinates, y down
    for i in 0..<60 {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.008) {
            CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: here, mouseButton: .left)?.post(tap: .cghidEventTap)
        }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
        func stats(_ a: [Double]) -> String {
            guard !a.isEmpty else { return "n=0" }
            let s = a.sorted()
            return String(format: "n=%d median=%.2f ms p90=%.2f ms max=%.2f ms", s.count, s[s.count / 2], s[Int(Double(s.count) * 0.9)], s.last!)
        }
        print("posted 60 zero-motion moves at", here)
        print("global monitor:", stats(global))
        print("local monitor:", stats(local))

        // Step 3: cost of moving a small panel vs a layer in a display-sized panel.
        let screen = NSScreen.screens[0].frame
        let small = panel(NSRect(x: 100, y: 100, width: 84, height: 120))
        small.orderFrontRegardless()
        var t = CACurrentMediaTime()
        for i in 0..<2000 { small.setFrameOrigin(NSPoint(x: 100 + Double(i % 400), y: 100 + Double(i % 300))) }
        let smallCost = (CACurrentMediaTime() - t) / 2000 * 1000
        small.close()

        let big = panel(screen)
        big.orderFrontRegardless()
        let layer = CALayer(); layer.bounds = CGRect(x: 0, y: 0, width: 60, height: 60); layer.backgroundColor = NSColor.clear.cgColor
        big.contentView!.layer!.addSublayer(layer)
        t = CACurrentMediaTime()
        for i in 0..<2000 {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            layer.position = CGPoint(x: 100 + Double(i % 400), y: 100 + Double(i % 300))
            CATransaction.commit()
            CATransaction.flush()
        }
        let layerCost = (CACurrentMediaTime() - t) / 2000 * 1000
        big.close()
        print(String(format: "setFrameOrigin on an 84x120 panel: %.3f ms per move", smallCost))
        print(String(format: "layer move + commit + flush in a display-sized panel: %.3f ms per move", layerCost))
        if let g { NSEvent.removeMonitor(g) }
        if let l { NSEvent.removeMonitor(l) }
        exit(0)
    }
}
app.run()
