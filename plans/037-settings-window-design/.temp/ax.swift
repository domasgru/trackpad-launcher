// Drives one app's controls through the Accessibility API: no pointer movement, no global events.
// Build: swiftc ax.swift -o ../../../build/ax
// Run:   ax <pid> tree [depth]
//        ax <pid> press <role> <text> [occurrence]   text is matched against title, description, value and identifier
import ApplicationServices
import Foundation

func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

func text(_ element: AXUIElement) -> String {
    [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute, kAXIdentifierAttribute, kAXHelpAttribute, kAXSubroleAttribute]
        .compactMap { attribute(element, $0).map { "\($0)" } }
        .joined(separator: " | ")
}

func frame(_ element: AXUIElement) -> CGRect {
    var origin = CGPoint.zero, size = CGSize.zero
    if let value = attribute(element, kAXPositionAttribute) { AXValueGetValue(value as! AXValue, .cgPoint, &origin) }
    if let value = attribute(element, kAXSizeAttribute) { AXValueGetValue(value as! AXValue, .cgSize, &size) }
    return CGRect(origin: origin, size: size)
}

func children(_ element: AXUIElement) -> [AXUIElement] {
    attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
}

func walk(_ element: AXUIElement, depth: Int, _ visit: (AXUIElement, Int) -> Void) {
    visit(element, depth)
    guard depth < 30 else { return }
    for child in children(element) { walk(child, depth: depth + 1, visit) }
}

let arguments = CommandLine.arguments
guard arguments.count >= 3, let pid = pid_t(arguments[1]) else {
    print("usage: ax <pid> tree [depth] | press <role> <text> [occurrence]")
    exit(2)
}
let app = AXUIElementCreateApplication(pid)

switch arguments[2] {
case "tree":
    let limit = arguments.count > 3 ? Int(arguments[3]) ?? 30 : 30
    walk(app, depth: 0) { element, depth in
        guard depth <= limit else { return }
        let role = attribute(element, kAXRoleAttribute) as? String ?? "?"
        let box = frame(element)
        print(String(repeating: " ", count: depth), role, "[\(Int(box.minX)),\(Int(box.minY)) \(Int(box.width))x\(Int(box.height))]", text(element))
    }
case "press":
    let role = arguments[3], wanted = arguments[4]
    let occurrence = arguments.count > 5 ? Int(arguments[5]) ?? 0 : 0
    var found: [AXUIElement] = []
    walk(app, depth: 0) { element, _ in
        if attribute(element, kAXRoleAttribute) as? String == role, text(element).contains(wanted) { found.append(element) }
    }
    guard occurrence < found.count else {
        print("not found: \(role) \(wanted) (matches: \(found.count))")
        exit(1)
    }
    let result = AXUIElementPerformAction(found[occurrence], kAXPressAction as CFString)
    print("pressed \(text(found[occurrence])) -> \(result.rawValue)")
default:
    print("unknown command")
    exit(2)
}
