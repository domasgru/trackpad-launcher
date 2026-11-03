// Probe: which plain NSPopUpButton configuration renders like System Settings' pop-up (title, then chevrons in a
// round badge, bezel only on hover)? Renders each variant, plus SwiftUI's Form picker, into one PNG.
// Build: swiftc appkit-variants.swift -o /tmp/appkit-variants && /tmp/appkit-variants /tmp/variants.png
import AppKit
import SwiftUI

func popup(_ label: String, configure: (NSPopUpButton) -> Void) -> NSView {
    let button = NSPopUpButton(frame: .zero, pullsDown: false)
    button.addItem(withTitle: "Safari")
    button.item(at: 0)?.image = NSWorkspace.shared.icon(forFile: "/Applications/Safari.app")
    button.item(at: 0)?.image?.size = NSSize(width: 16, height: 16)
    button.addItem(withTitle: "A much longer application name here")
    button.selectItem(at: 0)
    configure(button)
    let text = NSTextField(labelWithString: label)
    text.font = .systemFont(ofSize: 11)
    let row = NSStackView(views: [text, button])
    row.orientation = .horizontal
    row.distribution = .fill
    print(label, "intrinsic=\(button.intrinsicContentSize)")
    return row
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let window = NSWindow(
    contentRect: CGRect(x: 200, y: 200, width: 560, height: 420), styleMask: [.titled], backing: .buffered,
    defer: false)
let rows: [NSView] = [
    popup("push bordered") { _ in },
    popup("push bordered, showsBorderOnlyWhileMouseInside") { $0.showsBorderOnlyWhileMouseInside = true },
    popup("borderless") { $0.isBordered = false },
    popup("flexiblePush") { $0.bezelStyle = .flexiblePush },
    popup("push, width 120 (truncation)") { $0.widthAnchor.constraint(equalToConstant: 120).isActive = true },
    popup("push, usesItemFromMenu=false") { ($0.cell as? NSPopUpButtonCell)?.usesItemFromMenu = false },
    NSHostingView(rootView: Form {
        Picker("SwiftUI Form picker", selection: .constant("Safari")) { Text("Safari").tag("Safari") }
    }.formStyle(.grouped).frame(width: 500, height: 70)),
]
let stack = NSStackView(views: rows)
stack.orientation = .vertical
stack.alignment = .leading
stack.spacing = 14
stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
window.contentView = stack
window.makeKeyAndOrderFront(nil)
DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    let view = window.contentView!
    if let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(
            to: URL(fileURLWithPath: CommandLine.arguments[1]))
    }
    exit(0)
}
app.run()
