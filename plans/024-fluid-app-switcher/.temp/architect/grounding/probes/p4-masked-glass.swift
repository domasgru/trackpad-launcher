// Probe P4: the all-public render-server alternative. One rectangular NSGlassEffectView whose layer is
// masked by a CAShapeLayer blob path (band + beads + swell outline), with the path animated on the
// render server. Does the result still read as Liquid Glass (rim, lensing) or as a flat frosted cut-out?
// Compared side by side with the SDF-merged container (top half) over the same striped backdrop.
//
// Build: swiftc -swift-version 5 -parse-as-library -O p4-masked-glass.swift -o /tmp/tl-probe-024/p4
// Run:   /tmp/tl-probe-024/p4 /tmp/tl-probe-024/out-e

import AppKit
import QuartzCore

func blobPath(swellAt: CGFloat, in rect: CGRect) -> CGPath {
    // Union of a band capsule, five bead circles and a swell circle, as one path (non-zero fill).
    let p = CGMutablePath()
    p.addRoundedRect(in: CGRect(x: 40, y: rect.midY - 24, width: 400, height: 48), cornerWidth: 24, cornerHeight: 24)
    for i in 0..<5 {
        let cx: CGFloat = 60 + CGFloat(i) * 90
        p.addEllipse(in: CGRect(x: cx - 32, y: rect.midY - 32, width: 64, height: 64))
    }
    p.addEllipse(in: CGRect(x: swellAt - 46, y: rect.midY - 46, width: 92, height: 92))
    return p
}

@main
struct Probe {
    static func main() {
        let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/tl-probe-024/out-e"
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let size = NSSize(width: 520, height: 360)
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
            s.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.5).cgColor
            stripes.addSublayer(s)
        }
        root.layer!.addSublayer(stripes)

        // Top: SDF-merged container.
        let top = NSRect(x: 0, y: 180, width: 520, height: 180)
        let container = NSGlassEffectContainerView(frame: top)
        container.spacing = 40
        let content = NSView(frame: container.bounds)
        container.contentView = content
        let band = NSGlassEffectView(frame: NSRect(x: 40, y: 66, width: 400, height: 48)); band.cornerRadius = 24
        content.addSubview(band)
        for i in 0..<5 {
            let d: CGFloat = i == 2 ? 92 : 64
            let cx: CGFloat = 60 + CGFloat(i) * 90
            let g = NSGlassEffectView(frame: NSRect(x: cx - d / 2, y: 90 - d / 2, width: d, height: d)); g.cornerRadius = d * 0.4
            content.addSubview(g)
        }
        root.addSubview(container)

        // Bottom: one glass view masked by a path.
        let bottomRect = NSRect(x: 0, y: 0, width: 520, height: 180)
        let glass = NSGlassEffectView(frame: bottomRect)
        glass.cornerRadius = 0
        glass.wantsLayer = true
        root.addSubview(glass)
        panel.contentView = root
        panel.orderFrontRegardless()

        let mask = CAShapeLayer()
        mask.frame = glass.bounds
        mask.path = blobPath(swellAt: 240, in: glass.bounds)
        mask.fillRule = .nonZero
        glass.layer!.mask = mask

        func capture(_ name: String) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            p.arguments = ["-x", "-o", "-l", String(panel.windowNumber), "\(outDir)/\(name).png"]
            try? p.run()
            p.waitUntilExit()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            capture("p4-rest")
            print("mask applied to glass layer: \(glass.layer!.mask != nil); glass sublayers: \((glass.layer!.sublayers ?? []).map { NSStringFromClass(type(of: $0)) })")
            app.terminate(nil)
        }
        app.run()
    }
}
