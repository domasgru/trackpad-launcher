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

    static func withProbes<T>(_ body: (ProbeBundles) async throws -> T) async rethrows -> T {
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

    private func cleanUp() async {
        for bundle in built {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundle.id) {
                app.terminate()
                if await !Self.terminated(app, within: .seconds(2)) {
                    app.forceTerminate()
                    _ = await Self.terminated(app, within: .seconds(5))
                }
            }
            run(
                "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
                ["-u", bundle.url.path])
        }
        try? FileManager.default.removeItem(at: directory)
    }

    /// True when `app` exits before `bound`; the exit is awaited as a KVO push, never polled.
    static func terminated(_ app: NSRunningApplication, within bound: Duration) async -> Bool {
        await value(of: app, \.isTerminated, within: bound)
    }

    /// True when `app` is finished launching before `bound`.
    static func finishedLaunching(_ app: NSRunningApplication, within bound: Duration) async -> Bool {
        await value(of: app, \.isFinishedLaunching, within: bound)
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
