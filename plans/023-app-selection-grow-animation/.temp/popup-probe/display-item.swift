// Probe: a plain NSPopUpButton under semantic context 8, with the cell showing a display item of its own
// (usesItemFromMenu = false) and the menu filled only in menuNeedsUpdate.
// Questions: 1. does the intrinsic size follow the display item, not the widest menu item?
// 2. does the menu open with the selected item over the button (native), selected in menuNeedsUpdate?
// 3. does picking an item change what the button draws (it must not: we update the display item ourselves)?
// 4. does a long display title truncate at the end when the button is capped at 128 pt?
// Build: swiftc -swift-version 5 display-item.swift -o /tmp/display-item && /tmp/display-item /tmp/display
import AppKit
import ObjectiveC

func setFormContext(_ view: NSView) {
    let setter = NSSelectorFromString("_setSemanticContext:")
    typealias F = @convention(c) (AnyObject, Selector, Int) -> Void
    unsafeBitCast(view.method(for: setter), to: F.self)(view, setter, 8)
}

let names = (1...60).map { "App number \($0)" } + ["A much longer application name than fits"]
let icon = NSWorkspace.shared.icon(forFile: "/Applications/Safari.app")
icon.size = NSSize(width: 16, height: 16)

final class Delegate: NSObject, NSMenuDelegate {
    weak var button: NSPopUpButton?
    var selected = 30
    var openedAt: [String] = []
    func menuNeedsUpdate(_ menu: NSMenu) {
        let start = CFAbsoluteTimeGetCurrent()
        menu.removeAllItems()
        for (index, name) in names.enumerated() {
            let item = NSMenuItem(title: name, action: #selector(pick(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.image = icon
            menu.addItem(item)
        }
        button?.selectItem(at: selected)
        print("menuNeedsUpdate \(String(format: "%.1f", (CFAbsoluteTimeGetCurrent() - start) * 1000)) ms, selected item state=\(menu.item(at: selected)!.state.rawValue)")
    }
    @objc func pick(_ sender: NSMenuItem) {
        print("pick \(sender.title): display item title=\(button!.title) selectedItem=\(button!.selectedItem?.title ?? "-") intrinsic=\(button!.intrinsicContentSize)")
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let window = NSWindow(
    contentRect: CGRect(x: 300, y: 300, width: 420, height: 200), styleMask: [.titled], backing: .buffered,
    defer: false)
let root = NSView(frame: CGRect(x: 0, y: 0, width: 420, height: 200))
setFormContext(root)
let delegate = Delegate()

func makeButton(title: String, y: CGFloat, cap: Bool) -> NSPopUpButton {
    let button = NSPopUpButton(frame: .zero, pullsDown: false)
    let cell = button.cell as! NSPopUpButtonCell
    cell.usesItemFromMenu = false
    let display = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    display.image = icon
    cell.menuItem = display
    cell.lineBreakMode = .byTruncatingTail
    button.menu = NSMenu()
    button.menu!.delegate = delegate
    button.translatesAutoresizingMaskIntoConstraints = false
    root.addSubview(button)
    button.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20).isActive = true
    button.topAnchor.constraint(equalTo: root.topAnchor, constant: y).isActive = true
    if cap { button.widthAnchor.constraint(lessThanOrEqualToConstant: 128).isActive = true }
    print("'\(title)': intrinsic=\(button.intrinsicContentSize) items=\(button.numberOfItems)")
    return button
}

let main = makeButton(title: "App number 31", y: 30, cap: true)
let long = makeButton(title: names.last!, y: 80, cap: true)
delegate.button = main
window.contentView = root
window.makeKeyAndOrderFront(nil)
app.activate()

DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    // Fill the menu as an open would, then check the intrinsic size with 61 items inside.
    main.menu!.delegate!.menuNeedsUpdate!(main.menu!)
    print("with full menu: intrinsic=\(main.intrinsicContentSize) frame=\(main.frame) long frame=\(long.frame)")
    let view = window.contentView!
    if let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: CommandLine.arguments[1] + "-rest.png"))
    }
    // Open the menu for real; while it tracks, find where the selected item sits relative to the button.
    let timer = Timer(timeInterval: 0.5, repeats: false) { _ in
        let buttonOnScreen = window.convertToScreen(main.convert(main.bounds, to: nil))
        let menuWindows = NSApp.windows.filter { $0.className.contains("Menu") && $0.isVisible }
        print("button on screen \(buttonOnScreen)")
        for w in menuWindows { print("menu window \(w.className) frame \(w.frame)") }
        if let item = main.menu?.item(at: delegate.selected), let menuWindow = menuWindows.first {
            print("menu top \(menuWindow.frame.maxY), selected index \(delegate.selected) of \(names.count), highlighted=\(main.menu?.highlightedItem?.title ?? "-") item=\(item.title)")
        }
        // Pick item 5 as a click would.
        main.menu?.cancelTracking()
        main.menu?.performActionForItem(at: 5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("after pick: button title=\(main.title) selected=\(main.indexOfSelectedItem) intrinsic=\(main.intrinsicContentSize)")
            exit(0)
        }
    }
    RunLoop.main.add(timer, forMode: .common)
    main.performClick(nil)
}
app.run()
