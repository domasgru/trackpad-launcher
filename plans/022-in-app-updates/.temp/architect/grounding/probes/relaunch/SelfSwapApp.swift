// A minimal background app for self-relaunch.sh. On launch it appends "launch pid=<pid> version=<v>" to the
// log named by its Info.plist key ProbeLog. When its Info.plist also names ProbeSelfSwapFrom (a staged bundle),
// it then replaces ITS OWN bundle with that staged bundle (FileManager.replaceItemAt, as BundleInstall.swap does)
// and calls NSWorkspace.openApplication(at:) on its own bundle path, logging what openApplication answers.
// A reopen Apple event is logged as "reopen pid=<pid>". It keeps running until killed.
import AppKit

final class Delegate: NSObject, NSApplicationDelegate {
    let log = Bundle.main.object(forInfoDictionaryKey: "ProbeLog") as? String ?? "/tmp/probe.log"
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    func append(_ line: String) {
        let h = FileHandle(forUpdatingAtPath: log) ?? { FileManager.default.createFile(atPath: log, contents: nil); return FileHandle(forUpdatingAtPath: log)! }()
        h.seekToEndOfFile(); h.write(Data((line + "\n").utf8)); h.closeFile()
    }
    func applicationDidFinishLaunching(_ n: Notification) {
        append("launch pid=\(getpid()) version=\(version)")
        guard let staged = Bundle.main.object(forInfoDictionaryKey: "ProbeSelfSwapFrom") as? String else { return }
        let own = Bundle.main.bundleURL
        do {
            _ = try FileManager.default.replaceItemAt(own, withItemAt: URL(filePath: staged))
            append("self-swapped pid=\(getpid())")
        } catch { append("self-swap failed: \(error)"); return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance =
            (Bundle.main.object(forInfoDictionaryKey: "ProbeNewInstance") as? Bool) ?? false
        append("createsNewApplicationInstance=\(configuration.createsNewApplicationInstance)")
        NSWorkspace.shared.openApplication(at: own, configuration: configuration) { app, error in
            let pid = app.map { String($0.processIdentifier) } ?? "nil"
            DispatchQueue.main.async { self.append("openApplication answered pid=\(pid) error=\(error.map { "\($0)" } ?? "nil") (caller pid=\(getpid()))") }
        }
    }
    func applicationShouldHandleReopen(_ s: NSApplication, hasVisibleWindows: Bool) -> Bool {
        append("reopen pid=\(getpid()) version=\(version)")
        return false
    }
}

let delegate = Delegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
