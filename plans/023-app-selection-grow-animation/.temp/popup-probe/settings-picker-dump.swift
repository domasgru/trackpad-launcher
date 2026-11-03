// Probe: what AppKit control does SwiftUI's menu Picker in a grouped Form (System Settings' pop-up) become on macOS 26?
// Run: swift settings-picker-dump.swift
import AppKit
import SwiftUI

struct Probe: View {
    @State var choice = "Safari"
    var body: some View {
        Form {
            Picker("App", selection: $choice) {
                Label("Safari", systemImage: "safari").tag("Safari")
                Text("Mail").tag("Mail")
                Text("A much longer application name here").tag("Long")
            }
            Picker("Plain", selection: $choice) {
                Text("Safari").tag("Safari")
                Text("Mail").tag("Mail")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 200)
    }
}

func describe(_ view: NSView, depth: Int = 0) {
    let pad = String(repeating: "  ", count: depth)
    var line = "\(pad)\(type(of: view)) frame=\(view.frame)"
    if let popup = view as? NSPopUpButton {
        let cell = popup.cell as? NSPopUpButtonCell
        line += " POPUP bordered=\(popup.isBordered) bezel=\(popup.bezelStyle.rawValue) controlSize=\(popup.controlSize.rawValue)"
        line += " font=\(popup.font.map { "\($0.fontName) \($0.pointSize)" } ?? "nil")"
        line += " arrow=\(cell?.arrowPosition.rawValue ?? 99) pref=\(cell?.preferredEdge.rawValue ?? 99)"
        line += " pullsDown=\(popup.pullsDown) items=\(popup.numberOfItems) selected=\(popup.indexOfSelectedItem)"
        line += " intrinsic=\(popup.intrinsicContentSize) cellClass=\(type(of: popup.cell!))"
        line += " imagePosition=\(popup.imagePosition.rawValue) lineBreak=\(cell?.lineBreakMode.rawValue ?? 99)"
        line += " showsBorderOnlyWhileMouseInside=\(popup.showsBorderOnlyWhileMouseInside)"
        line += " altersState=\(cell?.altersStateOfSelectedItem ?? false) usesItemFromMenu=\(cell?.usesItemFromMenu ?? false)"
        if #available(macOS 26.0, *) { line += " borderShape=\(popup.borderShape.rawValue)" }
        line += " menuDelegate=\(String(describing: popup.menu?.delegate))"
        if let item = popup.selectedItem {
            line += " selTitle=\(item.title) selImage=\(item.image?.size ?? .zero)"
            line += " attr=\(item.attributedTitle?.description ?? "nil")"
        }
    }
    print(line)
    for sub in view.subviews { describe(sub, depth: depth + 1) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let window = NSWindow(contentRect: CGRect(x: 200, y: 200, width: 420, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
window.contentView = NSHostingView(rootView: Probe())
window.makeKeyAndOrderFront(nil)
DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    describe(window.contentView!)
    if let rep = window.contentView!.bitmapImageRepForCachingDisplay(in: window.contentView!.bounds) {
        window.contentView!.cacheDisplay(in: window.contentView!.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/settings-picker.png"))
    }
    exit(0)
}
app.run()
