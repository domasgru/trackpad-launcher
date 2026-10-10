// FSEvents over a canonical temp root and a not-yet-existing sibling, main queue, 1 s latency, watch-root, CF paths.
// Staged installs: bundle folder first, Info.plist later; a write deep inside an existing bundle; the same inside a
// root created after the stream started. Prints each callback's paths (relative to base) and flags, so the plan can
// decide (a) whether a path filter at "X.app/Contents/" keeps every install visible, (b) whether a late root needs
// the stream re-created.
import CoreServices
import Foundation

let base = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
    .appending(path: "tl-fsevents-staged-\(UUID().uuidString)")
let existing = base.appending(path: "Applications")
let later = base.appending(path: "UserApplications")
let fm = FileManager.default
try! fm.createDirectory(at: existing.appending(path: "Zed.app/Contents/Resources"), withIntermediateDirectories: true)
try! Data("z".utf8).write(to: existing.appending(path: "Zed.app/Contents/Info.plist"))

final class Clock: @unchecked Sendable { var mark = DispatchTime.now(); var label = "" }
let clock = Clock()

let callback: FSEventStreamCallback = { _, _, count, paths, flags, _ in
    let elapsed = Double(DispatchTime.now().uptimeNanoseconds - clock.mark.uptimeNanoseconds) / 1e6
    let list = unsafeBitCast(paths, to: NSArray.self) as! [String]
    let rendered = (0..<count).map { i in
        list[i].replacingOccurrences(of: base.path, with: "<base>") + " [0x" + String(flags[i], radix: 16) + "]"
    }
    print(String(format: "  [%@] +%.0f ms: ", clock.label, elapsed) + rendered.joined(separator: ", "))
}

var context = FSEventStreamContext()
let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagWatchRoot)
let stream = FSEventStreamCreate(
    nil, callback, &context, [existing.path, later.path] as CFArray,
    FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 1.0, flags)!
FSEventStreamSetDispatchQueue(stream, .main)
print("start:", FSEventStreamStart(stream))

var schedule: [(String, Double, () -> Void)] = [
    ("1 Slack.app/Contents folder only", 0.5, {
        try! fm.createDirectory(at: existing.appending(path: "Slack.app/Contents/MacOS"), withIntermediateDirectories: true)
    }),
    ("2 Slack Info.plist", 3.5, {
        try! Data("s".utf8).write(to: existing.appending(path: "Slack.app/Contents/Info.plist"))
    }),
    ("3 deep write in Zed Resources", 6.5, {
        try! Data("x".utf8).write(to: existing.appending(path: "Zed.app/Contents/Resources/cache.bin"))
    }),
    ("4 late root + Arc.app/Contents", 9.5, {
        try! fm.createDirectory(at: later.appending(path: "Arc.app/Contents/Resources"), withIntermediateDirectories: true)
    }),
    ("5 Arc Info.plist in late root", 12.5, {
        try! Data("a".utf8).write(to: later.appending(path: "Arc.app/Contents/Info.plist"))
    }),
    ("6 deep write in Arc Resources", 15.5, {
        try! Data("x".utf8).write(to: later.appending(path: "Arc.app/Contents/Resources/cache.bin"))
    }),
    ("7 remove Slack.app", 18.5, { try! fm.removeItem(at: existing.appending(path: "Slack.app")) }),
]
for (label, seconds, action) in schedule {
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
        clock.mark = DispatchTime.now()
        clock.label = label
        action()
        print("\(label) at +\(seconds)s")
    }
}
schedule = []
DispatchQueue.main.asyncAfter(deadline: .now() + 21.5) {
    FSEventStreamStop(stream)
    FSEventStreamInvalidate(stream)
    FSEventStreamRelease(stream)
    try? fm.removeItem(at: base)
    print("done")
    exit(0)
}
RunLoop.main.run()
