// Probe: what NSWorkspace reports as the frontmost application from a plain process, what identity and location
// it carries (bundle identifier and bundle URL, the two facts the catalog's `entry(at:)` parse needs), whether the
// activation notification is a push a menu bar app can observe (listens 6 s), and which app it names right now.
// Shows false if frontmostApplication is nil, lacks a bundle URL, or the notification never carries an app.
import AppKit
import Foundation

let workspace = NSWorkspace.shared
if let front = workspace.frontmostApplication {
    print("frontmostApplication: bundleIdentifier=\(front.bundleIdentifier ?? "nil") bundleURL=\(front.bundleURL?.path ?? "nil") name=\(front.localizedName ?? "nil") pid=\(front.processIdentifier) activationPolicy=\(front.activationPolicy.rawValue) isActive=\(front.isActive)")
} else {
    print("frontmostApplication: nil")
}
print("menuBarOwningApplication: \(workspace.menuBarOwningApplication?.bundleIdentifier ?? "nil")")
print("Info.plist under bundleURL exists: \(workspace.frontmostApplication?.bundleURL.map { FileManager.default.fileExists(atPath: $0.appending(path: "Contents/Info.plist").path) } ?? false)")

final class Seen: @unchecked Sendable { var lines: [String] = [] }
let seen = Seen()
let token = workspace.notificationCenter.addObserver(
    forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
) { note in
    let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    seen.lines.append("didActivate: \(app?.bundleIdentifier ?? "nil") url=\(app?.bundleURL?.path ?? "nil") thread=\(Thread.isMainThread ? "main" : "other")")
}
print("Listening 6 s for didActivateApplicationNotification (switch apps with Cmd-Tab if you are there)...")
RunLoop.main.run(until: Date(timeIntervalSinceNow: 6))
workspace.notificationCenter.removeObserver(token)
print("activations seen: \(seen.lines.count)")
seen.lines.forEach { print("  \($0)") }
print("done")
