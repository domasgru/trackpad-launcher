// Probe: does a plain NSPopUpButton inside an NSViewRepresentable get the grouped-Form style (context 8, resolved
// style 10) from SwiftUI, and from which containers? A public route would avoid the private setter.
// Build: swiftc -swift-version 5 form-inheritance.swift -o /tmp/form-inheritance && /tmp/form-inheritance
import AppKit
import SwiftUI

struct Plain: NSViewRepresentable {
    let tag: String
    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.addItem(withTitle: tag)
        button.identifier = NSUserInterfaceItemIdentifier(tag)
        return button
    }
    func updateNSView(_ view: NSPopUpButton, context: Context) {}
}

func popups(in view: NSView) -> [NSPopUpButton] {
    (view as? NSPopUpButton).map { [$0] } ?? view.subviews.flatMap(popups)
}

func read(_ object: NSObject, _ name: String) -> Int {
    let sel = NSSelectorFromString(name)
    typealias G = @convention(c) (AnyObject, Selector) -> Int
    return unsafeBitCast(object.method(for: sel), to: G.self)(object, sel)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let window = NSWindow(
    contentRect: CGRect(x: 300, y: 300, width: 420, height: 420), styleMask: [.titled], backing: .buffered,
    defer: false)
window.contentView = NSHostingView(rootView: VStack {
    Plain(tag: "vstack")
    Form { Plain(tag: "grouped form") }.formStyle(.grouped).frame(height: 70)
    Form { LabeledContent("x") { Plain(tag: "grouped form, labeled content") } }.formStyle(.grouped).frame(height: 70)
    Form { Plain(tag: "columns form") }.formStyle(.columns).frame(height: 40)
    VStack { Plain(tag: "vstack with formStyle grouped") }.formStyle(.grouped)
    LabeledContent("y") { Plain(tag: "labeled content alone") }
}.frame(width: 400, height: 400))
window.makeKeyAndOrderFront(nil)
DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    for popup in popups(in: window.contentView!) {
        print("\(popup.identifier?.rawValue ?? "?"): context \(read(popup, "computed_effectiveSemanticContext")) resolved style \(read(popup.cell!, "_resolvedButtonStyle"))")
    }
    exit(0)
}
app.run()
