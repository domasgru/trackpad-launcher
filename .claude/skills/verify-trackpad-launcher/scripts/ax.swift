// Accessibility driver for the Trackpad Launcher verification instance. Compiled by `tlv build` into
// $TLV_STATE/tlv-ax and run by `tlv`; usage: tlv-ax <command> <pid> [args...]
//
// Everything goes through the AX API addressed by PID (never System Events, which resolves processes by
// name and hands commands to whichever copy of the app it finds first). The one keystroke, Escape, is posted
// to our PID only, so it can never land in the user's frontmost app.
import AppKit
import ApplicationServices

struct Failure: Error, CustomStringConvertible { let description: String }
func fail(_ message: String) -> Failure { Failure(description: message) }

// MARK: AX primitives

func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

func string(_ element: AXUIElement, _ name: String) -> String {
    switch attribute(element, name) {
    case let value as String: value
    case let value as NSAttributedString: value.string
    case let value as NSNumber: value.stringValue
    default: ""
    }
}

func role(_ element: AXUIElement) -> String { string(element, "AXRole") }
func children(_ element: AXUIElement) -> [AXUIElement] { attribute(element, "AXChildren") as? [AXUIElement] ?? [] }

/// SwiftUI on macOS 26 puts labels in AXDescription; AppKit controls use AXTitle.
func label(_ element: AXUIElement) -> String {
    let title = string(element, "AXTitle")
    return title.isEmpty ? string(element, "AXDescription") : title
}

func perform(_ element: AXUIElement, _ action: String) throws {
    let result = AXUIElementPerformAction(element, action as CFString)
    // Opening a menu runs its tracking loop inside the app, so the call often reports a timeout
    // even though the menu opened. Callers wait for the observable result instead.
    guard result == .success || result == .cannotComplete else { throw fail("\(action) failed: AXError \(result.rawValue)") }
}

func waitFor(_ seconds: Double, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(seconds)
    while Date() < deadline {
        if condition() { return true }
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    return condition()
}

func pause(_ seconds: Double) { RunLoop.current.run(until: Date().addingTimeInterval(seconds)) }

// MARK: The launcher's UI

struct Launcher {
    let pid: pid_t
    let app: AXUIElement

    init(pid: pid_t) throws {
        guard AXIsProcessTrusted() else { throw fail("this terminal lacks Accessibility permission") }
        guard let running = NSRunningApplication(processIdentifier: pid) else { throw fail("no process with pid \(pid)") }
        guard running.bundleIdentifier == "com.domasgru.TrackpadLauncherApp.verify" else {
            throw fail("pid \(pid) is \(running.bundleIdentifier ?? "unknown"), not the verification build; refusing to drive it")
        }
        self.pid = pid
        app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 2)
    }

    var statusItem: AXUIElement? {
        guard let bar = attribute(app, "AXExtrasMenuBar") else { return nil }
        return children(bar as! AXUIElement).first
    }

    var window: AXUIElement? { (attribute(app, "AXWindows") as? [AXUIElement])?.first }
    var isOpen: Bool { window != nil }

    /// The window's controls in visual order: four (image, picker) pairs, hand toggle, hint/notices, buttons.
    func controls() throws -> [AXUIElement] {
        if !isOpen {
            // A real mouse-down anywhere closes the window (by design), so a person using the Mac while the
            // agent drives closes it between commands. Commands that act inside the window reopen it.
            try clickIcon()
            guard waitFor(3, { isOpen }) else { throw fail("window did not open within 3s") }
        }
        guard let group = window.flatMap({ children($0).first }) else { throw fail("window has no content") }
        return children(group)
    }

    func pickers() throws -> [AXUIElement] { try controls().filter { role($0) == "AXPopUpButton" } }

    func picker(_ n: String) throws -> AXUIElement {
        let all = try pickers()
        guard let index = Int(n), (1...all.count).contains(index) else { throw fail("no picker for gesture \(n)") }
        return all[index - 1]
    }

    func clickIcon() throws {
        guard let item = statusItem else { throw fail("menu bar icon not found") }
        try perform(item, "AXPress")
    }

    /// Opens a picker's menu and returns it.
    func openMenu(_ picker: AXUIElement) throws -> AXUIElement {
        try perform(picker, "AXPress")
        var menu: AXUIElement?
        guard waitFor(2, {
            menu = children(picker).first { role($0) == "AXMenu" }
            return menu != nil
        }) else { throw fail("picker menu did not open") }
        return menu!
    }

    func cancel(_ menu: AXUIElement) { _ = try? perform(menu, "AXCancel") }
}

// MARK: Commands

func json(_ object: Any) -> String {
    let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    return String(decoding: data, as: UTF8.self)
}

func tree(_ element: AXUIElement, _ depth: Int = 0) -> [String] {
    var line = String(repeating: "  ", count: depth) + role(element)
    let name = label(element), value = string(element, "AXValue")
    if !name.isEmpty { line += " label=\(json([name]).dropFirst().dropLast())" }
    if !value.isEmpty { line += " value=\(json([value]).dropFirst().dropLast())" }
    return [line] + children(element).flatMap { tree($0, depth + 1) }
}

func run(_ command: String, _ launcher: Launcher, _ args: [String]) throws -> String {
    switch command {
    case "status":
        let policy: String = switch NSRunningApplication(processIdentifier: launcher.pid)?.activationPolicy {
        case .regular: "regular"
        case .accessory: "accessory"
        case .prohibited: "prohibited"
        default: "unknown"
        }
        return json(["statusItem": launcher.statusItem != nil, "windowOpen": launcher.isOpen,
                     "windowFocused": launcher.window.map { string($0, "AXFocused") == "1" } ?? false,
                     "activationPolicy": policy])

    case "tree":
        guard let window = launcher.window else { return "(window closed)" }
        return tree(window).joined(separator: "\n")

    case "frame":
        guard let window = launcher.window, let frame = attribute(window, "AXFrame") else { throw fail("window is not open") }
        var rect = CGRect.zero
        AXValueGetValue(frame as! AXValue, .cgRect, &rect)
        return "\(Int(rect.minX)),\(Int(rect.minY)),\(Int(rect.width)),\(Int(rect.height))"

    case "rows":
        var rows: [String: String] = [:]
        for (i, picker) in try launcher.pickers().enumerated() { rows["\(i + 1)"] = string(picker, "AXValue") }
        return json(rows)

    case "click-icon":
        try launcher.clickIcon()
        return "clicked"

    case "open":
        if !launcher.isOpen { try launcher.clickIcon() }
        guard waitFor(3, { launcher.isOpen }) else { throw fail("window did not open within 3s") }
        return "open"

    case "close":
        if launcher.isOpen { try launcher.clickIcon() }
        guard waitFor(3, { !launcher.isOpen }) else { throw fail("window did not close within 3s") }
        return "closed"

    case "menu":
        guard args.count == 1 else { throw fail("menu takes <n>") }
        let menu = try launcher.openMenu(try launcher.picker(args[0]))
        defer { launcher.cancel(menu) }
        return children(menu).map { item in
            let title = string(item, "AXTitle")
            return (string(item, "AXMenuItemMarkChar").isEmpty ? "  " : "✓ ") + (title.isEmpty ? "---" : title)
        }.joined(separator: "\n")

    case "pick":
        guard args.count == 2 else { throw fail("pick takes <n> <title>") }
        let menu = try launcher.openMenu(try launcher.picker(args[0]))
        guard let item = children(menu).first(where: { string($0, "AXTitle") == args[1] }) else {
            let titles = children(menu).map { string($0, "AXTitle") }.filter { !$0.isEmpty }
            launcher.cancel(menu)
            throw fail("no menu item \(json([args[1]]).dropFirst().dropLast()); items: \(titles.joined(separator: ", "))")
        }
        try perform(item, "AXPress")
        pause(0.5)
        return "picked \(args[1]) for gesture \(args[0])"

    case "hand":
        let labels = ["left": "Left hand", "right": "Right hand"]
        guard args.count == 1, let wanted = labels[args[0]] else { throw fail("hand takes left | right") }
        guard let group = try launcher.controls().first(where: { role($0) == "AXRadioGroup" }),
              let button = children(group).first(where: { label($0) == wanted })
        else { throw fail("hand mode toggle not found") }
        try perform(button, "AXPress")
        pause(0.4)
        return "hand \(args[0])"

    case "press":
        let labels = ["quit": "Quit", "grant-access": "Grant access…", "trackpad-settings": "Trackpad settings…"]
        guard args.count == 1, let wanted = labels[args[0]] else { throw fail("press takes quit | grant-access | trackpad-settings") }
        guard let button = try launcher.controls().first(where: { role($0) == "AXButton" && label($0) == wanted }) else {
            throw fail("button \(wanted) is not shown in the current window state")
        }
        try perform(button, "AXPress")
        return "pressed \(wanted)"

    case "escape":
        // Posted to our PID, so it reaches the panel only if the panel is the app's key window,
        // and never any other app. Refuse rather than send it into the void.
        guard let window = launcher.window else { throw fail("window is not open") }
        guard string(window, "AXFocused") == "1" else { throw fail("window is open but not key; Escape would not reach it") }
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            CGEvent(keyboardEventSource: source, virtualKey: 53, keyDown: down)?.postToPid(launcher.pid)
        }
        return waitFor(2, { !launcher.isOpen }) ? "closed" : "still open"

    default:
        throw fail("unknown command \(command)")
    }
}

// MARK: Entry

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.first == "frontmost" {
    let app = NSWorkspace.shared.frontmostApplication
    print("\(app?.localizedName ?? "?") (\(app?.bundleIdentifier ?? "?"))")
    exit(0)
}
guard arguments.count >= 2, let pid = pid_t(arguments[1]) else {
    FileHandle.standardError.write(Data("usage: tlv-ax <status|tree|frame|rows|click-icon|open|close|menu|pick|hand|press|escape> <pid> [args] | tlv-ax frontmost\n".utf8))
    exit(2)
}
do {
    print(try run(arguments[0], try Launcher(pid: pid), Array(arguments.dropFirst(2))))
} catch {
    FileHandle.standardError.write(Data("tlv-ax: \(error)\n".utf8))
    exit(1)
}
