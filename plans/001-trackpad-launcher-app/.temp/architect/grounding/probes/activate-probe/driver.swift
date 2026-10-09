// Driver for the activation probe. A plain background process (like the real app: no UI focus)
// calls NSWorkspace.openApplication(at:configuration:) on the target in each state and reports.
// Shows false if: launch does not activate; a hidden app is not unhidden+activated; a minimized
// window is not deminiaturized; no reopen event reaches the running app; two near-simultaneous
// opens launch two instances; an already-active app's window frame changes.
import AppKit

let appURL = URL(fileURLWithPath: CommandLine.arguments[1])
let bundleID = "com.trackpadlauncher.probe.target"
let logPath = CommandLine.arguments[2]
func wait(_ s: Double) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }
func running() -> [NSRunningApplication] { NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) }
func front() -> String { NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil" }
func open(_ label: String) {
    let cfg = NSWorkspace.OpenConfiguration(); cfg.activates = true
    NSWorkspace.shared.openApplication(at: appURL, configuration: cfg) { app, err in
        print("  open[\(label)] -> pid=\(app?.processIdentifier ?? -1) err=\(err.map { "\($0)" } ?? "nil")")
    }
}
func post(_ name: String) { DistributedNotificationCenter.default().postNotificationName(Notification.Name(name), object: nil, userInfo: nil, deliverImmediately: true) }
func report(_ phase: String) {
    let r = running().first
    print("[\(phase)] instances=\(running().count) isActive=\(r?.isActive ?? false) isHidden=\(r?.isHidden ?? false) frontmost=\(front())")
}

print("driver pid=\(ProcessInfo.processInfo.processIdentifier) frontmost before=\(front())")
print("1. launch (not running)"); open("launch"); wait(2.5); report("launch")
print("2. hide via NSRunningApplication.hide(), then open"); _ = running().first?.hide(); wait(1); report("hidden"); open("unhide"); wait(1.5); report("after-open")
print("3. minimize window, then open"); post("tlprobe.minimize"); wait(1); open("deminiaturize"); wait(1.5); report("after-open")
print("4. close the only window, then open (expect reopen hasVisibleWindows=false)"); post("tlprobe.close"); wait(1); open("reopen-no-windows"); wait(1.5); report("after-open")
print("5. already active: open again (expect reopen hasVisibleWindows=true, frame unchanged)"); open("already-active"); wait(1.5); report("after-open")
print("6. quit, then open twice within 50 ms"); post("tlprobe.quit"); wait(2); report("quit"); open("double-1"); usleep(50_000); open("double-2"); wait(3); report("double")
post("tlprobe.quit"); wait(1.5); report("final")
print("--- target log ---"); print((try? String(contentsOfFile: logPath, encoding: .utf8)) ?? "(no log)")
