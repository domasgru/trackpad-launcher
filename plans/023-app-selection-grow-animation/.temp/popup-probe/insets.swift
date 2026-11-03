// Probe: in System Settings' pop-up style, how far inside the button's frame is the drawn content (icon or title on
// the left, the chevron badge on the right)? The picker's 128 pt is content, so its frame cap is 128 plus these.
// Build: swiftc -swift-version 5 insets.swift -o /tmp/insets && /tmp/insets
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let window = NSWindow(
    contentRect: CGRect(x: 300, y: 300, width: 300, height: 100), styleMask: [.titled], backing: .buffered,
    defer: false)
let root = NSView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
let setter = NSSelectorFromString("_setSemanticContext:")
typealias F = @convention(c) (AnyObject, Selector, Int) -> Void
unsafeBitCast(root.method(for: setter), to: F.self)(root, setter, 8)
var buttons: [NSPopUpButton] = []
for (row, title) in ["Choose app…", "IIII"].enumerated() {
    let button = NSPopUpButton(frame: .zero, pullsDown: false)
    (button.cell as! NSPopUpButtonCell).usesItemFromMenu = false
    (button.cell as! NSPopUpButtonCell).menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    button.frame = CGRect(origin: CGPoint(x: 20, y: 10 + CGFloat(row) * 40), size: button.intrinsicContentSize)
    root.addSubview(button)
    buttons.append(button)
}
window.contentView = root
window.makeKeyAndOrderFront(nil)
DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    for button in buttons {
        let rep = button.bitmapImageRepForCachingDisplay(in: button.bounds)!
        button.cacheDisplay(in: button.bounds, to: rep)
        let scale = CGFloat(rep.pixelsWide) / button.bounds.width
        var minX = CGFloat.infinity, maxX = -CGFloat.infinity
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 {
                minX = min(minX, CGFloat(x) / scale)
                maxX = max(maxX, CGFloat(x + 1) / scale)
            }
        }
        let title = (button.cell as! NSPopUpButtonCell).menuItem!.title
        let titleRect = (button.cell as! NSPopUpButtonCell).titleRect(forBounds: button.bounds)
        print("\(title): width \(button.bounds.width), drawn \(minX)...\(maxX), leading inset \(minX), trailing inset \(button.bounds.width - maxX), titleRect \(titleRect)")
    }
    exit(0)
}
app.run()
