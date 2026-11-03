// Probe: is FileManager.replaceItemAt(_:withItemAt:) on an app-bundle-shaped directory a single atomic
// exchange on this Mac's APFS data volume, or does the destination ever go missing mid-call?
// Claim tested: during replaceItemAt, a concurrent observer never sees the destination missing or
// half-filled (every observation finds a whole bundle: Info.plist + executable, version A or B).
// Also reports whether the destination's inode after the call is the staged directory's (a rename/swap)
// and what is left of the old copy.
// Runs in a temp folder on the same volume as /Applications (/private/var/folders...). Removes it after.
import Foundation

let fm = FileManager.default
let root = try! fm.url(for: .itemReplacementDirectory, in: .userDomainMask,
                       appropriateFor: URL(filePath: "/Applications"), create: true)
let dest = root.appending(path: "Probe.app")

func makeBundle(at url: URL, version: String) {
    try! fm.createDirectory(at: url.appending(path: "Contents/MacOS"), withIntermediateDirectories: true)
    try! fm.createDirectory(at: url.appending(path: "Contents/Resources"), withIntermediateDirectories: true)
    try! Data("<plist><dict><key>CFBundleShortVersionString</key><string>\(version)</string></dict></plist>".utf8)
        .write(to: url.appending(path: "Contents/Info.plist"))
    try! Data(repeating: 0x41, count: 4096).write(to: url.appending(path: "Contents/MacOS/Probe"))
    for i in 0..<50 { try! Data(repeating: 0x42, count: 2048).write(to: url.appending(path: "Contents/Resources/r\(i)")) }
}

func inode(_ url: URL) -> UInt64? { (try? fm.attributesOfItem(atPath: url.path)[.systemFileNumber] as? UInt64) ?? nil }

makeBundle(at: dest, version: "A")
let observations = Atomic(0), missing = Atomic(0), partial = Atomic(0)
let stop = Atomic(0)
let observer = Thread {
    while stop.load() == 0 {
        var st = stat()
        let plist = stat(dest.appending(path: "Contents/Info.plist").path, &st) == 0
        let exe = stat(dest.appending(path: "Contents/MacOS/Probe").path, &st) == 0
        observations.add()
        if !plist && !exe { missing.add() } else if plist != exe { partial.add() }
    }
}
observer.start()

var sameInode = 0, leftovers = Set<String>()
let rounds = 1500
for i in 0..<rounds {
    let stagingFolder = try! fm.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: dest, create: true)
    let staged = stagingFolder.appending(path: "Probe.app")
    makeBundle(at: staged, version: i % 2 == 0 ? "B" : "A")
    let stagedInode = inode(staged)
    _ = try! fm.replaceItemAt(dest, withItemAt: staged)
    if inode(dest) == stagedInode { sameInode += 1 }
    for name in (try? fm.contentsOfDirectory(atPath: stagingFolder.path)) ?? [] { leftovers.insert(name) }
    try? fm.removeItem(at: stagingFolder)
}
stop.store(1)
Thread.sleep(forTimeInterval: 0.2)
print("volume of temp folder:", root.path)
print("rounds:", rounds, "observations:", observations.load(), "destination missing:", missing.load(), "half-filled:", partial.load())
print("destination inode == staged inode after call:", sameInode, "of", rounds)
print("names left in the staging folder after the call:", leftovers.sorted())
try? fm.removeItem(at: root)

final class Atomic: @unchecked Sendable {
    private var value: Int; private let lock = NSLock()
    init(_ v: Int) { value = v }
    func add() { lock.lock(); value += 1; lock.unlock() }
    func load() -> Int { lock.lock(); defer { lock.unlock() }; return value }
    func store(_ v: Int) { lock.lock(); value = v; lock.unlock() }
}
