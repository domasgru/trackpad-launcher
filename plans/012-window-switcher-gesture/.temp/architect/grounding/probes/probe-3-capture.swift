// Probe 3: window previews with ScreenCaptureKit. Launches TextEdit on two temp files (TextEdit must
// not be running beforehand), enumerates SCShareableContent, captures each window scaled to fit
// 240x120 px, minimises one and tries again, then quits TextEdit and cleans up. Needs the Screen
// Recording permission for this process (CGPreflightScreenCaptureAccess is checked first; the probe
// never calls CGRequestScreenCaptureAccess and never captures when the preflight is false).
// Build: swiftc -O -parse-as-library -o probe-3-capture probe-3-capture.swift
import ApplicationServices
import AppKit
import Foundation
import ScreenCaptureKit

func ms(_ start: DispatchTime) -> String {
    String(format: "%.2f ms", Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e6)
}

func sleep(_ s: Double) { Thread.sleep(forTimeInterval: s) }

func attr(_ el: AXUIElement, _ name: String) -> AnyObject? {
    var v: AnyObject?
    return AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success ? v : nil
}

func describe(_ w: SCWindow) -> String {
    "id=\(w.windowID) title=\(w.title.map { "\"\($0)\"" } ?? "nil") onScreen=\(w.isOnScreen) active=\(w.isActive) layer=\(w.windowLayer) frame=\(w.frame.origin.x),\(w.frame.origin.y) \(w.frame.width)x\(w.frame.height) app=\(w.owningApplication?.applicationName ?? "nil")"
}

func fit(_ frame: CGRect, maxW: Int, maxH: Int) -> (Int, Int) {
    let scale = min(Double(maxW) / frame.width, Double(maxH) / frame.height)
    return (max(Int(frame.width * scale), 1), max(Int(frame.height * scale), 1))
}

@main
struct Probe {
    static func main() async throws {
        print("== Probe 3: ScreenCaptureKit previews")
        print("CGPreflightScreenCaptureAccess:", CGPreflightScreenCaptureAccess())
        guard CGPreflightScreenCaptureAccess() else { print("No Screen Recording permission; not capturing."); return }
        let previousFront = NSWorkspace.shared.frontmostApplication
        precondition(NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.TextEdit" } == nil, "TextEdit already running; aborting to leave it alone")

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("probe-3-\(getpid())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let names = ["Alpha.txt", "Beta.txt"]
        for n in names { try "Contents of \(n)\n".write(to: dir.appendingPathComponent(n), atomically: true, encoding: .utf8) }
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = ["-a", "TextEdit"] + names.map { dir.appendingPathComponent($0).path }
        try open.run(); open.waitUntilExit()
        var textEdit: NSRunningApplication?
        for _ in 0..<50 { sleep(0.2); textEdit = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.TextEdit" }; if textEdit != nil { break } }
        guard let textEdit else { print("TextEdit did not launch"); return }
        defer {
            textEdit.terminate()
            sleep(0.5)
            previousFront?.activate()
            print("Teardown: TextEdit terminated, previous front re-activated:", previousFront?.localizedName ?? "nil")
        }
        let pid = textEdit.processIdentifier
        let app = AXUIElementCreateApplication(pid)
        var axWindows: [AXUIElement] = []
        for _ in 0..<50 { sleep(0.2); axWindows = (attr(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []; if axWindows.count >= 2 { break } }
        sleep(0.5)

        // CGWindowList timings: dictionaries (cold, then warm) versus ids only
        var t = DispatchTime.now()
        _ = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        print("CGWindowListCopyWindowInfo on-screen, cold:", ms(t))
        t = DispatchTime.now()
        _ = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        print("CGWindowListCopyWindowInfo on-screen, warm:", ms(t))
        // CGWindowListCreate is a public C function that Swift marks unavailable (its CFArray holds raw ids), so call it through dlsym.
        typealias ListFn = @convention(c) (UInt32, CGWindowID) -> Unmanaged<CFArray>?
        var ids: [CGWindowID] = []
        if let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreate") {
            let fn = unsafeBitCast(sym, to: ListFn.self)
            t = DispatchTime.now()
            let option: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
            if let array = fn(option.rawValue, kCGNullWindowID)?.takeRetainedValue() {
                let count = CFArrayGetCount(array)
                ids = (0..<count).map { CGWindowID(UInt(bitPattern: CFArrayGetValueAtIndex(array, $0))) }
            }
            print("CGWindowListCreate (ids only) on-screen via dlsym:", ms(t), " count:", ids.count, " first ids:", Array(ids.prefix(12)))
        } else {
            print("CGWindowListCreate not resolvable via dlsym")
        }
        t = DispatchTime.now()
        let described = CGWindowListCreateDescriptionFromArray(ids.prefix(12).map { NSNumber(value: $0) } as CFArray) as? [[String: Any]] ?? []
        print("CGWindowListCreateDescriptionFromArray for 12 ids:", ms(t), " pids:", described.map { $0[kCGWindowOwnerPID as String] as? Int32 ?? -1 })
        t = DispatchTime.now()
        let mineDescribed = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []).filter { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }
        print("CGWindowListCopyWindowInfo third call + pid filter:", ms(t), " TextEdit windows:", mineDescribed.count)

        // Enumerate
        t = DispatchTime.now()
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        print("SCShareableContent (all windows) took", ms(t), " total windows:", content.windows.count)
        let mine = content.windows.filter { $0.owningApplication?.processID == pid }
        print("-- TextEdit windows in SCShareableContent order:")
        for w in mine { print("  ", describe(w)) }
        t = DispatchTime.now()
        let onScreenContent = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        print("SCShareableContent (on-screen only) took", ms(t), " TextEdit windows:", onScreenContent.windows.filter { $0.owningApplication?.processID == pid }.map { $0.title ?? "nil" })

        // Capture each window scaled to fit 240x120
        func capture(_ w: SCWindow) async throws -> CGImage {
            let filter = SCContentFilter(desktopIndependentWindow: w)
            let config = SCStreamConfiguration()
            let (cw, ch) = fit(w.frame, maxW: 240, maxH: 120)
            config.width = cw
            config.height = ch
            config.showsCursor = false
            config.ignoreShadowsSingleWindow = true
            config.scalesToFit = true
            config.captureResolution = .best
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        }
        for w in mine where w.windowLayer == 0 {
            t = DispatchTime.now()
            do {
                let image = try await capture(w)
                print("capture \"\(w.title ?? "nil")\" took", ms(t), " image \(image.width)x\(image.height) bpp=\(image.bitsPerPixel)")
            } catch {
                print("capture \"\(w.title ?? "nil")\" failed after", ms(t), ":", error)
            }
        }
        // Concurrent capture of both
        t = DispatchTime.now()
        try await withThrowingTaskGroup(of: (String, Int, Int).self) { group in
            for w in mine where w.windowLayer == 0 {
                group.addTask { let i = try await capture(w); return (w.title ?? "nil", i.width, i.height) }
            }
            for try await r in group { print("  concurrent capture", r) }
        }
        print("concurrent captures of \(mine.filter { $0.windowLayer == 0 }.count) windows took", ms(t))

        // Capture a window hidden behind another: raise Alpha over Beta, then capture Beta
        if let alpha = axWindows.first(where: { (attr($0, kAXTitleAttribute) as? String) == names[0] }) {
            _ = AXUIElementPerformAction(alpha, kAXRaiseAction as CFString)
            sleep(0.3)
        }
        if let beta = mine.first(where: { $0.title == names[1] }) {
            t = DispatchTime.now()
            let image = try await capture(beta)
            print("capture of occluded \"\(beta.title ?? "")\" took", ms(t), " image \(image.width)x\(image.height)")
        }

        // Minimise Beta, re-enumerate, try to capture it
        if let beta = axWindows.first(where: { (attr($0, kAXTitleAttribute) as? String) == names[1] }) {
            _ = AXUIElementSetAttributeValue(beta, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
            sleep(1.0)
            let after = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            print("-- after minimising Beta, SCShareableContent (all):")
            for w in after.windows.filter({ $0.owningApplication?.processID == pid }) { print("  ", describe(w)) }
            let afterOnScreen = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            print("on-screen only now:", afterOnScreen.windows.filter { $0.owningApplication?.processID == pid }.map { $0.title ?? "nil" })
            if let w = after.windows.first(where: { $0.owningApplication?.processID == pid && $0.title == names[1] }) {
                t = DispatchTime.now()
                do {
                    let image = try await capture(w)
                    print("capture of minimised \"\(w.title ?? "")\" took", ms(t), " image \(image.width)x\(image.height)")
                } catch {
                    print("capture of minimised failed after", ms(t), ":", error)
                }
            }
            _ = AXUIElementSetAttributeValue(beta, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            sleep(0.8)
        }

        // Does SCShareableContent order match CGWindowList order?
        let cg = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? [])
            .filter { ($0[kCGWindowOwnerPID as String] as? Int32) == pid && ($0[kCGWindowLayer as String] as? Int) == 0 }
            .map { $0[kCGWindowNumber as String] as? Int ?? -1 }
        let sc = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        print("CG on-screen order (layer 0):", cg, " SC on-screen order:", sc.windows.filter { $0.owningApplication?.processID == pid && $0.windowLayer == 0 }.map { Int($0.windowID) })
    }
}
