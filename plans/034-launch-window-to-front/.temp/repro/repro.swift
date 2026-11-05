// Reproduces "the settings window stays under other windows" on the real built app, launched the way a user does.
// usage: repro <app path> <bundle id> <trials>
// Modes:
//   cold-finder     app not running, Finder in front, Finder opens the app (double click)
//   cold-other      app not running, Calculator in front, LaunchServices opens the app (as Spotlight does)
//   reopen-finder   app running with its window closed, Finder in front, Finder opens the app
//   reopen-other    app running with its window closed, Calculator in front, LaunchServices opens the app
//   behind-other    app running with its window open behind Calculator, LaunchServices opens the app
import AppKit
import Foundation

let args = CommandLine.arguments
let appPath = args[1]
let bundleID = args[2]
let trials = Int(args[3])!
let variants = args[4].split(separator: ",").map(String.init)
let processName = "Trackpad Launcher"

@discardableResult func run(_ path: String, _ arguments: [String]) -> String {
    let process = Process()
    process.executableURL = URL(filePath: path)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    try! process.run()
    process.waitUntilExit()
    return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}
func osa(_ script: String) { run("/usr/bin/osascript", ["-e", script]) }
func pause(_ seconds: Double) { Thread.sleep(forTimeInterval: seconds) }

/// NSWorkspace's answer, which needs the run loop to turn. System Events' `frontmost` disagreed with the app's real
/// state in the reopen modes, and `lsappinfo front` answers `!!none` from this context.
func frontmost() -> String {
    RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    return NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
}

/// Layer-0 windows, front to back, by owner.
func windows() -> [(owner: String, name: String)] {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        as? [[String: Any]] ?? []
    return list.compactMap { info in
        guard (info[kCGWindowLayer as String] as? Int) == 0 else { return nil }
        let bounds = info[kCGWindowBounds as String] as? [String: Double] ?? [:]
        guard (bounds["Height"] ?? 0) > 60 else { return nil }
        return (info[kCGWindowOwnerName as String] as? String ?? "?", info[kCGWindowName as String] as? String ?? "")
    }
}

func isRunning() -> Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty }

func kill() {
    for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) { app.forceTerminate() }
    for _ in 0..<50 where isRunning() { pause(0.1) }
}

func settingsVisible() -> Bool { windows().contains { $0.owner == processName } }

func waitForWindow(_ open: Bool) -> Bool {
    for _ in 0..<80 {
        if settingsVisible() == open { return true }
        pause(0.1)
    }
    return false
}

func bringFinder() {
    osa("tell application \"Finder\" to activate")
    osa("tell application \"Finder\" to if (count of windows) is 0 then make new Finder window")
    pause(0.8)
}
func bringOther() {
    run("/usr/bin/open", ["-a", "Calculator"])
    osa("tell application \"Calculator\" to activate")
    pause(0.8)
}
func openByFinder() { osa("tell application \"Finder\" to open POSIX file \"\(appPath)\"") }
func openByLaunchServices() { run("/usr/bin/open", [appPath]) }

func openBySpotlight() {
    osa("""
    tell application "System Events"
        key code 49 using command down
        delay 0.7
        keystroke "Trackpad Launcher"
        delay 1.2
        key code 36
    end tell
    """)
}

/// Running, window closed: the scripted quit closes the settings window and keeps the process.
func runningWithWindowClosed() {
    if !isRunning() {
        openByLaunchServices()
        _ = waitForWindow(true)
        pause(0.5)
    }
    if settingsVisible() {
        osa("tell application id \"\(bundleID)\" to quit")
        _ = waitForWindow(false)
    }
    pause(0.5)
}

struct Outcome {
    let shown: Bool, front: String, order: [String]
    var good: Bool { shown && front == processName && order.first == processName }
}

func measure() -> Outcome {
    let shown = waitForWindow(true)
    pause(2.0)  // Let the activation settle: the verdict is the state the user is left with.
    return Outcome(shown: shown, front: frontmost(), order: Array(windows().map(\.owner).prefix(4)))
}

let onlySpotlight = args.count > 5 && args[5] == "spotlight"
let spotlightModes: [(String, () -> Void, () -> Void)] = [
    ("spotlight-cold", { kill(); bringOther() }, openBySpotlight),
    ("spotlight-reopen", { runningWithWindowClosed(); bringOther() }, openBySpotlight),
]
let allModes: [(String, () -> Void, () -> Void)] = [
    ("cold-finder", { kill(); bringFinder() }, openByFinder),
    ("cold-other", { kill(); bringOther() }, openByLaunchServices),
    ("reopen-finder", { runningWithWindowClosed(); bringFinder() }, openByFinder),
    ("reopen-other", { runningWithWindowClosed(); bringOther() }, openByLaunchServices),
    ("behind-other", {
        if !isRunning() || !settingsVisible() { openByLaunchServices(); _ = waitForWindow(true) }
        bringOther()
    }, openByLaunchServices),
]

for variant in variants {
try! variant.write(toFile: "/tmp/tl034-variant", atomically: true, encoding: .utf8)
print("#### variant \(variant)")
for (name, prepare, open) in onlySpotlight ? spotlightModes : allModes {
    var bad = 0
    for trial in 1...trials {
        prepare()
        let before = frontmost()
        open()
        let outcome = measure()
        if !outcome.good { bad += 1 }
        print("\(name) #\(trial) before=\(before) \(outcome.good ? "ok " : "BAD") shown=\(outcome.shown) front=\(outcome.front) order=\(outcome.order)")
    }
    print("== \(variant) \(name): \(bad)/\(trials) bad")
}
kill()
}
