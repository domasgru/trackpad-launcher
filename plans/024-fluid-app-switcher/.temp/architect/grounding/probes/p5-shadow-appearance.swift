// Probe P5: R1 and R2 evidence for the merged-glass shape in a clear, shadowed overlay window.
//  - Does the window-server shadow trace the merged shape, or a rectangle (the reason GlassClip exists)?
//  - How do the band, beads and swell read in light appearance over a white window, and in dark
//    appearance over a busy window?
// The probe puts its own backdrop window under the glass window and captures only that region.
//
// Build: swiftc -swift-version 5 -parse-as-library -O p5-shadow-appearance.swift -o /tmp/tl-probe-024/p5
// Run:   /tmp/tl-probe-024/p5 <light|dark> <white|busy> /tmp/tl-probe-024/out-f [frameset|element]
// With a 4th argument the probe then changes the swell (index 1) and captures again 0.25 s later:
//   frameset: a public view frame set (as per input event), no animation, no invalidateShadow()
//   element:  an additive spring on the mirrored CASDFElementLayer (render server)
// to see whether the window-server shadow follows the new shape.

import AppKit
import QuartzCore

@main
struct Probe {
    static func main() {
        let args = CommandLine.arguments
        let appearanceName = args.count > 1 ? args[1] : "light"
        let backdropKind = args.count > 2 ? args[2] : "white"
        let outDir = args.count > 3 ? args[3] : "/tmp/tl-probe-024/out-f"
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let appearance = NSAppearance(named: appearanceName == "dark" ? .darkAqua : .aqua)!
        app.appearance = appearance

        let screen = NSScreen.main!.frame
        let backRect = NSRect(x: screen.midX - 320, y: screen.midY - 140, width: 640, height: 280)
        let back = NSPanel(contentRect: backRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        back.level = .floating
        back.hasShadow = false
        back.backgroundColor = .white
        let backView = NSView(frame: NSRect(origin: .zero, size: backRect.size))
        backView.wantsLayer = true
        backView.layer!.backgroundColor = NSColor.white.cgColor
        if backdropKind == "busy" {
            // Text-like rows and coloured blocks, like a busy window.
            for row in 0..<14 {
                for col in 0..<12 {
                    let b = CALayer()
                    let w = CGFloat(20 + (row * 7 + col * 13) % 34)
                    b.frame = CGRect(x: CGFloat(col) * 54 + 6, y: CGFloat(row) * 20 + 6, width: w, height: 9)
                    let hue = CGFloat((row * 3 + col * 5) % 10) / 10
                    b.backgroundColor = NSColor(hue: hue, saturation: 0.7, brightness: 0.8, alpha: 1).cgColor
                    backView.layer!.addSublayer(b)
                }
            }
            backView.layer!.backgroundColor = NSColor(white: 0.12, alpha: 1).cgColor
        } else {
            for row in 0..<14 {
                let b = CALayer()
                b.frame = CGRect(x: 20, y: CGFloat(row) * 20 + 6, width: CGFloat(200 + (row * 37) % 300), height: 7)
                b.backgroundColor = NSColor(white: 0.85, alpha: 1).cgColor
                backView.layer!.addSublayer(b)
            }
        }
        back.contentView = backView
        back.orderFrontRegardless()

        let size = NSSize(width: 560, height: 180)
        let rect = NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2, width: size.width, height: size.height)
        let panel = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        panel.hasShadow = true
        let container = NSGlassEffectContainerView(frame: NSRect(origin: .zero, size: size))
        container.spacing = 40
        let content = NSView(frame: container.bounds)
        container.contentView = content
        let band = NSGlassEffectView(frame: NSRect(x: 50, y: 64, width: 460, height: 52)); band.cornerRadius = 26
        content.addSubview(band)
        let iconsHost = NSView(frame: container.bounds)
        iconsHost.wantsLayer = true
        for i in 0..<5 {
            let d: CGFloat = i == 1 ? 104 : 80
            let cx: CGFloat = 80 + CGFloat(i) * 100
            let g = NSGlassEffectView(frame: NSRect(x: cx - d / 2, y: 90 - d / 2, width: d, height: d)); g.cornerRadius = d * 0.32
            content.addSubview(g)
            // A stand-in icon: a rounded square, 64 pt (the 80 pt canvas's body), 1.12x on the selected one.
            let icon = CALayer()
            let s: CGFloat = i == 1 ? 64 * 1.12 : 64
            icon.frame = CGRect(x: cx - s / 2, y: 90 - s / 2, width: s, height: s)
            icon.cornerRadius = s * 0.225
            icon.cornerCurve = .continuous
            icon.backgroundColor = NSColor(hue: CGFloat(i) / 5, saturation: 0.6, brightness: 0.9, alpha: 1).cgColor
            iconsHost.layer!.addSublayer(icon)
        }
        let root = NSView(frame: container.bounds)
        root.addSubview(container)
        root.addSubview(iconsHost)
        panel.contentView = root
        panel.orderFrontRegardless()

        let change = args.count > 4 ? args[4] : ""
        func capture(_ suffix: String) {
            // screencapture -R takes top-left-origin global coordinates in points.
            let mainH = NSScreen.screens[0].frame.height
            let r = "\(Int(backRect.minX)),\(Int(mainH - backRect.maxY)),\(Int(backRect.width)),\(Int(backRect.height))"
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            p.arguments = ["-x", "-R", r, "\(outDir)/p5-\(appearanceName)-\(backdropKind)\(suffix).png"]
            try? p.run()
            p.waitUntilExit()
        }
        func allLayers(_ l: CALayer) -> [CALayer] { [l] + (l.sublayers ?? []).flatMap(allLayers) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            capture("")
            let swell = content.subviews[2] as! NSGlassEffectView
            if change == "frameset" {
                CATransaction.begin(); CATransaction.setDisableActions(true)
                swell.frame = swell.frame.offsetBy(dx: 0, dy: 0).insetBy(dx: -40, dy: 0)
                CATransaction.commit()
            } else if change == "element" {
                let el = allLayers(container.layer!).first { NSStringFromClass(type(of: $0)) == "CASDFElementLayer" && abs($0.frame.width - 104) < 0.5 }
                let a = CABasicAnimation(keyPath: "bounds.size.width")
                a.isAdditive = true; a.fromValue = 80.0; a.toValue = 80.0; a.duration = 2
                el?.add(a, forKey: "probe")
            } else {
                app.terminate(nil)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                capture("-\(change)")
                app.terminate(nil)
            }
        }
        app.run()
    }
}
