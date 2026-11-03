// Check C6 (Phase C, test planner finding 8): does the glass mirror get built when the panel is pre-warmed invisibly?
// A deferred panel (as OverlayPanel's) is ordered front once with its content layer at opacity 0 (mode "layer") or
// with the window's alphaValue 0 (mode "window"), flushed, the 12 elements matched by frame, ordered out. Later, a
// "swipe": re-lay out for 4 apps (spares over the band), opacity back to 1, ordered front, flushed: are the matched
// layers still live and at their views' frames? Also captures the screen region during the pre-warm, to see it shows
// nothing.
//
// Build: swiftc -swift-version 5 -parse-as-library -O c6-zero-opacity-prewarm.swift -o /tmp/tl-check-024/c6
// Run:   /tmp/tl-check-024/c6 <layer|window> <outdir>

import AppKit
import QuartzCore

func allLayers(_ l: CALayer) -> [CALayer] { [l] + (l.sublayers ?? []).flatMap(allLayers) }
func elements(_ root: CALayer) -> [CALayer] { allLayers(root).filter { NSStringFromClass(type(of: $0)) == "CASDFElementLayer" } }

@main
struct Check {
    static func main() {
        let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "layer"
        let outDir = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "/tmp/tl-check-024/out"
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let size = NSSize(width: 1100, height: 180)
        let screen = NSScreen.main!.frame
        let rect = NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2, width: size.width, height: size.height)
        let panel = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.level = .floating; panel.hasShadow = true
        let root = NSView(frame: NSRect(origin: .zero, size: size))
        root.wantsLayer = true
        let container = NSGlassEffectContainerView(frame: root.bounds)
        container.spacing = 40
        let content = NSView(frame: container.bounds)
        container.contentView = content
        root.addSubview(container)
        let band = NSGlassEffectView(); band.cornerRadius = 26
        let beads = (0..<10).map { _ in NSGlassEffectView() }
        let swell = NSGlassEffectView(); swell.cornerRadius = 33
        let all = [band] + beads + [swell]
        all.forEach(content.addSubview)
        panel.contentView = root

        func layOut(count: Int, selected: Int) {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            let last = count - 1
            band.frame = NSRect(x: 90, y: 64, width: max(CGFloat(last) * 100, 1), height: 52)
            for (i, b) in beads.enumerated() {
                b.frame = i < count ? NSRect(x: 50 + CGFloat(i) * 100, y: 50, width: 80, height: 80) : band.frame
                b.cornerRadius = i < count ? 25.6 : 26
            }
            swell.frame = NSRect(x: 38 + CGFloat(selected) * 100, y: 38, width: 104, height: 104)
            CATransaction.commit()
        }
        func capture(_ name: String) {
            let mainH = NSScreen.screens[0].frame.height
            let r = "\(Int(rect.minX)),\(Int(mainH - rect.maxY)),\(Int(rect.width)),\(Int(rect.height))"
            let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            p.arguments = ["-x", "-R", r, "\(outDir)/c6-\(mode)-\(name).png"]
            try? p.run(); p.waitUntilExit()
        }

        // Pre-warm, invisibly.
        layOut(count: 10, selected: 0)
        if mode == "window" { panel.alphaValue = 0 } else {
            CATransaction.begin(); CATransaction.setDisableActions(true); root.layer!.opacity = 0; CATransaction.commit()
        }
        panel.orderFrontRegardless()
        CATransaction.flush()
        let els = elements(container.layer!)
        var matched: [ObjectIdentifier: CALayer] = [:]
        for v in all {
            let hits = els.filter { abs($0.frame.minX - v.frame.minX) < 0.5 && abs($0.frame.minY - v.frame.minY) < 0.5 && abs($0.frame.width - v.frame.width) < 0.5 && abs($0.frame.height - v.frame.height) < 0.5 }
            if hits.count == 1 { matched[ObjectIdentifier(v)] = hits[0] }
        }
        print("mode=\(mode) pre-warm at zero opacity: elements=\(els.count), matched uniquely=\(matched.count)/12")
        capture("prewarm-visible")       // should show nothing of ours
        panel.orderOut(nil)

        func verify(_ label: String) {
            let tree = Set(elements(container.layer!).map(ObjectIdentifier.init))
            var live = 0, placed = 0
            for v in all {
                guard let l = matched[ObjectIdentifier(v)] else { continue }
                if tree.contains(ObjectIdentifier(l)) { live += 1 }
                if abs(l.frame.minX - v.frame.minX) < 0.5 && abs(l.frame.width - v.frame.width) < 0.5 && abs(l.frame.height - v.frame.height) < 0.5 { placed += 1 }
            }
            print("\(label): elements in tree=\(tree.count), matched live=\(live)/\(matched.count), at their view's frame=\(placed)/\(matched.count)")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // A swipe: lay out while ordered out, opacity 1, order front, flush.
            layOut(count: 4, selected: 1)
            if mode == "window" { panel.alphaValue = 1 } else {
                CATransaction.begin(); CATransaction.setDisableActions(true); root.layer!.opacity = 1; CATransaction.commit()
            }
            panel.orderFrontRegardless()
            CATransaction.flush()
            verify("first swipe right after orderFront + flush")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                verify("first swipe 0.5 s later")
                capture("first-swipe")
                app.terminate(nil)
            }
        }
        app.run()
    }
}
