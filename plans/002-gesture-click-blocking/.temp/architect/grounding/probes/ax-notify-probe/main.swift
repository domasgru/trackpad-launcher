// Probe: which push signal, if any, fires when the Accessibility (TCC) list changes, and on which thread?
//   (a) DistributedNotificationCenter "com.apple.accessibility.api" (string present in the dyld shared cache)
//   (b) Darwin notify(3) "com.apple.tcc.access.changed" (string present in tccd, next to "Failed to post ... notification")
//
// Trigger: after 2 s of listening the probe itself runs
//   /usr/bin/tccutil reset Accessibility <bundle id given as argv[1]>
// The caller passes the bundle ID of a throwaway app it registered with LaunchServices and that has no TCC
// row, so the database is left as found. (tccutil rejects bundle IDs LaunchServices does not know.)
//
// Build and run:
//   swiftc -O -o /tmp/ax-notify-probe main.swift && /tmp/ax-notify-probe com.example.tl-probe-nonexistent

import Foundation
import notify

final class Box: @unchecked Sendable {
    var hits: [String] = []
}

let box = Box()
let started = Date()
func stamp() -> String { "t+\(String(format: "%.2f", Date().timeIntervalSince(started)))s" }

let distributed = Notification.Name("com.apple.accessibility.api")
let token = DistributedNotificationCenter.default().addObserver(forName: distributed, object: nil, queue: nil) { note in
    box.hits.append(
        "\(stamp()) distributed \(distributed.rawValue) thread=\(Thread.isMainThread ? "main" : "other") "
            + "object=\(String(describing: note.object)) userInfo=\(String(describing: note.userInfo))")
}

var darwinToken: Int32 = 0
let darwinName = "com.apple.tcc.access.changed"
let darwinStatus = notify_register_dispatch(darwinName, &darwinToken, DispatchQueue.main) { _ in
    box.hits.append("\(stamp()) darwin \(darwinName) thread=\(Thread.isMainThread ? "main" : "other")")
}
print("notify_register_dispatch(\(darwinName)) status \(darwinStatus) (0 = NOTIFY_STATUS_OK)")

let bundleID = CommandLine.arguments.dropFirst().first ?? "com.example.tl-probe-nonexistent"
print("listening; baseline 2 s, then tccutil reset Accessibility \(bundleID), then 6 s more")
RunLoop.main.run(until: Date(timeIntervalSinceNow: 2))
print("baseline hits in 2 s: \(box.hits.count)")

let tccutil = Process()
tccutil.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
tccutil.arguments = ["reset", "Accessibility", bundleID]
let pipe = Pipe()
tccutil.standardOutput = pipe
tccutil.standardError = pipe
let triggered = stamp()
try tccutil.run()
tccutil.waitUntilExit()
let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
print("tccutil ran at \(triggered), exit \(tccutil.terminationStatus): \(output.trimmingCharacters(in: .whitespacesAndNewlines))")

RunLoop.main.run(until: Date(timeIntervalSinceNow: 6))
DistributedNotificationCenter.default().removeObserver(token)
notify_cancel(darwinToken)
print("total hits: \(box.hits.count)")
box.hits.forEach { print("  \($0)") }
