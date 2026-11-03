// Probe P6: the cost of per-input-event geometry updates on a merged glass shape, as during a swipe.
// Simulates 100 input events per second for 2 s (the plans' ~100 Hz trackpad frames; a dispatch timer
// stands in for the frame thread here only, never in shipped code). Each event moves the swell and
// nudges every bead, on a row of ten beads, nine necks, a band and a swell (21 glass views).
//   mode "views":    public NSGlassEffectView frame sets in a no-actions transaction (AppKit mirrors them)
//   mode "elements": the same geometry written straight onto the mirrored CASDFElementLayers
//   mode "additive": the same geometry as keyed, held additive animations on those element layers
//                    (offset from the view's frame; replaced each event), which survive AppKit's re-sync
// Prints process CPU and main run loop wake-ups over the 2 s; then, in "elements" mode, whether AppKit
// later re-syncs the element geometry from the views (layout pass, another view frame change, appearance).
//
// Build: swiftc -swift-version 5 -parse-as-library -O p6-per-event-cost.swift -o /tmp/tl-probe-024/p6
// Run:   /tmp/tl-probe-024/p6 <views|elements|additive>

import AppKit
import QuartzCore

func cpuMS() -> Double {
    var u = rusage()
    getrusage(RUSAGE_SELF, &u)
    return Double(u.ru_utime.tv_sec + u.ru_stime.tv_sec) * 1000 + Double(u.ru_utime.tv_usec + u.ru_stime.tv_usec) / 1000
}

final class WakeCounter {
    var count = 0
    var observer: CFRunLoopObserver?
    func start() {
        observer = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.afterWaiting.rawValue, true, 0) { [weak self] _, _ in
            self?.count += 1
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
    }
    func stop() -> Int {
        if let o = observer { CFRunLoopRemoveObserver(CFRunLoopGetMain(), o, .commonModes) }
        return count
    }
}

func allLayers(_ l: CALayer) -> [CALayer] { [l] + (l.sublayers ?? []).flatMap(allLayers) }

/// A held additive offset on an element layer: from == to, effectively forever, replaced under its key.
func hold(_ layer: CALayer?, dy: CGFloat, dh: CGFloat, dx: CGFloat, dw: CGFloat) {
    guard let layer else { return }
    func put(_ keyPath: String, _ v: CGFloat) {
        let a = CABasicAnimation(keyPath: keyPath)
        a.isAdditive = true
        a.fromValue = v
        a.toValue = v
        a.duration = 1e6
        layer.add(a, forKey: "hold-" + keyPath)
    }
    if dx != 0 { put("position.x", dx + dw / 2) }
    if dw != 0 { put("bounds.size.width", dw) }
    if dh != 0 { put("bounds.size.height", dh) }
    if dy != 0 { put("position.y", dy) }
}

@main
struct Probe {
    static func main() {
        let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "views"
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let size = NSSize(width: 1040, height: 160)
        let screen = NSScreen.main!.frame
        let rect = NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2, width: size.width, height: size.height)
        let panel = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = true
        let container = NSGlassEffectContainerView(frame: NSRect(origin: .zero, size: size))
        container.spacing = 40
        let content = NSView(frame: container.bounds)
        container.contentView = content
        var views: [NSGlassEffectView] = []
        func add(_ r: NSRect, _ radius: CGFloat) -> NSGlassEffectView {
            let g = NSGlassEffectView(frame: r); g.cornerRadius = radius
            content.addSubview(g); views.append(g); return g
        }
        _ = add(NSRect(x: 60, y: 54, width: 920, height: 52), 26)            // band
        var beads: [NSGlassEffectView] = []
        for i in 0..<10 { beads.append(add(NSRect(x: 70 + CGFloat(i) * 100 - 0, y: 40, width: 80, height: 80), 26)) }
        for i in 0..<9 { _ = add(NSRect(x: 150 + CGFloat(i) * 100, y: 62, width: 20, height: 36), 10) }   // necks
        let swell = add(NSRect(x: 58, y: 28, width: 104, height: 104), 34)
        panel.contentView = container
        panel.orderFrontRegardless()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            var elementFor: [ObjectIdentifier: CALayer] = [:]
            let els = allLayers(container.layer!).filter { NSStringFromClass(type(of: $0)) == "CASDFElementLayer" }
            for v in views {
                if let e = els.first(where: { abs($0.frame.minX - v.frame.minX) < 0.5 && abs($0.frame.minY - v.frame.minY) < 0.5 && abs($0.frame.width - v.frame.width) < 0.5 && abs($0.frame.height - v.frame.height) < 0.5 }) {
                    elementFor[ObjectIdentifier(v)] = e
                }
            }
            print("mode=\(mode) glass views=\(views.count) element layers=\(els.count) matched=\(elementFor.count)")
            let counter = WakeCounter()
            let cpu0 = cpuMS()
            counter.start()
            var n = 0
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now(), repeating: .milliseconds(10))
            timer.setEventHandler {
                n += 1
                let t = CGFloat(n) / 100
                let swellX = 58 + (t * 450).truncatingRemainder(dividingBy: 900)
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                for (i, b) in beads.enumerated() {
                    let wob = 4 * sin(t * 12 + CGFloat(i))
                    let r = NSRect(x: 70 + CGFloat(i) * 100, y: 40 - wob / 2, width: 80, height: 80 + wob)
                    if mode == "views" { b.frame = r }
                    else if mode == "additive" { hold(elementFor[ObjectIdentifier(b)], dy: 0, dh: wob, dx: 0, dw: 0) }
                    else { elementFor[ObjectIdentifier(b)]?.frame = r }
                }
                let sr = NSRect(x: swellX, y: 28, width: 104 + 10 * sin(t * 9), height: 104)
                if mode == "views" { swell.frame = sr }
                else if mode == "additive" { hold(elementFor[ObjectIdentifier(swell)], dy: 0, dh: 0, dx: swellX - 58, dw: 10 * sin(t * 9)) }
                else { elementFor[ObjectIdentifier(swell)]?.frame = sr }
                CATransaction.commit()
                if n == 200 {
                    timer.cancel()
                    let wakes = counter.stop()
                    print("mode=\(mode) 200 events over 2 s: process CPU \(String(format: "%.1f", cpuMS() - cpu0)) ms, main wake-ups \(wakes) (the event source alone is 200)")
                    let swellEl = elementFor[ObjectIdentifier(swell)]
                    print("right after: swell view frame=\(swell.frame) element frame=\(swellEl?.frame ?? .zero)")
                    // Does AppKit later re-sync element geometry from the views (clobbering direct writes)?
                    // Trigger the usual suspects: a layout pass, an unrelated view frame change, appearance change.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        content.needsLayout = true
                        content.layoutSubtreeIfNeeded()
                        views[0].frame.size.width += 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            print("after layout + band frame change: swell element frame=\(swellEl?.frame ?? .zero)")
                            NSApp.appearance = NSAppearance(named: .darkAqua)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                print("after appearance change: swell element frame=\(swellEl?.frame ?? .zero) still in tree=\(allLayers(container.layer!).contains { $0 === swellEl })")
                                app.terminate(nil)
                            }
                        }
                    }
                }
            }
            timer.resume()
        }
        app.run()
    }
}
