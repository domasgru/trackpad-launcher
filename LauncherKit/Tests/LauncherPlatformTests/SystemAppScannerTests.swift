import Foundation
import LauncherCore
import Synchronization
import Testing

@testable import LauncherPlatform

/// The real scanner over a temp tree: real FSEvents and real off-main scans. Each push is awaited with a bound,
/// never polled.
@MainActor @Suite struct SystemAppScannerTests {
    /// Blocks readers until opened; stays open afterwards.
    final class Gate: Sendable {
        private let semaphore = DispatchSemaphore(value: 0)
        func open() { semaphore.signal() }
        func wait() {
            semaphore.wait()
            semaphore.signal()
        }
    }

    final class Tree {
        let root = FileManager.default.temporaryDirectory.appending(path: "tl-scanner-\(UUID().uuidString)")
        var applications: URL { root.appending(path: "Applications") }
        var userApplications: URL { root.appending(path: "UserApplications") }

        init() {
            try! FileManager.default.createDirectory(at: applications, withIntermediateDirectories: true)
        }

        deinit { try? FileManager.default.removeItem(at: root) }

        func catalog(lastOpened: @escaping @Sendable (URL) -> Date? = { _ in nil }) -> AppCatalog {
            AppCatalog(
                roots: [applications, userApplications], extras: [], registeredCopies: { _ in [] },
                lastOpened: lastOpened)
        }

        func makeContents(_ name: String, in directory: URL) {
            try! FileManager.default.createDirectory(
                at: directory.appending(path: "\(name).app/Contents/Resources"), withIntermediateDirectories: true)
        }

        func writeInfo(_ name: String, in directory: URL) {
            let plist = ["CFBundleIdentifier": "com.test.\(name.lowercased())"]
            try! PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                .write(to: directory.appending(path: "\(name).app/Contents/Info.plist"))
        }

        func install(_ name: String, in directory: URL) {
            makeContents(name, in: directory)
            writeInfo(name, in: directory)
        }
    }

    /// Scans as they arrive, as the listed app names.
    @MainActor final class Feed {
        private var buffered: [[String]] = []
        private var waiter: (id: Int, continuation: CheckedContinuation<[String]?, Never>)?
        private var waiterCount = 0

        init(_ scanner: SystemAppScanner) {
            scanner.onScan = { [unowned self] in receive(($0.recent + $0.others).map(\.name)) }
        }

        private func receive(_ names: [String]) {
            if let waiter {
                self.waiter = nil
                waiter.continuation.resume(returning: names)
            } else {
                buffered.append(names)
            }
        }

        private func pop(until deadline: ContinuousClock.Instant) async -> [String]? {
            if !buffered.isEmpty { return buffered.removeFirst() }
            waiterCount += 1
            let id = waiterCount
            return await withCheckedContinuation { continuation in
                waiter = (id, continuation)
                Task { [self] in
                    try? await Task.sleep(until: deadline)
                    guard let current = waiter, current.id == id else { return }
                    waiter = nil
                    current.continuation.resume(returning: nil)
                }
            }
        }

        /// The first scan from now on that satisfies `predicate`, or nil after `seconds`.
        func next(within seconds: Double = 5, where predicate: ([String]) -> Bool = { _ in true }) async -> [String]? {
            let deadline = ContinuousClock.now + .seconds(seconds)
            while let names = await pop(until: deadline) {
                if predicate(names) { return names }
            }
            return nil
        }
    }

    @Test func scansOnRequestAndAfterEveryInstallAndRemovalWithoutARequest() async {
        let tree = Tree()
        tree.install("Zed", in: tree.applications)
        let scanner = SystemAppScanner(catalog: tree.catalog())
        let feed = Feed(scanner)

        scanner.scan()
        #expect(await feed.next() == ["Zed"], "a scan arrives within 5 s of the request")

        tree.makeContents("Slack", in: tree.applications)
        #expect(await feed.next() != nil, "the new bundle folder causes a scan")
        tree.writeInfo("Slack", in: tree.applications)
        #expect(await feed.next(where: { $0.contains("Slack") }) != nil, "an install is listed within 5 s")

        try! FileManager.default.removeItem(at: tree.applications.appending(path: "Slack.app"))
        #expect(await feed.next(where: { !$0.contains("Slack") }) != nil, "a removal is gone within 5 s")

        tree.makeContents("Arc", in: tree.userApplications)
        #expect(await feed.next() != nil, "a root created later causes a scan")
        tree.writeInfo("Arc", in: tree.userApplications)
        #expect(await feed.next(where: { $0.contains("Arc") }) != nil, "an install in the new root is listed within 5 s")
    }

    @Test func aChangeMadeDuringAScanIsScannedOnceTheHeldScanFinishes() async {
        let tree = Tree()
        tree.install("Zed", in: tree.applications)
        let gate = Gate()
        let scanner = SystemAppScanner(catalog: tree.catalog(lastOpened: { _ in gate.wait(); return nil }))
        let feed = Feed(scanner)

        scanner.scan()
        tree.install("Slack", in: tree.applications)
        try? await Task.sleep(for: .seconds(2))
        gate.open()

        #expect(await feed.next() != nil, "the held scan delivers")
        #expect(await feed.next(where: { $0.contains("Slack") }) != nil, "a scan listing Slack follows within 5 s")
    }

    @Test func writesInsideAnInstalledBundleCauseNoScan() async {
        let tree = Tree()
        tree.install("Zed", in: tree.applications)
        // FSEvents still reports writes made just before a stream starts; let the setup's own writes pass first.
        try? await Task.sleep(for: .seconds(2))
        let scanner = SystemAppScanner(catalog: tree.catalog())
        let feed = Feed(scanner)
        scanner.scan()
        #expect(await feed.next() != nil)

        try! Data("x".utf8).write(to: tree.applications.appending(path: "Zed.app/Contents/Resources/cache.bin"))
        #expect(await feed.next(within: 3) == nil, "no scan within 3 s of a write deep inside a bundle")

        tree.install("Slack", in: tree.applications)
        #expect(await feed.next(where: { $0.contains("Slack") }) != nil, "the stream is still alive")
    }

    @Test func eventPathsCountOnlyUpToTheContentsFolder() {
        let none = FSEventStreamEventFlags(kFSEventStreamEventFlagNone)
        func counts(_ path: String) -> Bool { SystemAppScanner.isInstallChange(path: path, flags: none) }

        #expect(counts("/Applications"))
        #expect(counts("/Applications/Slack.app"))
        #expect(counts("/Applications/Slack.app/Contents"))
        #expect(counts("/Applications/Utilities/Terminal.app/Contents"))
        #expect(!counts("/Applications/Slack.app/Contents/Resources"))
        #expect(!counts("/Applications/Slack.app/Contents/Helpers/Helper.app/Contents"))
        #expect(SystemAppScanner.isInstallChange(
            path: "/Applications/Slack.app/Contents/Resources",
            flags: FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs)))
    }
}
