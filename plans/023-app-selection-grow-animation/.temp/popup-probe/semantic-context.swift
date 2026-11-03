// Probe: where does the pop-up's semantic context 8 come from, and does setting it on a plain NSPopUpButton's
// ancestor give System Settings' look? Lists AppKit's semantic-context selectors, then renders plain pop-ups under
// a container with each context value.
// Build: swiftc -swift-version 5 semantic-context.swift -o /tmp/semantic && /tmp/semantic /tmp/semantic.png
import AppKit
import ObjectiveC

for cls in [NSView.self, NSControl.self, NSButton.self, NSPopUpButton.self, NSWindow.self, NSCell.self] as [AnyClass] {
    var count: UInt32 = 0
    guard let methods = class_copyMethodList(cls, &count) else { continue }
    let names = (0..<Int(count)).map { NSStringFromSelector(method_getName(methods[$0])) }
        .filter { $0.lowercased().contains("semanticcontext") }
    free(methods)
    if !names.isEmpty { print(NSStringFromClass(cls), names.sorted()) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let window = NSWindow(
    contentRect: CGRect(x: 200, y: 200, width: 420, height: 420), styleMask: [.titled], backing: .buffered,
    defer: false)
let root = NSStackView()
root.orientation = .vertical
root.alignment = .leading
root.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
var buttons: [(Int, NSPopUpButton)] = []
for context in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] {
    let container = NSView()
    let button = NSPopUpButton(frame: .zero, pullsDown: false)
    button.addItems(withTitles: ["Context \(context)", "Two"])
    button.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(button)
    NSLayoutConstraint.activate([
        button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        button.topAnchor.constraint(equalTo: container.topAnchor),
        button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        container.widthAnchor.constraint(equalToConstant: 300),
    ])
    let setter = NSSelectorFromString("_setSemanticContext:")
    if container.responds(to: setter) {
        typealias F = @convention(c) (AnyObject, Selector, Int) -> Void
        unsafeBitCast(container.method(for: setter), to: F.self)(container, setter, context)
    }
    root.addArrangedSubview(container)
    buttons.append((context, button))
}
window.contentView = root
window.makeKeyAndOrderFront(nil)
DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    for (context, button) in buttons {
        let style = NSSelectorFromString("_resolvedButtonStyle")
        typealias G = @convention(c) (AnyObject, Selector) -> Int
        let resolved = button.cell!.responds(to: style)
            ? unsafeBitCast(button.cell!.method(for: style), to: G.self)(button.cell!, style) : -1
        print("context \(context): resolved style \(resolved) intrinsic \(button.intrinsicContentSize)")
    }
    let view = window.contentView!
    if let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    }
    exit(0)
}
app.run()
