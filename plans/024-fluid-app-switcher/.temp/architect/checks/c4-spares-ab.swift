// Check C4 (after fan-out): an A/B in ONE process. Does adding spare glass views laid exactly over the last bead
// change the merged glass's look (brightness, outline)? Captures the row before, after adding six coincident spares,
// and after removing them again; prints mean brightness inside the shape and the outline's extent, per capture.
// Backdrop: mid grey, so brightness can move both ways. Waits 4 s before A and 3 s between captures: the glass
// itself settles over the first seconds on screen (a first run with 1 s waits showed that drift).
//
// Build: swiftc -swift-version 5 -parse-as-library -O c4-spares-ab.swift -o /tmp/tl-check-024/c4
// Run:   /tmp/tl-check-024/c4 <outdir>

import AppKit
import QuartzCore

@main
struct Check {
    static func main() {
        let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/tl-check-024/out"
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let size = NSSize(width: 520, height: 180)
        let screen = NSScreen.main!.frame
        let rect = NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2, width: size.width, height: size.height)
        let panel = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = NSColor(white: 0.5, alpha: 1)
        panel.level = .floating
        panel.hasShadow = false
        let container = NSGlassEffectContainerView(frame: NSRect(origin: .zero, size: size))
        container.spacing = 40
        let content = NSView(frame: container.bounds)
        container.contentView = content
        func glass(_ r: NSRect, _ radius: CGFloat) -> NSGlassEffectView {
            let g = NSGlassEffectView(frame: r); g.cornerRadius = radius; content.addSubview(g); return g
        }
        _ = glass(NSRect(x: 60, y: 62, width: 300, height: 56), 28)
        for i in 0..<4 { _ = glass(NSRect(x: 16 + CGFloat(i) * 100, y: 46, width: 88, height: 88), 35) }
        _ = glass(NSRect(x: 104, y: 34, width: 112, height: 112), 44)
        panel.contentView = container
        panel.orderFrontRegardless()

        func measure(_ name: String) {
            let path = "\(outDir)/c4-\(name).png"
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            p.arguments = ["-x", "-o", "-l", String(panel.windowNumber), path]
            try? p.run(); p.waitUntilExit()
            guard let img = NSImage(contentsOfFile: path), let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
            let rep = NSBitmapImageRep(cgImage: cg)
            let s = CGFloat(rep.pixelsWide) / size.width
            func b(_ xPt: CGFloat, _ yPtFromTop: CGFloat) -> CGFloat { rep.colorAt(x: Int(xPt * s), y: Int(yPtFromTop * s))?.brightnessComponent ?? -1 }
            // Inside points: centre of each bead, the swell, the neck between beads 3 and 4; outside: corner.
            let inside = [60, 160, 260, 360].map { b(CGFloat($0), 90) } + [b(310, 90)]
            let outside = b(5, 5)
            // The neck's half height between beads 3 and 4 (x = 310): scan up from centre until brightness returns to backdrop.
            var y: CGFloat = 90
            while y > 0 && abs(b(310, y) - outside) > 0.02 { y -= 0.5 }
            print("\(name): inside brightness \(inside.map { String(format: "%.3f", $0) }) backdrop \(String(format: "%.3f", outside)); neck 3-4 top edge at y = \(y) pt from top")
        }
        var spares: [NSGlassEffectView] = []
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            measure("A-no-spares")
            for _ in 0..<6 { spares.append(glass(NSRect(x: 316, y: 46, width: 88, height: 88), 35)) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                measure("B-six-coincident-spares")
                spares.forEach { $0.removeFromSuperview() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    measure("C-spares-removed")
                    app.terminate(nil)
                }
            }
        }
        app.run()
    }
}
