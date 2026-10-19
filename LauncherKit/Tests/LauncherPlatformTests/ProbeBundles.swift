import AppKit
import Foundation

/// Throwaway `.app` bundles of the `LaunchProbe` executable, one per startup script, each with a fresh bundle ID in a
/// fresh temp directory. `withProbes` removes everything they leave behind when the body ends, even if an expectation
/// failed: running instances are quit, the bundles are unregistered from LaunchServices and the directory is deleted.
@MainActor final class ProbeBundles {
    struct Bundle {
        let url: URL
        let id: String
    }

    /// The `ProbeScript` Info.plist dictionary; see the probe's own header for the keys.
    typealias Script = [String: Any]

    @discardableResult
    static func withProbes<T>(_ body: @MainActor (ProbeBundles) async throws -> T) async rethrows -> T {
        let probes = ProbeBundles()
        do {
            let result = try await body(probes)
            await probes.cleanUp()
            return result
        } catch {
            await probes.cleanUp()
            throw error
        }
    }

    let directory = FileManager.default.temporaryDirectory.appending(path: "tl-probes-\(UUID().uuidString)")
    private var built: [Bundle] = []

    private init() {
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private final class Anchor {}

    /// The probe binary SwiftPM builds beside the test bundle.
    private static var probeExecutable: URL {
        Foundation.Bundle(for: Anchor.self).bundleURL.deletingLastPathComponent().appending(path: "LaunchProbe")
    }

    /// A bundle running `script`; a menu bar app (no Dock icon, no menu bar) when `menuBarApp`.
    func make(_ script: Script = [:], menuBarApp: Bool = false) -> Bundle {
        let bundle = skeleton(menuBarApp: menuBarApp, script: script, executable: "Probe")
        let executable = bundle.url.appending(path: "Contents/MacOS/Probe")
        try! FileManager.default.copyItem(at: Self.probeExecutable, to: executable)
        run("/usr/bin/codesign", ["-s", "-", "--force", bundle.url.path])
        return bundle
    }

    /// A bundle whose Info.plist names an executable that is not there, so macOS refuses to open it.
    func makeWithoutExecutable() -> Bundle {
        skeleton(menuBarApp: false, script: [:], executable: "Missing")
    }

    private func skeleton(menuBarApp: Bool, script: Script, executable: String) -> Bundle {
        let id = "com.trackpadlauncher.test.probe.\(UUID().uuidString)"
        let url = directory.appending(path: "\(id).app")
        let macOS = url.appending(path: "Contents/MacOS")
        try! FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        var info: [String: Any] = [
            "CFBundleIdentifier": id,
            "CFBundleName": "Probe",
            "CFBundleExecutable": executable,
            "CFBundlePackageType": "APPL",
            "ProbeScript": script,
        ]
        if menuBarApp { info["LSUIElement"] = true }
        try! PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: url.appending(path: "Contents/Info.plist"))
        let bundle = Bundle(url: url, id: id)
        built.append(bundle)
        return bundle
    }

    /// Leaves no probe process, listed or not. The bundles go first, so a launch still on its way to being spawned has
    /// nothing to spawn; then every process running from the probe directory is killed, whether or not macOS lists it
    /// yet (one still starting up, or blocked in will-finish, is not), and its exit is awaited.
    private func cleanUp() async {
        for bundle in built {
            run(
                "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
                ["-u", bundle.url.path])
        }
        try? FileManager.default.removeItem(at: directory)
        let listed = built.flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0.id) }
        for _ in 0..<3 {
            let pids = probeProcesses()
            if pids.isEmpty { break }
            for pid in pids { kill(pid, SIGKILL) }
            for pid in pids { await Self.exited(pid, within: .seconds(5)) }
        }
        for app in listed { _ = await Self.terminated(app, within: .seconds(5)) }
    }

    /// The pids of processes whose command line is inside the probe directory.
    private func probeProcesses() -> [pid_t] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", directory.path]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return [] }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self).split(separator: "\n").compactMap { pid_t($0) }
    }

    /// Returns once `pid` is gone or `bound` passes; the exit is a dispatch-source push.
    nonisolated private static func exited(_ pid: pid_t, within bound: Duration) async {
        let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .global())
        let gone = AsyncStream<Void>.makeStream()
        source.setEventHandler { gone.continuation.yield() }
        source.resume()
        if kill(pid, 0) != 0 { gone.continuation.yield() }
        let timeout = Task {
            try await Task.sleep(for: bound)
            gone.continuation.yield()
        }
        var iterator = gone.stream.makeAsyncIterator()
        _ = await iterator.next()
        timeout.cancel()
        source.cancel()
    }

    /// True when `app` exits before `bound`; the exit is awaited as a KVO push, never polled.
    static func terminated(_ app: NSRunningApplication, within bound: Duration) async -> Bool {
        await value(of: app, \.isTerminated, within: bound)
    }

    /// True when `app` is finished launching before `bound`.
    static func finishedLaunching(_ app: NSRunningApplication, within bound: Duration) async -> Bool {
        await value(of: app, \.isFinishedLaunching, within: bound)
    }

    /// The running process of the bundle once macOS lists it. The workspace's list pushes (key-value observation, off
    /// the main thread) and its launch notification wake the lookup, which is made on the main actor: a lookup made
    /// inside the push can miss a process the push announces.
    static func listed(_ bundle: Bundle, within bound: Duration) async -> NSRunningApplication? {
        let id = bundle.id
        let wakes = AsyncStream<Void>.makeStream()
        let observation = NSWorkspace.shared.observe(\.runningApplications, options: [.new]) { _, _ in
            wakes.continuation.yield()
        }
        let launched = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: nil
        ) { _ in wakes.continuation.yield() }
        let timeout = Task {
            try await Task.sleep(for: bound)
            wakes.continuation.finish()
        }
        defer {
            timeout.cancel()
            observation.invalidate()
            NSWorkspace.shared.notificationCenter.removeObserver(launched)
        }
        if let app = process(of: bundle) { return app }
        for await _ in wakes.stream {
            if let app = process(of: bundle) { return app }
        }
        return nil
    }

    /// The bundle's process now, if macOS lists one.
    static func process(of bundle: Bundle) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundle.id).first { !$0.isTerminated }
    }

    private static func value(
        of app: NSRunningApplication, _ keyPath: KeyPath<NSRunningApplication, Bool>, within bound: Duration
    ) async -> Bool {
        let outcome = AsyncStream<Bool>.makeStream()
        let observation = app.observe(keyPath, options: [.initial, .new]) { _, change in
            if change.newValue == true { outcome.continuation.yield(true) }
        }
        let timeout = Task {
            try await Task.sleep(for: bound)
            outcome.continuation.yield(false)
        }
        var iterator = outcome.stream.makeAsyncIterator()
        let reached = await iterator.next() ?? false
        timeout.cancel()
        observation.invalidate()
        return reached
    }

    private func run(_ tool: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}
