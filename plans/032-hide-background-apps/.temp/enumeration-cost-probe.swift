// Probe: what enumerating the Dock apps costs on the gesture path (reads only; hides nothing).
import AppKit

func time(_ label: String, _ body: () -> Int) {
    var best = Double.infinity
    var count = 0
    for _ in 0..<20 {
        let t0 = DispatchTime.now().uptimeNanoseconds
        count = body()
        best = min(best, Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e6)
    }
    print(String(format: "%@: best %.3f ms (%d)", label, best, count))
}
_ = NSWorkspace.shared.runningApplications
time("runningApplications, all") { NSWorkspace.shared.runningApplications.count }
time("runningApplications, .regular only") { NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.count }
time("regular + bundleIdentifier read") {
    NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.bundleIdentifier != "x" }.count
}
time("frontmostApplication read") { NSWorkspace.shared.frontmostApplication == nil ? 0 : 1 }
