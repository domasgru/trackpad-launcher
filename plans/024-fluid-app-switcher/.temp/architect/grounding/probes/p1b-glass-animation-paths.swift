// Probe P1b: which animation paths move a merged Liquid Glass shape, and do they run app code per frame?
//   mode "animator":  NSAnimationContext + view.animator().frame on an NSGlassEffectView in a container
//   mode "implicit":  NSAnimationContext with allowsImplicitAnimation + plain frame set
//   mode "element":   a CABasicAnimation added straight onto the (private) CASDFElementLayer AppKit mirrors
//   mode "spacing":   no animation; spacing 40 vs gaps of 16 pt, to see when necks form
// Also lists the ObjC properties of CASDFElementLayer and CASDFLayer.
//
// Build: swiftc -swift-version 5 -parse-as-library -O p1b-glass-animation-paths.swift -o /tmp/tl-probe-024/p1b
// Run:   /tmp/tl-probe-024/p1b <mode> <outdir>

import AppKit
import QuartzCore
import ObjectiveC

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

func cpuMS() -> Double {
    var u = rusage()
    getrusage(RUSAGE_SELF, &u)
    return Double(u.ru_utime.tv_sec + u.ru_stime.tv_sec) * 1000 + Double(u.ru_utime.tv_usec + u.ru_stime.tv_usec) / 1000
}

func allLayers(_ l: CALayer) -> [CALayer] { [l] + (l.sublayers ?? []).flatMap(allLayers) }

func listProperties(_ name: String) {
    guard let cls = NSClassFromString(name) else { print("\(name): not found"); return }
    var n: UInt32 = 0
    let props = class_copyPropertyList(cls, &n)
    var names: [String] = []
    for i in 0..<Int(n) { names.append(String(cString: property_getName(props![i]))) }
    free(props)
    print("\(name) properties: \(names.sorted())")
    if let sup = class_getSuperclass(cls) { print("\(name) superclass: \(NSStringFromClass(sup))") }
}

@main
struct Probe {
    static func main() {
        let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "animator"
        let outDir = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "/tmp/tl-probe-024/out-b"
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        listProperties("CASDFElementLayer")
        listProperties("CASDFLayer")

        let size = NSSize(width: 520, height: 180)
        let screen = NSScreen.main!.frame
        let rect = NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2, width: size.width, height: size.height)
        let panel = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = false

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
        container.spacing = mode == "spacing" ? 40 : 24
        let content = NSView(frame: root.bounds)
        container.contentView = content
        root.addSubview(container)

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
            p.arguments = ["-x", "-o", "-l", String(panel.windowNumber), "\(outDir)/\(mode)-\(name).png"]
            try? p.run()
            p.waitUntilExit()
        }
        func elementLayers() -> [CALayer] {
            allLayers(root.layer!).filter { NSStringFromClass(type(of: $0)) == "CASDFElementLayer" }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            capture("rest")
            if mode == "spacing" {
                print("spacing=40: captured rest only")
                app.terminate(nil)
                return
            }
            let moving = beads[3]
            let cpu0 = cpuMS()
            let counter = WakeCounter()
            counter.start()
            switch mode {
            case "animator":
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 1.2
                    moving.animator().frame.origin.x -= 50
                    beads[2].animator().frame.size.width += 60
                }
            case "implicit":
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 1.2
                    ctx.allowsImplicitAnimation = true
                    moving.frame.origin.x -= 50
                    beads[2].frame.size.width += 60
                }
            case "element":
                // Find the element mirroring bead index 3 by its frame.
                let target = elementLayers().first { abs($0.frame.minX - moving.frame.minX) < 0.5 && abs($0.frame.width - 60) < 0.5 }
                if let t = target {
                    let a = CABasicAnimation(keyPath: "position.x")
                    a.fromValue = t.position.x
                    a.toValue = t.position.x - 50
                    a.duration = 1.2
                    a.fillMode = .forwards
                    a.isRemovedOnCompletion = false
                    t.add(a, forKey: "probe-element")
                    print("added animation to element layer \(t.frame)")
                } else {
                    print("element layer not found")
                }
            default: break
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.6) { capture("mid") }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                for e in elementLayers() {
                    print("element \(e.frame) anims=\(e.animationKeys() ?? []) presentation=\(e.presentation()?.frame ?? .zero)")
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                print("process CPU during the animation window: \(String(format: "%.1f", cpuMS() - cpu0)) ms, including the capture spawn")
                let wakes = counter.stop()
                print("mode=\(mode) main run loop wake-ups during the 1.2 s animation (probe's own scheduled blocks: 2): \(wakes)")
                capture("end")
                app.terminate(nil)
            }
        }
        app.run()
    }
}
