// Opens the given app with the given arguments and samples the settings window's size a fixed number of times, to see
// it change. Always exits after <samples> reads.
// Run: window-heights <app> <samples> <intervalSeconds> [app arguments…]
import AppKit
import CoreGraphics

let arguments = CommandLine.arguments
let samples = Int(arguments[2])!, interval = Double(arguments[3])!
let open = Process()
open.executableURL = URL(filePath: "/usr/bin/open")
open.arguments = [arguments[1], "--args"] + arguments.dropFirst(4)
try! open.run()
let start = Date()
for _ in 0..<samples {
    Thread.sleep(forTimeInterval: interval)
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    let window = list.first {
        ($0[kCGWindowOwnerName as String] as? String) == "Trackpad Launcher"
            && ($0[kCGWindowName as String] as? String) == "Trackpad Launcher"
    }
    let bounds = window?[kCGWindowBounds as String] as? [String: Double]
    print(String(format: "t=%.2f", Date().timeIntervalSince(start)), "top:\(bounds?["Y"] ?? -1) height:\(bounds?["Height"] ?? -1)")
}
