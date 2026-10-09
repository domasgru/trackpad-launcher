// FSEvents over a temp root and a not-yet-existing sibling, delivered on the main queue with 1 s latency.
// Measures callback delay after a directory is created / removed, and whether a root created later is seen.
import CoreServices
import Foundation

let base = FileManager.default.temporaryDirectory.appending(path: "tl-fsevents-\(UUID().uuidString)")
let existing = base.appending(path: "Applications")
let later = base.appending(path: "UserApplications")  // does not exist when the stream starts
try! FileManager.default.createDirectory(at: existing, withIntermediateDirectories: true)

final class Clock: @unchecked Sendable { var mark = DispatchTime.now(); var label = "" }
let clock = Clock()

let callback: FSEventStreamCallback = { _, info, count, paths, flags, _ in
    let elapsed = Double(DispatchTime.now().uptimeNanoseconds - clock.mark.uptimeNanoseconds) / 1e6
    let list = unsafeBitCast(paths, to: NSArray.self) as! [String]
    let flagList = (0..<count).map { String(flags[$0], radix: 16) }
    print(String(format: "  [%@] callback after %.0f ms, %d paths: %@ flags %@", clock.label, elapsed, count,
                 list.map { $0.replacingOccurrences(of: base.path, with: "<base>") }.joined(separator: ", "),
                 flagList.joined(separator: ",")), "main:", Thread.isMainThread)
}

var context = FSEventStreamContext()
let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagWatchRoot)
let stream = FSEventStreamCreate(
    nil, callback, &context, [existing.path, later.path] as CFArray,
    FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 1.0, flags)!
FSEventStreamSetDispatchQueue(stream, .main)
print("start:", FSEventStreamStart(stream))

func step(_ label: String, at seconds: Double, _ action: @escaping @Sendable () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
        clock.mark = DispatchTime.now()
        clock.label = label
        action()
        print("\(label) at +\(seconds)s")
    }
}

step("install Slack.app", at: 0.5) {
    try! FileManager.default.createDirectory(at: existing.appending(path: "Slack.app/Contents"), withIntermediateDirectories: true)
    try! Data("x".utf8).write(to: existing.appending(path: "Slack.app/Contents/Info.plist"))
}
step("remove Slack.app", at: 3.0) {
    try! FileManager.default.removeItem(at: existing.appending(path: "Slack.app"))
}
step("create missing root + app", at: 5.5) {
    try! FileManager.default.createDirectory(at: later.appending(path: "Zed.app/Contents"), withIntermediateDirectories: true)
}
step("app inside the late root", at: 8.0) {
    try! FileManager.default.createDirectory(at: later.appending(path: "Arc.app/Contents"), withIntermediateDirectories: true)
}
DispatchQueue.main.asyncAfter(deadline: .now() + 11) {
    FSEventStreamStop(stream)
    FSEventStreamInvalidate(stream)
    FSEventStreamRelease(stream)
    try? FileManager.default.removeItem(at: base)
    print("done")
    exit(0)
}
RunLoop.main.run()
