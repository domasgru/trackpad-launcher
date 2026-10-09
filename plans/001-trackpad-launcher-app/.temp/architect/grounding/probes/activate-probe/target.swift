// Target app for the activation probe: one window; obeys distributed notifications
// "tlprobe.minimize", "tlprobe.close"; logs lifecycle facts to $TLPROBE_LOG.
import AppKit

let logPath = ProcessInfo.processInfo.environment["TLPROBE_LOG"] ?? "/tmp/tlprobe-target.log"
func log(_ s: String) {
    let line = "\(Date().timeIntervalSince1970) \(s)\n"
    if let h = FileHandle(forWritingAtPath: logPath) { h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); h.closeFile() }
    else { FileManager.default.createFile(atPath: logPath, contents: line.data(using: .utf8)) }
}

final class Delegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var w: NSWindow!
    func applicationDidFinishLaunching(_ n: Notification) {
        w = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 320, height: 180), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        w.title = "TLProbeTarget"; w.delegate = self; w.isReleasedWhenClosed = false
        w.makeKeyAndOrderFront(nil)
        log("launched pid=\(ProcessInfo.processInfo.processIdentifier) frame=\(w.frame)")
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: Notification.Name("tlprobe.minimize"), object: nil, queue: .main) { _ in self.w.miniaturize(nil); self.log2("minimized mini=\(self.w.isMiniaturized)") }
        dnc.addObserver(forName: Notification.Name("tlprobe.close"), object: nil, queue: .main) { _ in self.w.orderOut(nil); self.log2("closed visible=\(self.w.isVisible)") }
        dnc.addObserver(forName: Notification.Name("tlprobe.quit"), object: nil, queue: .main) { _ in NSApp.terminate(nil) }
    }
    func log2(_ s: String) { log(s) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        log("reopen hasVisibleWindows=\(flag) hidden=\(NSApp.isHidden) mini=\(w.isMiniaturized) frame=\(w.frame)"); return true
    }
    func applicationDidBecomeActive(_ n: Notification) { log("didBecomeActive hidden=\(NSApp.isHidden) mini=\(w.isMiniaturized) visible=\(w.isVisible) frame=\(w.frame)") }
    func applicationDidResignActive(_ n: Notification) { log("didResignActive") }
    func applicationDidUnhide(_ n: Notification) { log("didUnhide") }
    func applicationDidHide(_ n: Notification) { log("didHide") }
    func windowDidDeminiaturize(_ n: Notification) { log("windowDidDeminiaturize frame=\(w.frame)") }
    func windowDidMiniaturize(_ n: Notification) { log("windowDidMiniaturize") }
    func applicationWillTerminate(_ n: Notification) { log("terminating") }
}
let app = NSApplication.shared
let d = Delegate(); app.delegate = d
app.setActivationPolicy(.regular)
app.run()
