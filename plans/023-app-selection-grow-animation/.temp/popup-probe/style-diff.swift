// Probe: which property differs between SwiftUI's grouped-Form pop-up and a plain bordered NSPopUpButton? Reads every
// argument-less getter on NSPopUpButton/NSButton/NSControl/NSView and their cells whose name hints at style, and
// prints the ones whose values differ.
// Build: swiftc -swift-version 5 style-diff.swift -o /tmp/style-diff && /tmp/style-diff
import AppKit
import ObjectiveC
import SwiftUI

let hints = ["style", "Style", "variant", "Variant", "form", "Form", "inline", "Inline", "bezel", "Bezel", "border",
             "Border", "shape", "Shape", "hover", "Hover", "glass", "Glass", "chrome", "Chrome", "accessory", "flavor",
             "appearance", "Appearance", "prominence", "Prominence", "tint", "Tint", "context", "Context", "material"]

func getters(_ cls: AnyClass, stop: AnyClass) -> [String] {
    var names: Set<String> = []
    var walk: AnyClass? = cls
    while let c = walk, c != stop {
        var count: UInt32 = 0
        if let methods = class_copyMethodList(c, &count) {
            for i in 0..<Int(count) {
                let sel = method_getName(methods[i])
                let name = NSStringFromSelector(sel)
                guard !name.contains(":"), method_getNumberOfArguments(methods[i]) == 2,
                      hints.contains(where: name.contains) else { continue }
                var ret = [CChar](repeating: 0, count: 64)
                method_getReturnType(methods[i], &ret, 64)
                let type = String(cString: ret)
                guard ["c", "B", "q", "Q", "i", "I", "d", "f", "@", "s", "S", "l", "L"].contains(type) else { continue }
                names.insert("\(name)|\(type)")
            }
            free(methods)
        }
        walk = class_getSuperclass(c)
    }
    return names.sorted()
}

func read(_ object: NSObject, _ getter: String) -> String {
    let parts = getter.split(separator: "|")
    let name = String(parts[0]), kind = String(parts[1])
    let sel = NSSelectorFromString(name)
    guard object.responds(to: sel), let imp = object.method(for: sel) else { return "-" }
    switch kind {
    case "c", "B":
        typealias F = @convention(c) (AnyObject, Selector) -> Bool
        return "\(unsafeBitCast(imp, to: F.self)(object, sel))"
    case "q", "l", "i", "s":
        typealias F = @convention(c) (AnyObject, Selector) -> Int
        return "\(unsafeBitCast(imp, to: F.self)(object, sel))"
    case "Q", "L", "I", "S":
        typealias F = @convention(c) (AnyObject, Selector) -> UInt
        return "\(unsafeBitCast(imp, to: F.self)(object, sel))"
    case "d":
        typealias F = @convention(c) (AnyObject, Selector) -> Double
        return "\(unsafeBitCast(imp, to: F.self)(object, sel))"
    case "f":
        typealias F = @convention(c) (AnyObject, Selector) -> Float
        return "\(unsafeBitCast(imp, to: F.self)(object, sel))"
    case "@":
        typealias F = @convention(c) (AnyObject, Selector) -> AnyObject?
        let value = unsafeBitCast(imp, to: F.self)(object, sel)
        return value.map { "\(type(of: $0)):\(String(describing: $0).prefix(80))" } ?? "nil"
    default: return "?"
    }
}

func popups(in view: NSView) -> [NSPopUpButton] {
    (view as? NSPopUpButton).map { [$0] } ?? view.subviews.flatMap(popups)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let window = NSWindow(
    contentRect: CGRect(x: 200, y: 200, width: 420, height: 200), styleMask: [.titled], backing: .buffered,
    defer: false)
let plain = NSPopUpButton(frame: CGRect(x: 20, y: 20, width: 120, height: 24), pullsDown: false)
plain.addItems(withTitles: ["One", "Two"])
let host = NSHostingView(rootView: Form {
    Picker("App", selection: .constant(1)) { Text("One").tag(1); Text("Two").tag(2) }
}.formStyle(.grouped).frame(width: 400, height: 90))
host.frame = CGRect(x: 0, y: 80, width: 420, height: 100)
let root = NSView(frame: CGRect(x: 0, y: 0, width: 420, height: 200))
root.addSubview(plain)
root.addSubview(host)
window.contentView = root
window.makeKeyAndOrderFront(nil)
DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    guard let swiftUI = popups(in: host).first else { print("no popup"); exit(1) }
    for (label, a, b, stop) in [
        ("button", swiftUI as NSObject, plain as NSObject, NSResponder.self as AnyClass),
        ("cell", swiftUI.cell!, plain.cell!, NSObject.self as AnyClass),
    ] {
        for getter in getters(NSPopUpButton.self == stop ? NSPopUpButton.self : type(of: b), stop: stop) {
            let x = read(a, getter), y = read(b, getter)
            if x != y { print("\(label) \(getter): swiftUI=\(x)  plain=\(y)") }
        }
    }
    // The hosting renderer inside each.
    for (label, button) in [("swiftUI", swiftUI), ("plain", plain)] {
        print(label, "subviews:", button.subviews.map { "\(type(of: $0))" })
    }
    exit(0)
}
app.run()
