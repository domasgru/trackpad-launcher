// A minimal background app for relaunch.sh. On launch it appends "launch pid=<pid> version=<v>" to the log
// file named by its Info.plist key ProbeLog; on a reopen Apple event it appends "reopen pid=<pid>".
// It keeps running until killed.
import AppKit

final class Delegate: NSObject, NSApplicationDelegate {
    let log = Bundle.main.object(forInfoDictionaryKey: "ProbeLog") as? String ?? "/tmp/probe.log"
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    func append(_ line: String) {
        let h = FileHandle(forUpdatingAtPath: log) ?? { FileManager.default.createFile(atPath: log, contents: nil); return FileHandle(forUpdatingAtPath: log)! }()
        h.seekToEndOfFile(); h.write(Data((line + "\n").utf8)); h.closeFile()
    }
    func applicationDidFinishLaunching(_ n: Notification) {
        append("launch pid=\(getpid()) version=\(version) bundle=\(Bundle.main.bundlePath)")
    }
    func applicationShouldHandleReopen(_ s: NSApplication, hasVisibleWindows: Bool) -> Bool {
        append("reopen pid=\(getpid()) version=\(version)")
        return false
    }
}

let delegate = Delegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
