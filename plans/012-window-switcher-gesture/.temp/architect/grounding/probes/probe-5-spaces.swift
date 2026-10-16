// Probe 5: windows on another Space and a full-screen front window. Launches TextEdit on two temp files
// (TextEdit must not be running), makes one window full screen through AXFullScreen (its own Space), and
// asks what kAXWindowsAttribute and the on-screen CGWindowList then say about the window left behind on
// the previous Space; then leaves full screen, quits TextEdit, re-activates the previous app, cleans up.
// Build: swiftc -O -parse-as-library -o probe-5-spaces probe-5-spaces.swift
import ApplicationServices
import AppKit
import Foundation

typealias GetWindowFn = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
let getWindowFn: GetWindowFn? = {
    guard let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementGetWindow") else { return nil }
    return unsafeBitCast(sym, to: GetWindowFn.self)
}()

func attr(_ el: AXUIElement, _ name: String) -> AnyObject? {
    var v: AnyObject?
    return AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success ? v : nil
}
func cgID(_ el: AXUIElement) -> CGWindowID? {
    guard let fn = getWindowFn else { return nil }
    var id: CGWindowID = 0
    return fn(el, &id) == .success ? id : nil
}
func sleep(_ s: Double) { Thread.sleep(forTimeInterval: s) }
func onScreenIDs() -> [CGWindowID] {
    (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? [])
        .compactMap { ($0[kCGWindowNumber as String] as? Int).map { CGWindowID($0) } }
}
func report(_ app: AXUIElement, label: String) {
    let ids = onScreenIDs()
    print("-- \(label)")
    for w in (attr(app, kAXWindowsAttribute) as? [AXUIElement]) ?? [] {
        let title = attr(w, kAXTitleAttribute) as? String ?? "<no title>"
        let subrole = attr(w, kAXSubroleAttribute) as? String ?? "?"
        let minimized = attr(w, kAXMinimizedAttribute) as? Bool ?? false
        let full = attr(w, "AXFullScreen") as? Bool
        let id = cgID(w)
        print("   title=\"\(title)\" subrole=\(subrole) minimized=\(minimized) fullScreen=\(full.map(String.init(describing:)) ?? "nil") cgid=\(id.map(String.init) ?? "nil") onScreen(CG)=\(id.map { ids.contains($0) } ?? false)")
    }
}

@main
struct Probe {
    static func main() throws {
        print("== Probe 5: another Space, full-screen front window")
        let previousFront = NSWorkspace.shared.frontmostApplication
        precondition(NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.TextEdit" } == nil, "TextEdit already running; aborting")
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("probe-5-\(getpid())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let names = ["Alpha.txt", "Beta.txt"]
        for n in names { try "Contents of \(n)\n".write(to: dir.appendingPathComponent(n), atomically: true, encoding: .utf8) }
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = ["-a", "TextEdit"] + names.map { dir.appendingPathComponent($0).path }
        try open.run(); open.waitUntilExit()
        var textEdit: NSRunningApplication?
        for _ in 0..<50 { sleep(0.2); textEdit = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.TextEdit" }; if textEdit != nil { break } }
        guard let textEdit else { print("TextEdit did not launch"); return }
        let app = AXUIElementCreateApplication(textEdit.processIdentifier)
        var windows: [AXUIElement] = []
        for _ in 0..<50 { sleep(0.2); windows = (attr(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []; if windows.count >= 2 { break } }
        sleep(0.5)
        var fullScreenWindow: AXUIElement?
        defer {
            if let w = fullScreenWindow, (attr(w, "AXFullScreen") as? Bool) == true {
                _ = AXUIElementSetAttributeValue(w, "AXFullScreen" as CFString, kCFBooleanFalse)
                sleep(2.0)
                print("Teardown: left full screen; fullScreen now:", attr(w, "AXFullScreen") as? Bool ?? false)
            }
            textEdit.terminate()
            sleep(0.5)
            previousFront?.activate()
            print("Teardown: TextEdit terminated, previous front re-activated:", previousFront?.localizedName ?? "nil")
        }
        report(app, label: "before full screen")
        guard let front = windows.first else { return }
        print("AXFullScreen settable:", { var s: DarwinBoolean = false; return AXUIElementIsAttributeSettable(front, "AXFullScreen" as CFString, &s) == .success && s.boolValue }())
        let err = AXUIElementSetAttributeValue(front, "AXFullScreen" as CFString, kCFBooleanTrue)
        print("set AXFullScreen=true err:", err.rawValue)
        fullScreenWindow = front
        sleep(2.5)
        report(app, label: "front window full screen (its own Space); the other window stayed on the previous Space")
        print("focused:", (attr(app, kAXFocusedWindowAttribute)).flatMap { attr($0 as! AXUIElement, kAXTitleAttribute) as? String } ?? "nil")
        print("AXRaise on the window on the other Space, err:", AXUIElementPerformAction(windows[1], kAXRaiseAction as CFString).rawValue)
        sleep(1.5)
        report(app, label: "after AXRaise of the other-Space window")
        print("front app now:", NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil")
    }
}
