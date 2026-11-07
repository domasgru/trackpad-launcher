// Watches the screen and the disk every 100 ms for Scripts/update-e2e.sh, and writes one JSON line per sample:
//   t          epoch milliseconds
//   front      the frontmost app: {id, name, pid}
//   app        the app under test: {pids, policy}, policy being accessory (LSUIElement), regular, prohibited or none
//   windows    every on-screen window of every process: [owner, pid, number, layer]
//   installed  per --app path: {version: CFBundleVersion or null, exec: whether the executable is there}
//
//   sampler <output file> [--app <bundle path>]... [--duration <seconds>]
// The app's bundle identifier comes from the SAMPLER_BUNDLE_ID environment variable, so no process's arguments name it.
// It runs until it is terminated or the duration passes.
import AppKit
import CoreGraphics
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
guard let outputPath = arguments.first, let bundleID = ProcessInfo.processInfo.environment["SAMPLER_BUNDLE_ID"] else {
    FileHandle.standardError.write(Data("usage: SAMPLER_BUNDLE_ID=<id> sampler <output> [--app <path>]... [--duration <s>]\n".utf8))
    exit(2)
}
var apps: [String] = []
var duration: Double?
var index = 1
while index < arguments.count {
    switch arguments[index] {
    case "--app": apps.append(arguments[index + 1])
    case "--duration": duration = Double(arguments[index + 1])
    default: break
    }
    index += 2
}

FileManager.default.createFile(atPath: outputPath, contents: nil)
guard let output = FileHandle(forWritingAtPath: outputPath) else { exit(2) }
output.seekToEndOfFile()

func policyName(_ policy: NSApplication.ActivationPolicy) -> String {
    switch policy {
    case .regular: "regular"
    case .accessory: "accessory"
    case .prohibited: "prohibited"
    @unknown default: "unknown"
    }
}

func installed(_ path: String) -> [String: Any] {
    let info = NSDictionary(contentsOfFile: "\(path)/Contents/Info.plist")
    let version = info?["CFBundleVersion"] as? String
    let executable = (info?["CFBundleExecutable"] as? String).map {
        FileManager.default.fileExists(atPath: "\(path)/Contents/MacOS/\($0)")
    } ?? false
    return ["version": version ?? NSNull(), "exec": executable]
}

func sample() -> [String: Any] {
    let front = NSWorkspace.shared.frontmostApplication
    let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []).map {
        [
            $0[kCGWindowOwnerName as String] ?? "", $0[kCGWindowOwnerPID as String] ?? 0,
            $0[kCGWindowNumber as String] ?? 0, $0[kCGWindowLayer as String] ?? 0,
        ] as [Any]
    }
    return [
        "t": Int(Date().timeIntervalSince1970 * 1000),
        "front": [
            "id": front?.bundleIdentifier ?? "", "name": front?.localizedName ?? "",
            "pid": Int(front?.processIdentifier ?? 0),
        ],
        "app": [
            "pids": running.map { Int($0.processIdentifier) },
            "policy": running.first.map { policyName($0.activationPolicy) } ?? "none",
        ],
        "windows": windows,
        "installed": Dictionary(uniqueKeysWithValues: apps.map { ($0, installed($0)) }),
    ]
}

let started = Date()
while duration.map({ Date().timeIntervalSince(started) < $0 }) ?? true {
    let tick = Date()
    if let data = try? JSONSerialization.data(withJSONObject: sample(), options: [.sortedKeys, .withoutEscapingSlashes]) {
        output.write(data + Data("\n".utf8))
    }
    // The run loop must turn for NSWorkspace to learn which app is frontmost.
    RunLoop.current.run(until: tick.addingTimeInterval(0.1))
    let rest = 0.1 - Date().timeIntervalSince(tick)
    if rest > 0 { Thread.sleep(forTimeInterval: rest) }
}
