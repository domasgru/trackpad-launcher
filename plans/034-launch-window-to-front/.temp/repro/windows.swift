// Reads, without touching anything, what the user is left with: the frontmost app, whether the app under test is
// active, and the on-screen windows front to back at every level. It sends no input and needs no permission (window
// names may be blank without Screen Recording; owners and levels are always there). The alert of a move dialog sits at
// the modal panel level (8), which repro.swift's layer-0 read skips.
// usage: windows <bundle id> <seconds to wait before reading>
import AppKit
import Foundation

let args = CommandLine.arguments
let bundleID = args[1]
let delay = Double(args[2])!

// NSWorkspace's and NSRunningApplication's answers need the run loop to turn.
RunLoop.current.run(until: Date().addingTimeInterval(delay))

let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
print("frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "?")")
print("target running=\(!running.isEmpty) active=\(running.contains(where: \.isActive))")

let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
    as? [[String: Any]] ?? []
let visible = list.filter { info in
    let bounds = info[kCGWindowBounds as String] as? [String: Double] ?? [:]
    let layer = info[kCGWindowLayer as String] as? Int ?? 0
    return (bounds["Height"] ?? 0) > 60 && (0..<20).contains(layer)
}
for info in visible.prefix(8) {
    let owner = info[kCGWindowOwnerName as String] as? String ?? "?"
    let layer = info[kCGWindowLayer as String] as? Int ?? 0
    let bounds = info[kCGWindowBounds as String] as? [String: Double] ?? [:]
    print("window owner=\(owner) layer=\(layer) size=\(Int(bounds["Width"] ?? 0))x\(Int(bounds["Height"] ?? 0))")
}
