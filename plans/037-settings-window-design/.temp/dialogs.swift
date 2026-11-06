// Lists every on-screen window above the normal layer, and any owned by the system's prompt helpers, to spot a prompt.
import CoreGraphics
import Foundation

let helpers = ["UserNotificationCenter", "universalAccessAuthWarn", "tccd", "SecurityAgent", "CoreServicesUIAgent"]
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for window in list {
    let owner = window[kCGWindowOwnerName as String] as? String ?? ""
    let layer = window[kCGWindowLayer as String] as? Int ?? 0
    guard helpers.contains(owner) || (layer > 3 && layer < 1000) else { continue }
    let pid = window[kCGWindowOwnerPID as String] as? Int ?? 0
    let bounds = window[kCGWindowBounds as String] as? [String: Double] ?? [:]
    print(pid, owner, "layer:\(layer)", "x:\(bounds["X"] ?? 0) y:\(bounds["Y"] ?? 0) w:\(bounds["Width"] ?? 0) h:\(bounds["Height"] ?? 0)", window[kCGWindowName as String] as? String ?? "")
}
