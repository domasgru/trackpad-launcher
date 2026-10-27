// Throwaway LSUIElement app for plan 021's lifecycle probe. Logs to /tmp/tl021probe/log.txt.
// Behaviour switches are files in /tmp/tl021probe/flags/ read at each reopen or quit:
//   allow-quit  -> applicationShouldTerminate returns .terminateNow
//   close       -> the next reopen closes the window (and goes back to .accessory) instead of showing it
//   bring       -> after showing the window on reopen, open Calculator with activates = true
import AppKit

let root = "/tmp/tl021probe"
func flag(_ name: String) -> Bool { FileManager.default.fileExists(atPath: "\(root)/flags/\(name)") }
func log(_ line: String) {
    let pid = ProcessInfo.processInfo.processIdentifier
    let version = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    let text = "[pid \(pid) v\(version)] \(line)\n"
    let url = URL(fileURLWithPath: "\(root)/log.txt")
    if let handle = try? FileHandle(forWritingTo: url) {
        handle.seekToEndOfFile(); handle.write(text.data(using: .utf8)!); try? handle.close()
    } else {
        try? text.data(using: .utf8)!.write(to: url)
    }
}
func fourCC(_ code: UInt32) -> String {
    let bytes = [24, 16, 8, 0].map { UInt8((code >> UInt32($0)) & 0xFF) }
    return String(bytes: bytes, encoding: .macOSRoman) ?? "\(code)"
}
func describe(_ event: NSAppleEventDescriptor?) -> String {
    guard let event else { return "no current Apple event" }
    let prop = event.paramDescriptor(forKeyword: keyAEPropData)
    let reasonParam = event.paramDescriptor(forKeyword: AEKeyword(kAEQuitReason))
    let reasonAttr = event.attributeDescriptor(forKeyword: AEKeyword(kAEQuitReason))
    let senderPID = event.attributeDescriptor(forKeyword: AEKeyword(keySenderPIDAttr))?.int32Value
    var sender = "?"
    if let senderPID, let app = NSRunningApplication(processIdentifier: pid_t(senderPID)) {
        sender = "\(senderPID) \(app.bundleIdentifier ?? app.localizedName ?? "unnamed")"
    } else if let senderPID { sender = "\(senderPID) (no NSRunningApplication)" }
    return "event \(fourCC(event.eventClass))/\(fourCC(event.eventID)) propData=\(prop.map { fourCC($0.enumCodeValue) } ?? "none") "
        + "quitReasonParam=\(reasonParam.map { fourCC($0.enumCodeValue) } ?? "none") quitReasonAttr=\(reasonAttr.map { fourCC($0.enumCodeValue) } ?? "none") sender=\(sender)"
}

final class Delegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow?

    func applicationWillFinishLaunching(_ notification: Notification) {
        log("willFinishLaunching path=\(Bundle.main.bundlePath) policy=\(NSApp.activationPolicy().rawValue) \(describe(NSAppleEventManager.shared().currentAppleEvent))")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let isDefault = notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool
        log("didFinishLaunching isDefaultLaunch=\(isDefault.map(String.init) ?? "absent") \(describe(NSAppleEventManager.shared().currentAppleEvent))")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        log("reopen hasVisibleWindows=\(flag) isActive=\(NSApp.isActive) \(describe(NSAppleEventManager.shared().currentAppleEvent))")
        if tl021Flag("close") { closeWindow(); return false }
        showWindow()
        if tl021Flag("bring") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/Calculator.app"), configuration: configuration) { _, error in
                    log("bring: openApplication error=\(error.map { "\($0)" } ?? "nil")")
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.report("after bring") }
            }
        }
        return false
    }

    func showWindow() {
        NSApp.setActivationPolicy(.regular)
        if window == nil {
            let made = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
                                styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            made.title = "TL021 Probe"
            made.isReleasedWhenClosed = false
            made.delegate = self
            window = made
        }
        if let window {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.report("after show") }
    }

    func closeWindow() { window?.close() }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.report("after close") }
    }

    func report(_ label: String) {
        let front = NSWorkspace.shared.frontmostApplication
        log("\(label): policy=\(NSApp.activationPolicy().rawValue) isActive=\(NSApp.isActive) windowVisible=\(window?.isVisible ?? false) windowKey=\(window?.isKeyWindow ?? false) frontmost=\(front?.bundleIdentifier ?? "nil") frontmostIsSelf=\(front?.processIdentifier == ProcessInfo.processInfo.processIdentifier)")
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let allow = tl021Flag("allow-quit")
        log("shouldTerminate allow=\(allow) \(describe(NSAppleEventManager.shared().currentAppleEvent))")
        if allow { return .terminateNow }
        closeWindow()
        return .terminateCancel
    }
}

func tl021Flag(_ name: String) -> Bool { flag(name) }

let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.run()
