// Probe P1: does NSGlassEffectContainerView merge NSGlassEffectViews into one liquid shape,
// and does that merge follow a Core Animation animation on a child's layer with no app code
// running per display frame?
//
// Build: swiftc -swift-version 5 -parse-as-library -O p1-glass-merge.swift -o /tmp/tl-probe-024/p1
// Run:   /tmp/tl-probe-024/p1 /tmp/tl-probe-024/out
// Prints the layer tree before and during the animation, the main run loop's wake-ups during a
// 1.2 s render-server animation, and saves window captures at rest and mid-animation.

import AppKit
import QuartzCore

final class WakeCounter {
    var count = 0
    var observer: CFRunLoopObserver?
    func start() {
        count = 0
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

final class CountingView: NSView {
    static var layouts = 0
    static var draws = 0
    override func layout() { CountingView.layouts += 1; super.layout() }
    override func draw(_ r: NSRect) { CountingView.draws += 1 }
}

func dump(_ layer: CALayer, _ depth: Int = 0) {
    let pad = String(repeating: "  ", count: depth)
    var extras: [String] = []
    if let f = layer.filters, !f.isEmpty { extras.append("filters=\(f.map { String(describing: $0) })") }
    if let c = layer.compositingFilter { extras.append("compositingFilter=\(c)") }
    if layer.mask != nil { extras.append("mask=\(type(of: layer.mask!))") }
    if layer.cornerRadius > 0 { extras.append("cornerRadius=\(layer.cornerRadius)") }
    if let n = layer.name { extras.append("name=\(n)") }
    if let keys = layer.animationKeys(), !keys.isEmpty { extras.append("anims=\(keys)") }
    print("\(pad)\(type(of: layer)) frame=\(layer.frame) \(extras.joined(separator: " "))")
    for s in layer.sublayers ?? [] { dump(s, depth + 1) }
}

@main
struct Probe {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/tl-probe-024/out"
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

        let size = NSSize(width: 520, height: 180)
        let screen = NSScreen.main!.frame
        let rect = NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2, width: size.width, height: size.height)
        let panel = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = false

        // A striped backdrop so glass refraction is visible in captures.
        let root = NSView(frame: NSRect(origin: .zero, size: size))
        root.wantsLayer = true
        let stripes = CALayer()
        stripes.frame = root.bounds
        stripes.backgroundColor = NSColor.white.cgColor
        for i in 0..<26 {
            let s = CALayer()
            s.frame = NSRect(x: CGFloat(i) * 20, y: 0, width: 8, height: size.height)
            s.backgroundColor = NSColor.systemGray.withAlphaComponent(0.6).cgColor
            stripes.addSublayer(s)
        }
        root.layer!.addSublayer(stripes)

        let container = NSGlassEffectContainerView(frame: root.bounds)
        container.spacing = Double(CommandLine.arguments.count > 2 ? Double(CommandLine.arguments[2])! : 24)
        let content = CountingView(frame: root.bounds)
        container.contentView = content
        root.addSubview(container)

        // Five beads 60 pt, 16 pt apart; the third is the swell (88 pt).
        var beads: [NSGlassEffectView] = []
        for i in 0..<5 {
            let d: CGFloat = i == 2 ? 88 : 60
            let cx: CGFloat = 60 + CGFloat(i) * 76
            let g = NSGlassEffectView(frame: NSRect(x: cx - d / 2, y: 90 - d / 2, width: d, height: d))
            g.cornerRadius = d / 2
            content.addSubview(g)
            beads.append(g)
        }
        panel.contentView = root
        panel.orderFrontRegardless()

        func capture(_ name: String) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            p.arguments = ["-x", "-o", "-l", String(panel.windowNumber), "\(outDir)/\(name).png"]
            try? p.run()
            p.waitUntilExit()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("=== layer tree at rest (spacing \(container.spacing)) ===")
            dump(root.layer!)
            print("layouts so far=\(CountingView.layouts) draws=\(CountingView.draws)")
            capture("rest")

            // Render-server animation: move bead 4 (index 3) left into the swell and back, on its layer.
            let moving = beads[3]
            let layer = moving.layer!
            let a = CABasicAnimation(keyPath: "position.x")
            a.fromValue = layer.position.x
            a.toValue = layer.position.x - 50
            a.duration = 1.2
            a.autoreverses = false
            a.fillMode = .forwards
            a.isRemovedOnCompletion = false
            let counter = WakeCounter()
            let layoutsBefore = CountingView.layouts
            counter.start()
            layer.add(a, forKey: "probe-move")

            // A second, bounds animation on the swell: grow width (as a stretch would).
            let swell = beads[2].layer!
            let b = CABasicAnimation(keyPath: "bounds.size.width")
            b.fromValue = swell.bounds.width
            b.toValue = swell.bounds.width + 60
            b.duration = 1.2
            b.fillMode = .forwards
            b.isRemovedOnCompletion = false
            swell.add(b, forKey: "probe-stretch")

            // Capture mid-animation from a background thread so the main thread stays idle.
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.6) {
                capture("mid")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                print("=== layer tree mid-animation ===")
                dump(root.layer!)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                let wakes = counter.stop()
                print("main run loop wake-ups during the 1.2 s animation (includes the probe's own 3 timers + 1 dump): \(wakes)")
                print("layouts during animation: \(CountingView.layouts - layoutsBefore)")
                capture("end")
                // Now the same via a model change: set the frame (no animation) to see the merge result at the end state.
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0
                    moving.frame.origin.x -= 50
                    beads[2].frame.size.width += 60
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    capture("model-end")
                    print("=== layer tree after model change ===")
                    dump(root.layer!)
                    app.terminate(nil)
                }
            }
        }
        app.run()
    }
}
