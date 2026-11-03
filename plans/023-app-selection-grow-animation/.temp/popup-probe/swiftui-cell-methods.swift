// Probe: what do SwiftUI's SwiftUIPopupButton and SwiftUIPopupButtonCell (the grouped Form pop-up) override, and
// what state do they hold? Tells us which AppKit hooks produce System Settings' badge-and-hover look.
// Build: swiftc -swift-version 5 swiftui-cell-methods.swift -o /tmp/cell-methods && /tmp/cell-methods
import AppKit
import ObjectiveC
import SwiftUI

func dump(_ cls: AnyClass) {
    var chain: [String] = []
    var walk: AnyClass? = cls
    while let c = walk { chain.append(NSStringFromClass(c)); walk = class_getSuperclass(c) }
    print("== \(NSStringFromClass(cls)) : \(chain.dropFirst().joined(separator: " : "))")
    var count: UInt32 = 0
    if let methods = class_copyMethodList(cls, &count) {
        let names = (0..<Int(count)).map { NSStringFromSelector(method_getName(methods[$0])) }.sorted()
        print("  methods:", names.joined(separator: "  "))
        free(methods)
    }
    if let ivars = class_copyIvarList(cls, &count) {
        let names = (0..<Int(count)).compactMap { ivar_getName(ivars[$0]).map { String(cString: $0) } }
        print("  ivars:", names.joined(separator: "  "))
        free(ivars)
    }
}

func popups(in view: NSView) -> [NSPopUpButton] {
    (view as? NSPopUpButton).map { [$0] } ?? view.subviews.flatMap(popups)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let window = NSWindow(
    contentRect: CGRect(x: 200, y: 200, width: 420, height: 120), styleMask: [.titled], backing: .buffered,
    defer: false)
window.contentView = NSHostingView(rootView: Form {
    Picker("App", selection: .constant(1)) { Text("One").tag(1); Text("Two").tag(2) }
}.formStyle(.grouped))
window.makeKeyAndOrderFront(nil)
DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    guard let popup = popups(in: window.contentView!).first else { print("no popup"); exit(1) }
    dump(type(of: popup))
    dump(type(of: popup.cell!))
    for sub in popup.subviews { dump(type(of: sub)) }
    let cell = popup.cell as! NSPopUpButtonCell
    print("cell bezel=\(cell.bezelStyle.rawValue) bordered=\(cell.isBordered) controlSize=\(cell.controlSize.rawValue)")
    print("tracking areas:", popup.trackingAreas.map { "\($0.options.rawValue) owner=\(type(of: $0.owner!))" })
    exit(0)
}
app.run()
