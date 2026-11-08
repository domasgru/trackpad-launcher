// Probe C: can a hidden app's document windows be told from its panels, and what do apps listing no windows have?
// 1. Fixture (W1, W2 visible, W3 minimised, a floating panel, a plain panel), shown and hidden: per window, the
//    subrole and the presence of the minimise, zoom, full-screen and close buttons.
// 2. Every regular running app whose AX list holds no standard window: its raw AX list and its layer-0 CG windows.
// Usage: probe_hidden <path to compiled fixture>. Terminates the fixture at the end.
import AppKit
import ApplicationServices

setvbuf(stdout, nil, _IONBF, 0)
AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.2)

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

func describe(_ pid: pid_t) {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXWindowsAttribute as CFString, &value) == .success,
        let elements = value as? [AXUIElement]
    else { print("    no AX window list"); return }
    for element in elements {
        let title = attribute(element, kAXTitleAttribute) as? String ?? ""
        let subrole = attribute(element, kAXSubroleAttribute) as? String ?? "-"
        let minimised = attribute(element, kAXMinimizedAttribute) as? Bool ?? false
        let buttons = [("min", kAXMinimizeButtonAttribute), ("zoom", kAXZoomButtonAttribute),
                       ("fs", "AXFullScreenButton"), ("close", kAXCloseButtonAttribute)]
            .map { "\($0.0)=\(attribute(element, $0.1) != nil ? "y" : "n")" }.joined(separator: " ")
        var number: CGWindowID = 0
        _ = getWindow?(element, &number)
        print("    #\(number) '\(title)' \(subrole) minimised=\(minimised) \(buttons)")
    }
}

let fixture = Process()
fixture.executableURL = URL(fileURLWithPath: CommandLine.arguments[1])
let toFixture = Pipe()
let fromFixture = Pipe()
fixture.standardInput = toFixture
fixture.standardOutput = fromFixture
try! fixture.run()
var buffer = ""
func line() -> String {
    while true {
        if let range = buffer.range(of: "\n") {
            let found = String(buffer[..<range.lowerBound])
            buffer.removeSubrange(..<range.upperBound)
            return found
        }
        let data = fromFixture.fileHandleForReading.availableData
        if data.isEmpty { fatalError("fixture ended") }
        buffer += String(decoding: data, as: UTF8.self)
    }
}
func send(_ command: String) -> String {
    toFixture.fileHandleForWriting.write((command + "\n").data(using: .utf8)!)
    return line()
}
func pause(_ seconds: Double) { RunLoop.current.run(until: Date().addingTimeInterval(seconds)) }

print("fixture:", line())
let pid = fixture.processIdentifier
print("\n== 1. fixture shown")
describe(pid)
_ = send("hide")
pause(1.0)
print("== 1. fixture hidden (NSRunningApplication.isHidden=\(NSRunningApplication(processIdentifier: pid)?.isHidden ?? false))")
describe(pid)
_ = send("unhide")
pause(0.5)
print("fixture:", send("quit"))
fixture.waitUntilExit()

print("\n== 2. regular apps whose AX list has no AXStandardWindow")
for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && app.processIdentifier != getpid() {
    let read = readAX(app.processIdentifier)
    guard !read.windows.contains(where: { $0.subrole == "AXStandardWindow" }) else { continue }
    print("  \(app.localizedName ?? "?") hidden=\(app.isHidden) AX error=\(read.error.rawValue) AX windows=\(read.windows.count)")
    describe(app.processIdentifier)
    let all = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    for info in all where (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == app.processIdentifier
        && (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0 {
        let bounds = (info[kCGWindowBounds as String] as? NSDictionary).flatMap { CGRect(dictionaryRepresentation: $0) } ?? .zero
        print("    CG #\(info[kCGWindowNumber as String] ?? "?") onScreen=\(info[kCGWindowIsOnscreen as String] ?? false) alpha=\(info[kCGWindowAlpha as String] ?? "?") \(Int(bounds.width))x\(Int(bounds.height))")
    }
}
