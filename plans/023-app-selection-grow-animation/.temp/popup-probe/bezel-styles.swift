// Probe: does any public bezel style (or control size, or borderShape) make a plain NSPopUpButton resolve to the
// grouped-Form style (cell _resolvedButtonStyle 10) without the private semantic context?
// Build: swiftc -swift-version 5 bezel-styles.swift -o /tmp/bezel-styles && /tmp/bezel-styles
import AppKit

func resolved(_ button: NSPopUpButton) -> Int {
    let sel = NSSelectorFromString("_resolvedButtonStyle")
    typealias G = @convention(c) (AnyObject, Selector) -> Int
    return unsafeBitCast(button.cell!.method(for: sel), to: G.self)(button.cell!, sel)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let window = NSWindow(
    contentRect: CGRect(x: 300, y: 300, width: 300, height: 200), styleMask: [.titled], backing: .buffered,
    defer: false)
let root = NSView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
window.contentView = root
window.makeKeyAndOrderFront(nil)
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    var found: [String] = []
    for raw in 0...30 {
        guard let style = NSButton.BezelStyle(rawValue: UInt(raw)) else { continue }
        for bordered in [true, false] {
            for shape in [NSControl.BorderShape.automatic, .capsule, .roundedRectangle, .circle] {
                for size in [NSControl.ControlSize.regular, .small, .large] {
                    let button = NSPopUpButton(frame: CGRect(x: 0, y: 0, width: 100, height: 24), pullsDown: false)
                    button.addItem(withTitle: "One")
                    button.bezelStyle = style
                    button.isBordered = bordered
                    button.borderShape = shape
                    button.controlSize = size
                    root.addSubview(button)
                    let r = resolved(button)
                    if r == 10 { found.append("bezel \(raw) bordered \(bordered) shape \(shape.rawValue) size \(size.rawValue)") }
                    button.removeFromSuperview()
                }
            }
        }
    }
    print(found.isEmpty ? "no public combination resolves to style 10" : found.joined(separator: "\n"))
    exit(0)
}
app.run()
