// Shared AX read for the 042 probes, mirroring FrontmostAppWindows.read(): kAXWindows, then one
// CopyMultipleAttributeValues per window (role, subrole, title, minimised, AXFullScreen), then the private
// _AXUIElementGetWindow, then the CG lists. Compiled together with the probe that uses it.
import AppKit
import ApplicationServices

typealias GetWindow = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
let getWindow: GetWindow? = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementGetWindow")
    .map { unsafeBitCast($0, to: GetWindow.self) }

struct AXWindow: CustomStringConvertible {
    let number: UInt32?
    let role: String?
    let subrole: String?
    let title: String
    let minimised: Bool
    let fullScreen: Bool
    var description: String {
        "#\(number.map(String.init) ?? "nil") \(role ?? "-")/\(subrole ?? "-") min=\(minimised) fs=\(fullScreen) '\(title)'"
    }
}

struct AXRead {
    var error: AXError = .success
    var windows: [AXWindow] = []
    var seconds: Double = 0
    var calls: [(String, Double, AXError)] = []
}

func now() -> Double { ProcessInfo.processInfo.systemUptime }

let attributes = [kAXRoleAttribute, kAXSubroleAttribute, kAXTitleAttribute, kAXMinimizedAttribute, "AXFullScreen"]
    as CFArray

func readAX(_ pid: pid_t, traceCalls: Bool = false) -> AXRead {
    var result = AXRead()
    let start = now()
    readInto(&result, pid, traceCalls: traceCalls)
    result.seconds = now() - start
    return result
}

private func readInto(_ result: inout AXRead, _ pid: pid_t, traceCalls: Bool) {
    let app = AXUIElementCreateApplication(pid)
    var value: CFTypeRef?
    let t0 = now()
    result.error = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
    if traceCalls { result.calls.append(("windows", now() - t0, result.error)) }
    guard result.error == .success, let elements = value as? [AXUIElement] else { return }
    for element in elements {
        var values: CFArray?
        let t1 = now()
        let error = AXUIElementCopyMultipleAttributeValues(element, attributes, AXCopyMultipleAttributeOptions(rawValue: 0), &values)
        if traceCalls { result.calls.append(("multi", now() - t1, error)) }
        if error == .cannotComplete { result.error = error; break }
        guard error == .success, let list = values as? [AnyObject] else { continue }
        var number: CGWindowID = 0
        let t2 = now()
        let numberError = getWindow?(element, &number) ?? .failure
        if traceCalls { result.calls.append(("getWindow", now() - t2, numberError)) }
        result.windows.append(AXWindow(
            number: numberError == .success ? number : nil, role: list[0] as? String, subrole: list[1] as? String,
            title: list[2] as? String ?? "", minimised: list[3] as? Bool ?? false, fullScreen: list[4] as? Bool ?? false))
    }
}

struct CGEntry: CustomStringConvertible {
    let number: UInt32
    let onScreen: Bool
    let name: String?
    var description: String { "#\(number) onScreen=\(onScreen) '\(name ?? "<no name>")'" }
}

/// The pid's layer-0 windows from one system-wide copy.
func cgList(_ options: CGWindowListOption, of pid: pid_t) -> [CGEntry] {
    let all = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
    return all.compactMap { info in
        guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
            (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
            let number = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value
        else { return nil }
        return CGEntry(
            number: number, onScreen: (info[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false,
            name: info[kCGWindowName as String] as? String)
    }
}

/// Today's sort: visible = AXWindow/AXStandardWindow, not minimised, on screen, in CG order; minimised by flag alone.
func listed(_ read: AXRead, onScreen: [UInt32]) -> (visible: [UInt32], minimised: [UInt32]) {
    var standard = Set<UInt32>()
    var minimised: [UInt32] = []
    for window in read.windows {
        guard let number = window.number else { continue }
        if window.minimised { minimised.append(number) }
        else if window.role == "AXWindow", window.subrole == "AXStandardWindow" { standard.insert(number) }
    }
    return (onScreen.filter(standard.contains), minimised)
}

func ms(_ seconds: Double) -> String { String(format: "%.2f ms", seconds * 1000) }
