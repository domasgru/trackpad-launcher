// Probe 2: what the Accessibility API and CGWindowList say about an app's windows, and what AXRaise,
// kAXMinimized and kAXFocusedWindow do. Launches TextEdit on three temp files (TextEdit must not be
// running beforehand), exercises it, then quits TextEdit, re-activates the app that was in front and
// deletes the temp files. Needs Accessibility trust for this process.
// Build: swiftc -O -parse-as-library -o probe-2-ax-windows probe-2-ax-windows.swift
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
    let err = AXUIElementCopyAttributeValue(el, name as CFString, &v)
    return err == .success ? v : nil
}

func attrErr(_ el: AXUIElement, _ name: String) -> AXError {
    var v: AnyObject?
    return AXUIElementCopyAttributeValue(el, name as CFString, &v)
}

func point(_ el: AXUIElement, _ name: String) -> CGPoint? {
    guard let v = attr(el, name) else { return nil }
    var p = CGPoint.zero
    return AXValueGetValue(v as! AXValue, .cgPoint, &p) ? p : nil
}

func size(_ el: AXUIElement, _ name: String) -> CGSize? {
    guard let v = attr(el, name) else { return nil }
    var s = CGSize.zero
    return AXValueGetValue(v as! AXValue, .cgSize, &s) ? s : nil
}

func cgID(_ el: AXUIElement) -> CGWindowID? {
    guard let fn = getWindowFn else { return nil }
    var id: CGWindowID = 0
    return fn(el, &id) == .success ? id : nil
}

func describe(_ w: AXUIElement) -> String {
    let title = attr(w, kAXTitleAttribute) as? String ?? "<no title>"
    let role = attr(w, kAXRoleAttribute) as? String ?? "?"
    let subrole = attr(w, kAXSubroleAttribute) as? String ?? "?"
    let minimized = attr(w, kAXMinimizedAttribute) as? Bool
    let main = attr(w, kAXMainAttribute) as? Bool
    let focused = attr(w, kAXFocusedAttribute) as? Bool
    let p = point(w, kAXPositionAttribute)
    let s = size(w, kAXSizeAttribute)
    return "title=\"\(title)\" role=\(role) subrole=\(subrole) minimized=\(minimized.map(String.init(describing:)) ?? "nil") main=\(main.map(String.init(describing:)) ?? "nil") focused=\(focused.map(String.init(describing:)) ?? "nil") pos=\(p.map { "\($0.x),\($0.y)" } ?? "nil") size=\(s.map { "\($0.width)x\($0.height)" } ?? "nil") cgid=\(cgID(w).map(String.init) ?? "nil")"
}

func axWindows(_ app: AXUIElement) -> [AXUIElement] {
    (attr(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
}

func cgWindows(pid: pid_t, option: CGWindowListOption) -> [[String: Any]] {
    let list = CGWindowListCopyWindowInfo(option, kCGNullWindowID) as? [[String: Any]] ?? []
    return list.filter { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }
}

func describeCG(_ w: [String: Any]) -> String {
    let number = w[kCGWindowNumber as String] as? Int ?? -1
    let layer = w[kCGWindowLayer as String] as? Int ?? -1
    let name = w[kCGWindowName as String] as? String
    let onscreen = w[kCGWindowIsOnscreen as String] as? Bool
    let alpha = w[kCGWindowAlpha as String] as? Double ?? -1
    var bounds = CGRect.zero
    if let b = w[kCGWindowBounds as String] as? NSDictionary { bounds = CGRect(dictionaryRepresentation: b) ?? .zero }
    return "number=\(number) layer=\(layer) name=\(name.map { "\"\($0)\"" } ?? "nil") onscreen=\(onscreen.map(String.init(describing:)) ?? "nil") alpha=\(alpha) bounds=\(bounds.origin.x),\(bounds.origin.y) \(bounds.width)x\(bounds.height)"
}

func ms(_ start: DispatchTime) -> String {
    String(format: "%.2f ms", Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e6)
}

func sleep(_ s: Double) { Thread.sleep(forTimeInterval: s) }

@main
struct Probe {
    static func main() throws {
        print("== Probe 2: AX windows, CGWindowList, raise, minimise, focus")
        print("AXIsProcessTrusted:", AXIsProcessTrusted(), " _AXUIElementGetWindow resolved:", getWindowFn != nil)
        let previousFront = NSWorkspace.shared.frontmostApplication
        print("Front app before:", previousFront?.localizedName ?? "nil")
        precondition(NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.TextEdit" } == nil, "TextEdit already running; aborting to leave it alone")

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("probe-2-\(getpid())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let names = ["Alpha.txt", "Beta.txt", "Gamma.txt"]
        for n in names { try "Contents of \(n)\n".write(to: dir.appendingPathComponent(n), atomically: true, encoding: .utf8) }

        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = ["-a", "TextEdit"] + names.map { dir.appendingPathComponent($0).path }
        try open.run(); open.waitUntilExit()

        var textEdit: NSRunningApplication?
        for _ in 0..<50 {
            sleep(0.2)
            textEdit = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.TextEdit" }
            if textEdit != nil { break }
        }
        guard let textEdit else { print("TextEdit did not launch"); return }
        defer {
            textEdit.terminate()
            sleep(0.5)
            previousFront?.activate()
            print("Teardown: TextEdit terminated, previous front re-activated:", previousFront?.localizedName ?? "nil")
        }
        let pid = textEdit.processIdentifier
        let app = AXUIElementCreateApplication(pid)
        var windows: [AXUIElement] = []
        for _ in 0..<50 { sleep(0.2); windows = axWindows(app); if windows.count >= 3 { break } }
        sleep(0.5)

        print("\n-- AX windows (kAXWindowsAttribute order), \(windows.count) windows")
        var t = DispatchTime.now()
        windows = axWindows(app)
        print("kAXWindowsAttribute read took", ms(t))
        t = DispatchTime.now()
        for w in windows { print("  ", describe(w)) }
        print("describing \(windows.count) windows (8 attributes each) took", ms(t))
        print("kAXWindowsAttribute error code when read:", attrErr(app, kAXWindowsAttribute).rawValue)

        print("\n-- CGWindowList on-screen, excluding desktop elements, front to back (pid \(pid))")
        t = DispatchTime.now()
        let onscreen = cgWindows(pid: pid, option: [.optionOnScreenOnly, .excludeDesktopElements])
        print("CGWindowListCopyWindowInfo took", ms(t))
        for w in onscreen { print("  ", describeCG(w)) }
        print("-- CGWindowList optionAll for the pid")
        for w in cgWindows(pid: pid, option: [.optionAll]) { print("  ", describeCG(w)) }

        func focusedTitle() -> String {
            guard let f = attr(app, kAXFocusedWindowAttribute) else { return "nil" }
            return attr(f as! AXUIElement, kAXTitleAttribute) as? String ?? "<no title>"
        }
        func mainTitle() -> String {
            guard let f = attr(app, kAXMainWindowAttribute) else { return "nil" }
            return attr(f as! AXUIElement, kAXTitleAttribute) as? String ?? "<no title>"
        }
        func order() -> [String] {
            cgWindows(pid: pid, option: [.optionOnScreenOnly, .excludeDesktopElements])
                .filter { ($0[kCGWindowLayer as String] as? Int) == 0 }
                .map { ($0[kCGWindowName as String] as? String) ?? "?" }
        }
        print("\nFocused window (TextEdit inactive):", focusedTitle(), " main:", mainTitle(), " front app:", NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil")

        // AXRaise while TextEdit is NOT the active app
        guard let back = windows.last, let front = windows.first else { return }
        let backTitle = attr(back, kAXTitleAttribute) as? String ?? "?"
        print("\n-- AXRaise \"\(backTitle)\" while TextEdit is inactive")
        t = DispatchTime.now()
        let raiseErr = AXUIElementPerformAction(back, kAXRaiseAction as CFString)
        print("AXRaise took", ms(t), "err", raiseErr.rawValue)
        sleep(0.3)
        print("CG order now:", order(), " focused:", focusedTitle(), " main:", mainTitle(), " front app:", NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil")

        // Activate TextEdit, then raise the first window
        print("\n-- activate TextEdit, then AXRaise the original front window")
        textEdit.activate()
        sleep(0.5)
        print("front app:", NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil", " focused:", focusedTitle(), " CG order:", order())
        t = DispatchTime.now()
        _ = AXUIElementPerformAction(front, kAXRaiseAction as CFString)
        print("AXRaise took", ms(t))
        sleep(0.3)
        print("CG order now:", order(), " focused:", focusedTitle(), " main:", mainTitle())

        // Set kAXFocusedWindow on the app to the back window
        print("\n-- set kAXFocusedWindowAttribute on the app element to \"\(backTitle)\"")
        let setErr = AXUIElementSetAttributeValue(app, kAXFocusedWindowAttribute as CFString, back)
        sleep(0.3)
        print("set err", setErr.rawValue, " focused:", focusedTitle(), " CG order:", order())
        print("-- set kAXMainAttribute=true on the front window")
        let setMain = AXUIElementSetAttributeValue(front, kAXMainAttribute as CFString, kCFBooleanTrue)
        sleep(0.3)
        print("set err", setMain.rawValue, " focused:", focusedTitle(), " main:", mainTitle(), " CG order:", order())

        // Minimise the middle window
        let middle = windows[1]
        let middleTitle = attr(middle, kAXTitleAttribute) as? String ?? "?"
        print("\n-- set kAXMinimizedAttribute=true on \"\(middleTitle)\"")
        t = DispatchTime.now()
        let minErr = AXUIElementSetAttributeValue(middle, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        print("set took", ms(t), "err", minErr.rawValue)
        sleep(1.0)
        print("AX windows now:")
        for w in axWindows(app) { print("  ", describe(w)) }
        print("CG on-screen order:", order())
        print("CG optionAll entries for the minimised window present:", cgWindows(pid: pid, option: [.optionAll]).contains { ($0[kCGWindowName as String] as? String) == middleTitle })
        print("focused:", focusedTitle(), " main:", mainTitle())

        print("\n-- AXRaise the minimised window (does it restore?)")
        _ = AXUIElementPerformAction(middle, kAXRaiseAction as CFString)
        sleep(0.8)
        print("minimized now:", attr(middle, kAXMinimizedAttribute) as? Bool ?? false, " CG order:", order(), " focused:", focusedTitle())

        print("\n-- set kAXMinimizedAttribute=false (restore)")
        t = DispatchTime.now()
        let restoreErr = AXUIElementSetAttributeValue(middle, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        print("set took", ms(t), "err", restoreErr.rawValue)
        sleep(1.0)
        print("minimized now:", attr(middle, kAXMinimizedAttribute) as? Bool ?? false, " CG order:", order(), " focused:", focusedTitle(), " main:", mainTitle())

        // Re-stack by raising back to front: desired order Gamma, Alpha, Beta
        print("\n-- re-stack to [\(names[2]), \(names[0]), \(names[1])] by raising Beta, Alpha, Gamma in that order")
        let byTitle = Dictionary(uniqueKeysWithValues: axWindows(app).compactMap { w in (attr(w, kAXTitleAttribute) as? String).map { ($0, w) } })
        t = DispatchTime.now()
        for title in [names[1], names[0], names[2]] { if let w = byTitle[title] { _ = AXUIElementPerformAction(w, kAXRaiseAction as CFString) } }
        print("three raises took", ms(t))
        sleep(0.3)
        print("CG order now:", order(), " focused:", focusedTitle())

        // Close a window and see what AX and CG say about its element
        print("\n-- close \"\(names[2])\" via its close button, then query the stale element")
        if let w = byTitle[names[2]], let button = attr(w, kAXCloseButtonAttribute) {
            _ = AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
            sleep(0.5)
            print("stale element title err:", attrErr(w, kAXTitleAttribute).rawValue, " (kAXErrorInvalidUIElement = \(AXError.invalidUIElement.rawValue))")
            print("AXRaise on stale element err:", AXUIElementPerformAction(w, kAXRaiseAction as CFString).rawValue)
            print("CG order now:", order(), " AX windows:", axWindows(app).count)
        }
    }
}
