// Check C1 (after fan-out): the private glass mirror's lifecycle, for the designs' open risks.
//  (a) Does the CASDFElementLayer mirror exist before the panel is first ordered front, right after
//      orderFrontRegardless, after a CATransaction.flush, after one run loop turn?
//  (b) A glass view parked far outside the window: is it mirrored, and does it grow the SDF/backdrop bounds?
//  (c) A hidden glass view (isHidden = true): is its element dropped from the mirror (identity churn)?
//  (d) After orderOut and a new orderFront, are the element layers the same objects?
//
// Build: swiftc -swift-version 5 -parse-as-library -O c1-mirror-lifecycle.swift -o /tmp/tl-check-024/c1
// Run:   /tmp/tl-check-024/c1

import AppKit
import QuartzCore

func allLayers(_ l: CALayer) -> [CALayer] { [l] + (l.sublayers ?? []).flatMap(allLayers) }
func named(_ root: CALayer, _ cls: String) -> [CALayer] { allLayers(root).filter { NSStringFromClass(type(of: $0)) == cls } }

@main
struct Check {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let size = NSSize(width: 520, height: 180)
        let screen = NSScreen.main!.frame
        let rect = NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2, width: size.width, height: size.height)
        let panel = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        let container = NSGlassEffectContainerView(frame: NSRect(origin: .zero, size: size))
        container.spacing = 40
        let content = NSView(frame: container.bounds)
        container.contentView = content
        var views: [NSGlassEffectView] = []
        for i in 0..<4 {
            let g = NSGlassEffectView(frame: NSRect(x: 40 + CGFloat(i) * 90, y: 50, width: 80, height: 80)); g.cornerRadius = 26
            content.addSubview(g); views.append(g)
        }
        let parked = NSGlassEffectView(frame: NSRect(x: 4000, y: 50, width: 80, height: 80)); parked.cornerRadius = 26
        content.addSubview(parked)
        panel.contentView = container

        func report(_ label: String) {
            guard let root = container.layer else { print("\(label): container has no layer"); return }
            let els = named(root, "CASDFElementLayer")
            let sdf = named(root, "CASDFLayer").map { $0.frame }
            let backdrops = named(root, "CABackdropLayer").map { $0.frame }
            print("\(label): elements=\(els.count) frames=\(els.map { $0.frame.origin.x }.sorted()) CASDFLayer=\(sdf) backdrop=\(backdrops)")
        }
        report("(a) before any orderFront")
        panel.orderFrontRegardless()
        report("(a) right after orderFrontRegardless")
        CATransaction.flush()
        report("(a) after CATransaction.flush")
        func ids() -> [CGFloat: ObjectIdentifier] {
            var m: [CGFloat: ObjectIdentifier] = [:]
            for e in named(container.layer!, "CASDFElementLayer") { m[e.frame.origin.x] = ObjectIdentifier(e) }
            return m
        }
        func after(_ turns: Int, _ body: @escaping () -> Void) {
            if turns == 0 { body() } else { DispatchQueue.main.async { after(turns - 1, body) } }
        }
        after(1) {
            report("(a) after one run loop turn")
            let first = ids()
            views[3].isHidden = true                                    // the view at x = 310
            after(2) {
                let hidden = ids()
                print("(c) isHidden: elements at x=\(hidden.keys.sorted()); others kept identity=\([40, 130, 220].allSatisfy { hidden[$0] == first[$0] })")
                views[3].isHidden = false
                after(3) {
                    let shown = ids()
                    print("(c) unhidden: elements at x=\(shown.keys.sorted()); x=310 same object as before hiding=\(shown[310] == first[310]); others kept identity=\([40, 130, 220].allSatisfy { shown[$0] == first[$0] })")
                    parked.removeFromSuperview()
                    after(2) {
                        report("(b) after removing the parked view")
                        let before = ids()
                        panel.orderOut(nil)
                        after(2) {
                            panel.orderFrontRegardless()
                            CATransaction.flush()
                            let again = ids()
                            print("(d) right after orderOut + orderFront + flush: every element the same object=\(again == before) (\(again.count) elements)")
                            after(3) {
                                print("(d) three turns later: every element the same object=\(ids() == before)")
                                app.terminate(nil)
                            }
                        }
                    }
                }
            }
        }
        app.run()
    }
}
