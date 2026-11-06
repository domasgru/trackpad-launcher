// Lists the on-screen and off-screen windows of processes named "Trackpad Launcher": id, bounds, title, layer.
// Run: swift windows.swift
import CoreGraphics
import Foundation

let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
for window in list where (window[kCGWindowOwnerName as String] as? String) == "Trackpad Launcher" {
    let id = window[kCGWindowNumber as String] as? Int ?? 0
    let bounds = window[kCGWindowBounds as String] as? [String: Double] ?? [:]
    let title = window[kCGWindowName as String] as? String ?? ""
    let onScreen = window[kCGWindowIsOnscreen as String] as? Bool ?? false
    let layer = window[kCGWindowLayer as String] as? Int ?? 0
    print(id, "x:\(bounds["X"] ?? 0) y:\(bounds["Y"] ?? 0) w:\(bounds["Width"] ?? 0) h:\(bounds["Height"] ?? 0)", "layer:\(layer)", "on:\(onScreen)", "'\(title)'")
}
