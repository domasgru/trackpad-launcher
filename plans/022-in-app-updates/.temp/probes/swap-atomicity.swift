// Is FileManager.replaceItemAt one atomic exchange for a bundle directory, or is there a moment with nothing at the
// destination? Compares it with renamex_np(RENAME_SWAP). An observer thread opens the destination in a tight loop and
// records every failure with its errno.
//
// Usage: swift swap-atomicity.swift [rounds]
import Foundation

let rounds = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1])! : 2000
let fm = FileManager.default
let root = fm.temporaryDirectory.appending(path: "tl-swap-probe-\(UUID().uuidString)")
let folder = root.appending(path: "Applications")
try fm.createDirectory(at: folder, withIntermediateDirectories: true)
let destination = folder.appending(path: "App.app")

func makeBundle(_ url: URL, _ tag: String) throws {
    try fm.createDirectory(at: url.appending(path: "Contents/MacOS"), withIntermediateDirectories: true)
    try Data("binary \(tag)".utf8).write(to: url.appending(path: "Contents/MacOS/fixture"))
}
try makeBundle(destination, "0")

final class Observer: @unchecked Sendable {
    let lock = NSLock()
    var stop = false
    var observations = 0
    var failures: [Int32: Int] = [:]
    let done = DispatchSemaphore(value: 0)
    func start(_ folder: URL) {
        let thread = Thread {
            let folderFD = open(folder.path, O_RDONLY | O_DIRECTORY)
            while true {
                self.lock.lock()
                if self.stop { self.lock.unlock(); break }
                self.lock.unlock()
                let fd = openat(folderFD, "App.app", O_RDONLY | O_DIRECTORY)
                let error = errno
                self.lock.lock()
                self.observations += 1
                if fd < 0 { self.failures[error, default: 0] += 1 }
                self.lock.unlock()
                if fd >= 0 { close(fd) }
            }
            close(folderFD)
            self.done.signal()
        }
        thread.start()
    }
    func finish() -> (Int, [Int32: Int]) {
        lock.lock(); stop = true; lock.unlock()
        done.wait()
        return (observations, failures)
    }
}

func run(_ name: String, _ swap: (URL) throws -> Void) throws {
    let observer = Observer()
    observer.start(folder)
    for round in 1...rounds {
        let staging = try fm.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: destination, create: true)
        let staged = staging.appending(path: "App.app")
        try makeBundle(staged, "\(round)")
        try swap(staged)
        try? fm.removeItem(at: staging)
    }
    let (observations, failures) = observer.finish()
    let described = failures.map { "\(String(cString: strerror($0.key))) (\($0.key)): \($0.value)" }.joined(separator: ", ")
    print("\(name): \(rounds) swaps, \(observations) observations, failures: \(failures.isEmpty ? "none" : described)")
}

try run("replaceItemAt") { staged in _ = try fm.replaceItemAt(destination, withItemAt: staged) }
try run("renamex_np RENAME_SWAP") { staged in
    guard renamex_np(staged.path, destination.path, UInt32(RENAME_SWAP)) == 0 else { throw POSIXError(.init(rawValue: errno)!) }
    try fm.removeItem(at: staged)  // the old copy, now at the staged path
}
try? fm.removeItem(at: root)
