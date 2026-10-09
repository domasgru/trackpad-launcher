// Probe: can NSImage load the SVG assets directly (no asset catalog / actool), and can a template
// rendering of them be drawn (needed for light/dark tinting)? Shows false if NSImage is nil, has zero
// size, or drawing into a bitmap yields no opaque pixels.
import AppKit

let dir = CommandLine.arguments[1]
for name in ["gesture-1", "gesture-2", "gesture-3", "gesture-4", "thumb-mark", "other-finger-mark"] {
    let url = URL(fileURLWithPath: "\(dir)/\(name).svg")
    guard let img = NSImage(contentsOf: url) else { print("FAIL \(name): NSImage nil"); continue }
    img.isTemplate = true
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 96, pixelsHigh: 62, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 0, y: 0, width: 96, height: 62), from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    var opaque = 0
    for y in 0..<62 { for x in 0..<96 { if (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 { opaque += 1 } } }
    print("OK \(name): size=\(img.size) reps=\(img.representations.map { type(of: $0) }) opaquePixels(96x62)=\(opaque)")
}
