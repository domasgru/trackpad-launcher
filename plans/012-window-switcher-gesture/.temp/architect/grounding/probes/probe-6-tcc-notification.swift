// Probe 6: does tccd post the Darwin notification com.apple.tcc.access.changed (the one the existing
// Accessibility adapter listens to) when the Screen Capture service changes? We cannot grant or revoke
// a real permission here, so the probe listens, then runs `tccutil reset ScreenCapture <bundle id that
// does not exist>`, which changes nothing on the machine, and reports whether a notification arrived.
// A notification proves the service posts; silence is inconclusive (a no-op reset may not post).
// Build: swiftc -O -parse-as-library -o probe-6-tcc-notification probe-6-tcc-notification.swift
import Foundation
import notify

@main
struct Probe {
    static func main() throws {
        print("== Probe 6: com.apple.tcc.access.changed on a ScreenCapture reset")
        let fired = NSLock()
        nonisolated(unsafe) var count = 0
        var token: Int32 = 0
        let status = notify_register_dispatch("com.apple.tcc.access.changed", &token, DispatchQueue.global()) { _ in
            fired.lock(); count += 1; fired.unlock()
            print("  notification received at", Date())
        }
        print("notify_register_dispatch status:", status)
        Thread.sleep(forTimeInterval: 1.0)
        fired.lock(); let before = count; fired.unlock()
        print("notifications before reset:", before)
        let reset = Process()
        reset.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        // Trackpad Launcher's own bundle id: the app has never asked for Screen Capture, so the reset removes nothing.
        // (A first run with a made-up bundle id was rejected by tccutil before reaching tccd and fired nothing.)
        reset.arguments = ["reset", "ScreenCapture", "com.domasgru.TrackpadLauncherApp"]
        let pipe = Pipe()
        reset.standardOutput = pipe
        reset.standardError = pipe
        try reset.run()
        reset.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        print("tccutil exit:", reset.terminationStatus, "output:", output.trimmingCharacters(in: .whitespacesAndNewlines))
        Thread.sleep(forTimeInterval: 2.0)
        fired.lock(); let after = count; fired.unlock()
        print("notifications after reset:", after, " fired for the reset:", after > before)
        notify_cancel(token)
    }
}
