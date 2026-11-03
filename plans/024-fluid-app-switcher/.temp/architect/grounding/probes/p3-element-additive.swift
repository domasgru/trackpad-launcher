// Probe P3: the hybrid pattern. Public frame sets on NSGlassEffectViews (as per input event) plus
// additive CASpringAnimations on the CASDFElementLayers AppKit mirrors them into.
//  1. Does AppKit's mirror of a frame change animate implicitly, or land at once?
//  2. Does an additive spring on an element layer survive AppKit re-syncing that element's frame?
//  3. Can an element layer be tied to its glass view other than by frame (delegate, name, order)?
//  4. Main run loop wake-ups while only render-server springs run.
//  5. Does the element mirror keep its identity across orderOut / orderFront (a new swipe)?
//
// Build: swiftc -swift-version 5 -parse-as-library -O p3-element-additive.swift -o /tmp/tl-probe-024/p3
// Run:   /tmp/tl-probe-024/p3 /tmp/tl-probe-024/out-d [nosync]   (nosync: skip the mid-spring view frame set, to attribute wake-ups)

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

func allLayers(_ l: CALayer) -> [CALayer] { [l] + (l.sublayers ?? []).flatMap(allLayers) }

@main
struct Probe {
    static func main() {
        let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/tl-probe-024/out-d"
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let size = NSSize(width: 520, height: 180)
        let screen = NSScreen.main!.frame
        let rect = NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2, width: size.width, height: size.height)
        let panel = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .white
        panel.level = .floating
        panel.hasShadow = false

        let container = NSGlassEffectContainerView(frame: NSRect(origin: .zero, size: size))
        container.spacing = 40
        let content = NSView(frame: container.bounds)
        container.contentView = content
        var beads: [NSGlassEffectView] = []
        // A band element plus five beads; the middle bead is the swell.
        let band = NSGlassEffectView(frame: NSRect(x: 40, y: 66, width: 400, height: 48))
        band.cornerRadius = 24
        content.addSubview(band)
        for i in 0..<5 {
            let d: CGFloat = i == 2 ? 92 : 64
            let cx: CGFloat = 60 + CGFloat(i) * 90
            let g = NSGlassEffectView(frame: NSRect(x: cx - d / 2, y: 90 - d / 2, width: d, height: d))
            g.cornerRadius = d * 0.4
            content.addSubview(g)
            beads.append(g)
        }
        panel.contentView = container
        panel.orderFrontRegardless()

        func capture(_ name: String) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            p.arguments = ["-x", "-o", "-l", String(panel.windowNumber), "\(outDir)/\(name).png"]
            try? p.run()
            p.waitUntilExit()
        }
        func elements() -> [CALayer] {
            allLayers(container.layer!).filter { NSStringFromClass(type(of: $0)) == "CASDFElementLayer" }
        }
        func element(for v: NSView) -> CALayer? {
            elements().first { abs($0.frame.minX - v.frame.minX) < 0.5 && abs($0.frame.minY - v.frame.minY) < 0.5 && abs($0.frame.width - v.frame.width) < 0.5 }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            capture("p3-rest")
            let els = elements()
            print("element count=\(els.count) (expect 6)")
            for e in els {
                print("element frame=\(e.frame) delegate=\(String(describing: e.delegate.map { type(of: $0) })) name=\(e.name ?? "nil") actions=\(e.actions?.keys.sorted() ?? [])")
            }
            let swellEl = element(for: beads[2])!
            let identityBefore = ObjectIdentifier(swellEl)

            // (2) Additive spring on the swell element's width + position: a "flow + wobble" kick.
            let counter = WakeCounter()
            counter.start()
            CATransaction.begin()
            let w = CASpringAnimation(keyPath: "bounds.size.width")
            w.isAdditive = true
            w.fromValue = 70.0
            w.toValue = 0.0
            w.mass = 1; w.stiffness = 180; w.damping = 9
            w.duration = w.settlingDuration
            swellEl.add(w, forKey: "probe-wobble")
            let x = CASpringAnimation(keyPath: "position.x")
            x.isAdditive = true
            x.fromValue = 35.0
            x.toValue = 0.0
            x.mass = 1; x.stiffness = 180; x.damping = 9
            x.duration = x.settlingDuration
            swellEl.add(x, forKey: "probe-wobble-x")
            CATransaction.commit()
            print("spring settling duration=\(w.settlingDuration)")

            // (1)+(2): 0.15 s later, an "input event" moves bead 4's view frame and changes the swell view's height.
            let skipSync = CommandLine.arguments.count > 2 && CommandLine.arguments[2] == "nosync"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if skipSync { print("nosync: no view frame set during the springs"); return }
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                beads[3].frame.origin.y += 10
                beads[2].frame.size.height += 8
                beads[2].frame.origin.y -= 4
                CATransaction.commit()
                DispatchQueue.main.async {
                    let el4 = elements().first { abs($0.frame.minX - beads[3].frame.minX) < 0.5 && abs($0.frame.width - 64) < 0.5 }
                    print("after view frame set: bead4 element model=\(el4?.frame ?? .zero) presentation=\(el4?.presentation()?.frame ?? .zero) anims=\(el4?.animationKeys() ?? [])")
                    print("after view frame set: swell element model=\(swellEl.frame) anims=\(swellEl.animationKeys() ?? []) presentation=\(swellEl.presentation()?.frame ?? .zero) same layer=\(ObjectIdentifier(swellEl) == identityBefore && elements().contains { $0 === swellEl })")
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.08) { capture("p3-kick-early") }
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.35) { capture("p3-kick-mid") }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let wakes = counter.stop()
                print("wake-ups over 2.0 s with springs on the render server (probe's own blocks: 3-4): \(wakes)")
                capture("p3-settled")
                // (5) Order out and back in: is the element mirror the same layer?
                panel.orderOut(nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    panel.orderFrontRegardless()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        let again = elements()
                        print("after orderOut/orderFront: element count=\(again.count) swell element same layer=\(again.contains { $0 === swellEl })")
                        app.terminate(nil)
                    }
                }
            }
        }
        app.run()
    }
}
