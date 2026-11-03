// Probe: under semantic context 8, where does the pop-up actually draw its display item's icon and title, and does
// the cell's imageRect/titleRect agree? Also measures the native gap between icon and title, and how a trailing clear
// margin on the image widens it.
// Build: swiftc -swift-version 5 icon-geometry.swift -o /tmp/icon-geometry && /tmp/icon-geometry
import AppKit

func setFormContext(_ view: NSView) {
    let setter = NSSelectorFromString("_setSemanticContext:")
    typealias F = @convention(c) (AnyObject, Selector, Int) -> Void
    unsafeBitCast(view.method(for: setter), to: F.self)(view, setter, 8)
}

/// A solid red square, easy to find in pixels.
func square(_ side: CGFloat, trailing: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: side + trailing, height: side), flipped: false) { _ in
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: side, height: side).fill()
        return true
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let window = NSWindow(
    contentRect: CGRect(x: 300, y: 300, width: 300, height: 200), styleMask: [.titled], backing: .buffered,
    defer: false)
let root = NSView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
setFormContext(root)
var buttons: [(CGFloat, NSPopUpButton)] = []
for (row, trailing) in [CGFloat(0), 1, 3].enumerated() {
    let button = NSPopUpButton(frame: .zero, pullsDown: false)
    let cell = button.cell as! NSPopUpButtonCell
    cell.usesItemFromMenu = false
    let item = NSMenuItem(title: "IIII", action: nil, keyEquivalent: "")
    item.image = square(16, trailing: trailing)
    cell.menuItem = item
    button.frame = CGRect(origin: CGPoint(x: 20, y: 20 + CGFloat(row) * 50), size: button.intrinsicContentSize)
    root.addSubview(button)
    buttons.append((trailing, button))
}
window.contentView = root
window.makeKeyAndOrderFront(nil)
DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    for (trailing, button) in buttons {
        let rep = button.bitmapImageRepForCachingDisplay(in: button.bounds)!
        button.cacheDisplay(in: button.bounds, to: rep)
        let scale = CGFloat(rep.pixelsWide) / button.bounds.width
        // Red pixels: the icon. Dark, non-red pixels left of the badge: the title's glyphs.
        var red = CGRect.null, text = CGRect.null
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                let point = CGRect(x: CGFloat(x) / scale, y: CGFloat(y) / scale, width: 1 / scale, height: 1 / scale)
                if c.redComponent > 0.8, c.greenComponent < 0.3, c.alphaComponent > 0.5 { red = red.union(point) }
                else if c.alphaComponent > 0.5, c.redComponent < 0.4, c.greenComponent < 0.4,
                        CGFloat(x) / scale < button.bounds.width - 30 { text = text.union(point) }
            }
        }
        let cell = button.cell as! NSPopUpButtonCell
        let imageRect = cell.imageRect(forBounds: button.bounds)
        let titleRect = cell.titleRect(forBounds: button.bounds)
        print("trailing \(trailing): bounds=\(button.bounds) flipped=\(button.isFlipped)")
        print("  drawn icon (top-left origin)=\(red)  cell imageRect=\(imageRect)")
        print("  drawn title=\(text)  cell titleRect=\(titleRect)")
        print("  gap icon→title = \(text.minX - red.maxX) pt")
    }
    exit(0)
}
app.run()
