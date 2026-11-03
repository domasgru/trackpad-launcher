// Check (after fan-out, for R12's amended last case): an app replaces its own bundle in place, does NOT open the new
// one, and keeps running. What does it then read through Bundle.main, and does it keep running?
// v1 holds Resources/marker.txt = "v1" and Resources/only-in-v1.txt; v2 holds marker.txt = "v2" and not the other.
// The app logs: before the swap, the marker; after the swap, the marker, whether only-in-v1 is still found, its
// Info.plist version as Bundle.main reports it, and that it is still alive 3 s later.
import AppKit

final class Delegate: NSObject, NSApplicationDelegate {
    let log = Bundle.main.object(forInfoDictionaryKey: "ProbeLog") as? String ?? "/tmp/probe.log"
    func append(_ line: String) {
        let h = FileHandle(forUpdatingAtPath: log) ?? { FileManager.default.createFile(atPath: log, contents: nil); return FileHandle(forUpdatingAtPath: log)! }()
        h.seekToEndOfFile(); h.write(Data((line + "\n").utf8)); h.closeFile()
    }
    func marker() -> String {
        guard let url = Bundle.main.url(forResource: "marker", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "missing" }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    func applicationDidFinishLaunching(_ n: Notification) {
        append("before swap: marker=\(marker()) only-in-v1=\(Bundle.main.url(forResource: "only-in-v1", withExtension: "txt") != nil)")
        guard let staged = Bundle.main.object(forInfoDictionaryKey: "ProbeSelfSwapFrom") as? String else { return }
        do { _ = try FileManager.default.replaceItemAt(Bundle.main.bundleURL, withItemAt: URL(filePath: staged)) }
        catch { append("swap failed: \(error)"); return }
        append("after swap: marker=\(marker()) only-in-v1=\(Bundle.main.url(forResource: "only-in-v1", withExtension: "txt") != nil) infoVersion=\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.append("alive 3 s after the swap: pid=\(getpid()) marker=\(self.marker())")
        }
    }
}

let delegate = Delegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
