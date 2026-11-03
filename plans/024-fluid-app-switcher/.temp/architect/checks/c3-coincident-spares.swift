// Check C3 (after fan-out): do spare glass views laid exactly over a real bead change the merged shape?
// The smooth union of identical shapes could inflate the bead. Captures a four-icon row three ways:
//   "none":       band + 4 beads + swell (no spares)
//   "coincident": plus 6 spare beads exactly over the last bead
//   "inside":     plus 6 spare beads shrunk to 1x1 pt at the last bead's centre
// and prints the pixel width of the glass at the last bead's row of pixels for each, from the capture.
//
// Build: swiftc -swift-version 5 -parse-as-library -O c3-coincident-spares.swift -o /tmp/tl-check-024/c3
// Run:   /tmp/tl-check-024/c3 <none|coincident|inside> <outdir>

import AppKit
import QuartzCore

@main
struct Check {
    static func main() {
        let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "none"
        let outDir = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "/tmp/tl-check-024/out"
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let size = NSSize(width: 520, height: 180)
        let screen = NSScreen.main!.frame
        let rect = NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2, width: size.width, height: size.height)
        let panel = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .black
        panel.level = .floating
        panel.hasShadow = false
        let container = NSGlassEffectContainerView(frame: NSRect(origin: .zero, size: size))
        container.spacing = 40
        let content = NSView(frame: container.bounds)
        container.contentView = content
        func glass(_ r: NSRect, _ radius: CGFloat) { let g = NSGlassEffectView(frame: r); g.cornerRadius = radius; content.addSubview(g) }
        glass(NSRect(x: 60, y: 62, width: 300, height: 56), 28)
        for i in 0..<4 { glass(NSRect(x: 16 + CGFloat(i) * 100, y: 46, width: 88, height: 88), 35) }
        glass(NSRect(x: 104, y: 34, width: 112, height: 112), 44)
        for _ in 0..<6 {
            if mode == "coincident" { glass(NSRect(x: 316, y: 46, width: 88, height: 88), 35) }
            if mode == "inside" { glass(NSRect(x: 359.5, y: 89.5, width: 1, height: 1), 0.5) }
        }
        panel.contentView = container
        panel.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let path = "\(outDir)/c3-\(mode).png"
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            p.arguments = ["-x", "-o", "-l", String(panel.windowNumber), path]
            try? p.run(); p.waitUntilExit()
            // Measure the glass's extent along the last bead's vertical centre line and horizontal centre line.
            if let img = NSImage(contentsOfFile: path), let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let rep = NSBitmapImageRep(cgImage: cg)
                let scale = CGFloat(rep.pixelsWide) / size.width
                func lit(_ x: Int, _ y: Int) -> Bool { (rep.colorAt(x: x, y: y)?.brightnessComponent ?? 0) > 0.08 }
                let cx = Int(360 * scale), cy = Int((180 - 90) * scale)
                var top = cy; while top > 0 && lit(cx, top - 1) { top -= 1 }
                var bottom = cy; while bottom < rep.pixelsHigh - 1 && lit(cx, bottom + 1) { bottom += 1 }
                var right = cx; while right < rep.pixelsWide - 1 && lit(right + 1, cy) { right += 1 }
                print("mode=\(mode): last bead's glass height at its centre = \(CGFloat(bottom - top + 1) / scale) pt, right edge at x = \(CGFloat(right + 1) / scale) pt (bead drawn 88 pt tall, right edge 404)")
            }
            app.terminate(nil)
        }
        app.run()
    }
}
