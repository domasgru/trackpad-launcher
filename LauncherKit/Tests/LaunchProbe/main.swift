// A tiny app whose startup is scripted, for tests that launch a real app with NSWorkspace and watch it start. The
// script is the `ProbeScript` dictionary in the bundle's Info.plist; every key is optional and none means a window-less
// app. Seconds are numbers.
//   preSleep            sleep before NSApplication runs (a slow start)
//   crashAfter          sleep, then exit(3) before finishing launching
//   blockInWillFinish   block the main thread inside applicationWillFinishLaunching
//   windowWillFinish    show a window in applicationWillFinishLaunching
//   windowDidFinish     show a window in applicationDidFinishLaunching
//   windowAfter         show a window this long after applicationDidFinishLaunching
//   splash              show a borderless splash window at did-finish (with windowAfter, the main window comes later)
//   markerThenBlock     { marker: path, seconds: S }: on the first main-run-loop turn after finishing, write the
//                       marker file, block the main thread for S, then show a window
//   statusLevelWindow   show the only window at the status-window level, at did-finish
import AppKit

let script = Bundle.main.object(forInfoDictionaryKey: "ProbeScript") as? [String: Any] ?? [:]

@MainActor func seconds(_ key: String) -> Double? {
    (script[key] as? NSNumber)?.doubleValue
}

@MainActor func flag(_ key: String) -> Bool {
    (script[key] as? NSNumber)?.boolValue ?? false
}

if let preSleep = seconds("preSleep") { Thread.sleep(forTimeInterval: preSleep) }
if let crashAfter = seconds("crashAfter") {
    Thread.sleep(forTimeInterval: crashAfter)
    exit(3)
}

@MainActor final class Delegate: NSObject, NSApplicationDelegate {
    var windows: [NSWindow] = []

    func applicationWillFinishLaunching(_ notification: Notification) {
        if let blocked = seconds("blockInWillFinish") { Thread.sleep(forTimeInterval: blocked) }
        if flag("windowWillFinish") { show(titled: true) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if flag("windowDidFinish") { show(titled: true) }
        if flag("splash") { show(titled: false) }
        if flag("statusLevelWindow") { show(titled: true, level: .statusBar) }
        if let after = seconds("windowAfter") {
            DispatchQueue.main.asyncAfter(deadline: .now() + after) { MainActor.assumeIsolated { self.show(titled: true) } }
        }
        if let held = script["markerThenBlock"] as? [String: Any],
            let marker = held["marker"] as? String, let blocked = (held["seconds"] as? NSNumber)?.doubleValue
        {
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    FileManager.default.createFile(atPath: marker, contents: Data())
                    Thread.sleep(forTimeInterval: blocked)
                    self.show(titled: true)
                }
            }
        }
    }

    func show(titled: Bool, level: NSWindow.Level = .normal) {
        let window = NSWindow(
            contentRect: NSRect(x: 300, y: 300, width: 320, height: 200),
            styleMask: titled ? [.titled, .closable] : [.borderless], backing: .buffered, defer: false)
        window.title = "Probe"
        window.isReleasedWhenClosed = false
        window.backgroundColor = titled ? .windowBackgroundColor : .systemTeal
        window.level = level
        window.makeKeyAndOrderFront(nil)
        windows.append(window)
    }
}

let delegate = Delegate()
NSApplication.shared.delegate = delegate
NSApp.run()
