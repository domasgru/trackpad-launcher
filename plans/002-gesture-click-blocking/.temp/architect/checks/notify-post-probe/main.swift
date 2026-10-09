// Probe: may an ordinary, untrusted process post the Darwin notification "com.apple.tcc.access.changed"
// (the one tccd posts after a TCC change), and does its own registration receive it? Decides whether a
// platform test can drive the permission adapter's push path with notify_post, without touching TCC.
//
// Build and run:
//   swiftc -O -o /tmp/notify-post-probe main.swift && /tmp/notify-post-probe

import Foundation
import notify

final class Box: @unchecked Sendable {
    var hits: [String] = []
}

let box = Box()
let started = Date()
let name = "com.apple.tcc.access.changed"
var token: Int32 = 0
let registered = notify_register_dispatch(name, &token, DispatchQueue.main) { _ in
    box.hits.append("t+\(String(format: "%.3f", Date().timeIntervalSince(started)))s thread=\(Thread.isMainThread ? "main" : "other")")
}
print("notify_register_dispatch status \(registered)")
RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
print("baseline hits: \(box.hits.count)")
let posted = notify_post(name)
print("notify_post status \(posted) (0 = NOTIFY_STATUS_OK, 12 = NOTIFY_STATUS_NOT_AUTHORIZED)")
RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0))
print("hits after post: \(box.hits.count)")
box.hits.forEach { print("  \($0)") }
notify_cancel(token)
