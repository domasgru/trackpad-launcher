import CoreGraphics

let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for window in windows where (window[kCGWindowOwnerName as String] as? String)?.contains("Trackpad") == true {
    let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
    print(window[kCGWindowNumber as String] ?? "", window[kCGWindowName as String] ?? "", bounds)
}
