// Probe P0: what this machine and this process context offer.
// Prints displays, permission preflights, Reduce motion, and which candidate test apps are running.
import AppKit
import ApplicationServices

print("macOS:", ProcessInfo.processInfo.operatingSystemVersionString)
for (i, s) in NSScreen.screens.enumerated() {
    print("screen \(i): frame=\(s.frame) visible=\(s.visibleFrame) scale=\(s.backingScaleFactor)")
}
print("screensHaveSeparateSpaces:", NSScreen.screensHaveSeparateSpaces)
print("AXIsProcessTrusted:", AXIsProcessTrusted())
print("CGPreflightPostEventAccess:", CGPreflightPostEventAccess())
print("CGPreflightListenEventAccess:", CGPreflightListenEventAccess())
print("reduceMotion:", NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
let candidates = ["com.apple.calculator", "com.apple.Chess", "com.apple.TextEdit", "com.apple.Stickies", "com.apple.DigitalColorMeter", "com.apple.grapher", "com.apple.ScreenSharing", "com.apple.FontBook"]
for id in candidates {
    let running = NSRunningApplication.runningApplications(withBundleIdentifier: id)
    let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
    print("\(id): running=\(running.count) url=\(url?.path ?? "nil")")
}
print("pointer:", NSEvent.mouseLocation)
