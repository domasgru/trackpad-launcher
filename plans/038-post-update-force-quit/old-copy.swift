// Stands in for the old version at the update hand-over: it does what ApplicationsUpdater.openNewVersion and
// Lifecycle.replaced do, in the same order, with the same configuration, and nothing else. The bundle around it carries
// the Info.plist of the app under test, so macOS sees the same kind of parent. Built and used only by repro.sh.
//
// usage: open -n <this bundle> --args <path of the new version's bundle>
import AppKit

final class Delegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    /// The old version hands over from its settings window, which makes it a foreground-type app: loginwindow tracks such
    /// an app and acts on its death, and ignores the death of an LSUIElement app that never had a window.
    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.regular)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        self.window = window
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.handOver() }
    }

    private func handOver() {
        let bundle = URL(fileURLWithPath: CommandLine.arguments[1])
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundle, configuration: configuration) { app, _ in
            let didStart = app != nil
            DispatchQueue.main.async { if didStart { NSApp.terminate(nil) } else { exit(1) } }
        }
    }
}

let delegate = Delegate()
NSApplication.shared.delegate = delegate
withExtendedLifetime(delegate) { NSApplication.shared.run() }
