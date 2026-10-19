// Probe P1 helper: a tiny app whose startup is shaped by its launch arguments, so the
// observer probe (p1-lifecycle.swift) can time each lifecycle signal against a known script.
//   --pre-sleep S      sleep S seconds before NSApplication runs (a slow start)
//   --crash-after S    sleep S seconds, then exit(3) before finishing launching (crash during startup)
//   --window-will      show a window in applicationWillFinishLaunching (like state restoration)
//   --window-did       show a window in applicationDidFinishLaunching
//   --window-after S   show a window S seconds after applicationDidFinishLaunching
//   --splash           with --window-after: show a borderless splash window at did-finish first
//   (no window flag)   open no window at all
import AppKit

let args = CommandLine.arguments
func argValue(_ key: String) -> Double? {
    guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
    return Double(args[i + 1])
}
if let s = argValue("--pre-sleep") { Thread.sleep(forTimeInterval: s) }
if let c = argValue("--crash-after") { Thread.sleep(forTimeInterval: c); exit(3) }

final class Delegate: NSObject, NSApplicationDelegate {
    var windows: [NSWindow] = []
    func applicationWillFinishLaunching(_ n: Notification) {
        if args.contains("--window-will") { show(titled: true) }
    }
    func applicationDidFinishLaunching(_ n: Notification) {
        if args.contains("--window-did") { show(titled: true) }
        if args.contains("--splash") { show(titled: false) }
        if let d = argValue("--window-after") {
            DispatchQueue.main.asyncAfter(deadline: .now() + d) { self.show(titled: true) }
        }
    }
    func show(titled: Bool) {
        let w = NSWindow(contentRect: NSRect(x: 300, y: 300, width: 320, height: 200),
                         styleMask: titled ? [.titled, .closable] : [.borderless],
                         backing: .buffered, defer: false)
        w.title = "Probe"
        w.isReleasedWhenClosed = false
        w.backgroundColor = titled ? .windowBackgroundColor : .systemTeal
        w.makeKeyAndOrderFront(nil)
        windows.append(w)
    }
}
let delegate = Delegate()
NSApplication.shared.delegate = delegate
NSApp.run()
