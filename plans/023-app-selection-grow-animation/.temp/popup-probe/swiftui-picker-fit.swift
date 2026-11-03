// Probe: can SwiftUI's menu Picker (System Settings' own pop-up) be the app picker?
// 1. Look outside a Form (the settings window uses its own rows), 2. app icons at 16 pt in button and menu,
// 3. time to build a ~150-app menu on open, 4. whether the label's content animates live in the button.
// Build: swiftc swiftui-picker-fit.swift -o /tmp/swiftui-picker-fit && /tmp/swiftui-picker-fit /tmp/fit
import AppKit
import SwiftUI

let apps: [(name: String, icon: NSImage)] = {
    let urls = (try? FileManager.default.contentsOfDirectory(
        at: URL(fileURLWithPath: "/System/Applications"), includingPropertiesForKeys: nil)) ?? []
    let more = (try? FileManager.default.contentsOfDirectory(
        at: URL(fileURLWithPath: "/Applications"), includingPropertiesForKeys: nil)) ?? []
    let all = (urls + more).filter { $0.pathExtension == "app" }
    var list = all.map { url -> (String, NSImage) in
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        // Pre-rendered 16 pt bitmap, like AppIcons' cache.
        let small = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            icon.draw(in: rect); return true
        }
        return (url.deletingPathExtension().lastPathComponent, small)
    }
    while list.count < 150 { list += list.prefix(150 - list.count).map { ($0.0 + " copy", $0.1) } }
    return list
}()

struct AppLabel: View {
    let index: Int
    var scale: CGFloat = 1
    var body: some View {
        Label {
            Text(apps[index].name)
        } icon: {
            Image(nsImage: apps[index].icon).scaleEffect(scale)
        }
    }
}

final class Model: ObservableObject {
    @Published var selection = 0
    @Published var scale: CGFloat = 1
}

struct Probe: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            HStack {
                Text("Plain VStack, labelsHidden")
                Spacer()
                Picker("App", selection: $model.selection) {
                    ForEach(apps.indices, id: \.self) { AppLabel(index: $0).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            HStack {
                Text("Scaled label (animation check)")
                Spacer()
                Picker("App", selection: $model.selection) {
                    ForEach(apps.indices, id: \.self) { AppLabel(index: $0, scale: model.scale).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            Form {
                Picker("In grouped Form", selection: $model.selection) {
                    ForEach(apps.indices, id: \.self) { AppLabel(index: $0).tag($0) }
                }
            }
            .formStyle(.grouped)
            .frame(height: 70)
        }
        .padding(20)
        .frame(width: 460)
    }
}

func popups(in view: NSView) -> [NSPopUpButton] {
    (view as? NSPopUpButton).map { [$0] } ?? view.subviews.flatMap(popups)
}

func snapshot(_ view: NSView, _ path: String) {
    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
    view.cacheDisplay(in: view.bounds, to: rep)
    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
}

let out = CommandLine.arguments[1]
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let model = Model()
let window = NSWindow(
    contentRect: CGRect(x: 200, y: 200, width: 460, height: 220), styleMask: [.titled], backing: .buffered,
    defer: false)
window.contentView = NSHostingView(rootView: Probe(model: model))
window.makeKeyAndOrderFront(nil)
print("apps:", apps.count)
DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    let view = window.contentView!
    snapshot(view, out + "-rest.png")
    let found = popups(in: view)
    for popup in found {
        print("popup bezel=\(popup.bezelStyle.rawValue) bordered=\(popup.isBordered) frame=\(popup.frame) items=\(popup.numberOfItems)")
    }
    // 3. Menu build time: what the click pays before the menu shows.
    if let popup = found.first, let menu = popup.menu {
        for run in 1...3 {
            let start = CFAbsoluteTimeGetCurrent()
            menu.delegate?.menuNeedsUpdate?(menu)
            let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000
            let sized = menu.items.first?.image?.size ?? .zero
            print("menuNeedsUpdate run \(run): \(String(format: "%.1f", ms)) ms, items=\(menu.items.count), item image=\(sized)")
        }
        let first = menu.items.first
        print("menu item[0] title=\(first?.title ?? "-") view=\(String(describing: first?.view)) state=\(first?.state.rawValue ?? -1)")
    }
    // 4. Does a changing label redraw in the button?
    model.scale = 0.4
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        snapshot(view, out + "-scaled.png")
        model.selection = 5
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            snapshot(view, out + "-selection5.png")
            for popup in popups(in: view) { print("after select frame=\(popup.frame)") }
            exit(0)
        }
    }
}
app.run()
