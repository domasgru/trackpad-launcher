import CoreGraphics

let list = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as! [[String: Any]]
for window in list where (window["kCGWindowOwnerName"] as? String) == "Trackpad Launcher" {
    print(window["kCGWindowNumber"]!, window["kCGWindowBounds"]!, window["kCGWindowLayer"]!)
}
