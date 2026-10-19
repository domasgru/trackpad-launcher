// Probe P4: what the "is this app running" read costs on the gesture path.
// Times NSRunningApplication.runningApplications(withBundleIdentifier:) for a running app and a
// not-running one, cold (first call in the process) and warm, and NSWorkspace.runningApplications.
import AppKit

func time(_ label: String, _ n: Int, _ body: () -> Int) {
    let t = CACurrentMediaTime()
    var c = 0
    for _ in 0..<n { c += body() }
    print(String(format: "%@: %.3f ms per call (n=%d, found %d)", label, (CACurrentMediaTime() - t) / Double(n) * 1000, n, c / n))
}
time("cold, not running (com.apple.Chess)", 1) { NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Chess").count }
time("warm, not running (com.apple.Chess)", 200) { NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Chess").count }
time("warm, running (com.apple.finder)", 200) { NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").count }
time("NSWorkspace.shared.runningApplications filter", 200) { NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == "com.apple.finder" }.count }
