// As fsevents-staged-probe, but the stream is re-created whenever an event carries the root-changed flag.
// Question: after re-creation, are writes inside a root created after the first stream started reported?
// Also: deleting that root again, then re-creating it.
import CoreServices
import Foundation

let base = FileManager.default.temporaryDirectory.appending(path: "tl-fsevents-recreate-\(UUID().uuidString)")
let existing = base.appending(path: "Applications")
let later = base.appending(path: "UserApplications")
let fm = FileManager.default
try! fm.createDirectory(at: existing, withIntermediateDirectories: true)

final class State: @unchecked Sendable {
    var mark = DispatchTime.now()
    var label = ""
    var stream: FSEventStreamRef?
    var recreations = 0
}
let state = State()

func start() {
    var context = FSEventStreamContext()
    let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagWatchRoot)
    let stream = FSEventStreamCreate(
        nil, callback, &context, [existing.path, later.path] as CFArray,
        FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 1.0, flags)!
    FSEventStreamSetDispatchQueue(stream, .main)
    _ = FSEventStreamStart(stream)
    state.stream = stream
}

func stop() {
    guard let stream = state.stream else { return }
    FSEventStreamStop(stream)
    FSEventStreamInvalidate(stream)
    FSEventStreamRelease(stream)
    state.stream = nil
}

let callback: FSEventStreamCallback = { _, _, count, paths, flags, _ in
    let elapsed = Double(DispatchTime.now().uptimeNanoseconds - state.mark.uptimeNanoseconds) / 1e6
    let list = unsafeBitCast(paths, to: NSArray.self) as! [String]
    var rootChanged = false
    let rendered = (0..<count).map { i -> String in
        if flags[i] & FSEventStreamEventFlags(kFSEventStreamEventFlagRootChanged) != 0 { rootChanged = true }
        return list[i].replacingOccurrences(of: base.path, with: "<base>") + " [0x" + String(flags[i], radix: 16) + "]"
    }
    print(String(format: "  [%@] +%.0f ms: ", state.label, elapsed) + rendered.joined(separator: ", "))
    if rootChanged {
        DispatchQueue.main.async {
            stop()
            start()
            state.recreations += 1
            print("  (stream re-created, \(state.recreations))")
        }
    }
}

start()
let steps: [(String, Double, () -> Void)] = [
    ("1 late root + Arc.app/Contents", 0.5, {
        try! fm.createDirectory(at: later.appending(path: "Arc.app/Contents/Resources"), withIntermediateDirectories: true)
    }),
    ("2 Arc Info.plist in late root", 3.5, {
        try! Data("a".utf8).write(to: later.appending(path: "Arc.app/Contents/Info.plist"))
    }),
    ("3 deep write in Arc Resources", 6.5, {
        try! Data("x".utf8).write(to: later.appending(path: "Arc.app/Contents/Resources/cache.bin"))
    }),
    ("4 delete late root", 9.5, { try! fm.removeItem(at: later) }),
    ("5 re-create late root + Zed.app", 12.5, {
        try! fm.createDirectory(at: later.appending(path: "Zed.app/Contents"), withIntermediateDirectories: true)
    }),
    ("6 Zed Info.plist", 15.5, {
        try! Data("z".utf8).write(to: later.appending(path: "Zed.app/Contents/Info.plist"))
    }),
]
for (label, seconds, action) in steps {
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
        state.mark = DispatchTime.now()
        state.label = label
        action()
        print("\(label) at +\(seconds)s")
    }
}
DispatchQueue.main.asyncAfter(deadline: .now() + 18.5) {
    stop()
    try? fm.removeItem(at: base)
    print("done")
    exit(0)
}
RunLoop.main.run()
