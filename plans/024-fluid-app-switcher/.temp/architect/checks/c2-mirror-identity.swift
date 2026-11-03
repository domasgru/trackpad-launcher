// Check C2 (after fan-out): with a FIXED set of glass views, does a frame-matched mirror stay valid across swipes?
// Twelve views (band, ten beads, swell) matched once while every frame is distinct. Then, per "swipe": orderOut,
// re-lay out for a shorter row by frame sets only (spare beads coincident with the last real bead, so the union is
// unchanged), orderFront + flush, and check that every matched layer is still in the tree and sits at its view's frame.
// Also: does isHidden on a spare bead drop its element, measured after 0.3 s rather than run loop turns?
// And what are the CASDFLayer bounds with coincident spares?
//
// Build: swiftc -swift-version 5 -parse-as-library -O c2-mirror-identity.swift -o /tmp/tl-check-024/c2
// Run:   /tmp/tl-check-024/c2

import AppKit
import QuartzCore

func allLayers(_ l: CALayer) -> [CALayer] { [l] + (l.sublayers ?? []).flatMap(allLayers) }
func elements(_ root: CALayer) -> [CALayer] { allLayers(root).filter { NSStringFromClass(type(of: $0)) == "CASDFElementLayer" } }
func sdfBounds(_ root: CALayer) -> [CGRect] { allLayers(root).filter { NSStringFromClass(type(of: $0)) == "CASDFLayer" }.map(\.frame) }

@main
struct Check {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let size = NSSize(width: 1040, height: 160)
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
        let band = NSGlassEffectView(); band.cornerRadius = 26
        let beads = (0..<10).map { _ in NSGlassEffectView() }
        let swell = NSGlassEffectView(); swell.cornerRadius = 40
        let all = [band] + beads + [swell]
        all.forEach(content.addSubview)
        panel.contentView = container

        func layOut(count: Int, selected: Int) {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            let last = count - 1
            band.frame = NSRect(x: 60, y: 52, width: max(CGFloat(last) * 100, 1), height: 56)
            for (i, b) in beads.enumerated() {
                let slot = min(i, last)   // spares coincide with the last real bead
                b.frame = NSRect(x: 16 + CGFloat(slot) * 100, y: 36, width: 88, height: 88)
                b.cornerRadius = 35
            }
            swell.frame = NSRect(x: 4 + CGFloat(selected) * 100, y: 24, width: 112, height: 112)
            CATransaction.commit()
        }
        func after(_ seconds: Double, _ body: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: body)
        }

        // Match once with ten distinct beads.
        layOut(count: 10, selected: 0)
        panel.orderFrontRegardless()
        CATransaction.flush()
        var matched: [ObjectIdentifier: CALayer] = [:]
        let els = elements(container.layer!)
        for v in all {
            let hits = els.filter { $0.frame.insetBy(dx: -0.5, dy: -0.5).contains(v.frame) && v.frame.insetBy(dx: -0.5, dy: -0.5).contains($0.frame) }
            if hits.count == 1 { matched[ObjectIdentifier(v)] = hits[0] }
        }
        print("match at first show: views=\(all.count) elements=\(els.count) matched uniquely=\(matched.count) sdf=\(sdfBounds(container.layer!))")

        func verify(_ label: String) {
            let tree = Set(elements(container.layer!).map(ObjectIdentifier.init))
            var live = 0, placed = 0
            for v in all {
                guard let l = matched[ObjectIdentifier(v)] else { continue }
                if tree.contains(ObjectIdentifier(l)) { live += 1 }
                if abs(l.frame.minX - v.frame.minX) < 0.5 && abs(l.frame.width - v.frame.width) < 0.5 && abs(l.frame.minY - v.frame.minY) < 0.5 { placed += 1 }
            }
            print("\(label): elements in tree=\(tree.count), matched still live=\(live)/\(matched.count), at their view's frame=\(placed)/\(matched.count), sdf=\(sdfBounds(container.layer!))")
        }

        after(0.3) {
            verify("first swipe, 0.3 s on screen")
            panel.orderOut(nil)
            after(0.3) {
                layOut(count: 4, selected: 1)       // next swipe: four apps, laid out while hidden
                panel.orderFrontRegardless()
                CATransaction.flush()
                verify("second swipe (4 apps), right after orderFront + flush")
                after(0.3) {
                    verify("second swipe, 0.3 s later")
                    beads[9].isHidden = true
                    after(0.3) {
                        let n = elements(container.layer!).count
                        print("isHidden on one spare bead, 0.3 s later: elements in tree=\(n)")
                        verify("after isHidden")
                        beads[9].isHidden = false
                        after(0.3) {
                            verify("after unhiding, 0.3 s later")
                            panel.orderOut(nil)
                            after(0.3) {
                                layOut(count: 10, selected: 9)
                                panel.orderFrontRegardless()
                                CATransaction.flush()
                                verify("third swipe (10 apps), right after orderFront + flush")
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
