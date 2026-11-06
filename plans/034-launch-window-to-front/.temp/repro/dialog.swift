// R1's and R2's cold openings with Calculator in front, read without input: the system's frontmost app and active flag,
// the windows in front at every level and, where a probe build wrote it, the app's own state in /tmp/tl034-probe.
// It sends no keystrokes or clicks and force-terminates the copy after each trial; it never answers the dialog.
// usage: dialog <app path> <bundle id> <trials> <dialog|window> <variant,variant,…>
import AppKit
import Foundation

let args = CommandLine.arguments
let appPath = args[1]
let bundleID = args[2]
let trials = Int(args[3])!
let opening = args[4]
let variants = args[5].split(separator: ",").map(String.init)
let probe = "/tmp/tl034-probe"

func run(_ path: String, _ arguments: [String]) {
    let process = Process()
    process.executableURL = URL(filePath: path)
    process.arguments = arguments
    try! process.run()
    process.waitUntilExit()
}
func pause(_ seconds: Double) { RunLoop.current.run(until: Date().addingTimeInterval(seconds)) }
func copies() -> [NSRunningApplication] { NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) }
func kill() {
    for app in copies() { app.forceTerminate() }
    for _ in 0..<50 where !copies().isEmpty { pause(0.1) }
}
func windows() -> [String] {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        as? [[String: Any]] ?? []
    return list.compactMap { info in
        let bounds = info[kCGWindowBounds as String] as? [String: Double] ?? [:]
        let layer = info[kCGWindowLayer as String] as? Int ?? 0
        guard (bounds["Height"] ?? 0) > 60, (0..<20).contains(layer) else { return nil }
        return "\(info[kCGWindowOwnerName as String] as? String ?? "?")@\(layer)"
    }
}

for variant in variants {
    try! variant.write(toFile: "/tmp/tl034-variant", atomically: true, encoding: .utf8)
    var active = 0
    for trial in 1...trials {
        kill()
        try? FileManager.default.removeItem(atPath: probe)
        run("/usr/bin/open", ["-a", "Calculator"])
        pause(1.0)
        let before = NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
        run("/usr/bin/open", opening == "dialog" ? [appPath, "--args", "--as-release-build"] : [appPath])
        pause(3.5)
        let isActive = copies().contains(where: \.isActive)
        if isActive { active += 1 }
        let front = NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
        let state = (try? String(contentsOfFile: probe, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "no probe"
        print("\(variant) #\(trial) before=\(before) front=\(front) active=\(isActive) order=\(windows().prefix(3)) app: \(state)")
        kill()
    }
    print("== \(variant): \(active)/\(trials) active")
}
