// Probe: does _LSCopyApplicationArrayInFrontToBackOrder ever list a non-regular (accessory / UIElement) app?
// Prints each entry's ApplicationType and pid, the running non-regular apps NSWorkspace knows and whether any of
// their pids is in the array, then makes this process an accessory app, activates it, and re-reads the array to see
// whether it appears. Also times the keyed information read with the keys the adapter would ask for.
import AppKit
import Foundation

typealias CopyOrder = @convention(c) (UInt32) -> Unmanaged<CFArray>?
typealias CopyInfo = @convention(c) (Int32, CFTypeRef, CFArray?) -> Unmanaged<CFDictionary>?

func symbol<T>(_ name: String, as type: T.Type) -> T? {
    dlsym(UnsafeMutableRawPointer(bitPattern: -2), name).map { unsafeBitCast($0, to: type) }
}

func time<T>(_ label: String, _ body: () -> T) -> T {
    let start = DispatchTime.now().uptimeNanoseconds
    let result = body()
    let end = DispatchTime.now().uptimeNanoseconds
    print(String(format: "%@: %.3f ms", label, Double(end - start) / 1e6))
    return result
}

let copyOrder = symbol("_LSCopyApplicationArrayInFrontToBackOrder", as: CopyOrder.self)!
let copyInfo = symbol("_LSCopyApplicationInformation", as: CopyInfo.self)!
let keys = ["pid", "ApplicationType", "LSDisplayName", "LSBundlePath", "CFBundleIdentifier"] as CFArray

func read() -> [[String: Any]] {
    let asns = copyOrder(0xFFFF_FFFE)?.takeRetainedValue() as? [CFTypeRef] ?? []
    return asns.compactMap { copyInfo(-2, $0, keys)?.takeRetainedValue() as? [String: Any] }
}

func dump(_ infos: [[String: Any]]) {
    for info in infos {
        let pid = (info["pid"] as? NSNumber)?.int32Value ?? -1
        let policy = NSRunningApplication(processIdentifier: pid)?.activationPolicy.rawValue ?? -1
        print("  type=\(info["ApplicationType"] ?? "nil") policy=\(policy) pid=\(pid) \(info["LSDisplayName"] ?? "?")  \(info["LSBundlePath"] ?? "?")")
    }
}

let before = time("keyed read with 5 keys × N") { read() }
_ = time("keyed read with 5 keys × N, again") { read() }
print("LS array (\(before.count)):")
dump(before)
let lsPIDs = Set(before.compactMap { ($0["pid"] as? NSNumber)?.int32Value })

let nonRegular = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy != .regular && $0.bundleURL != nil }
print("non-regular running apps with a bundle (\(nonRegular.count)); * marks one that is in the LS array:")
for app in nonRegular {
    let mark = lsPIDs.contains(app.processIdentifier) ? "*" : " "
    print("  \(mark) policy=\(app.activationPolicy.rawValue) \(app.localizedName ?? "?")")
}

// Now become an accessory app, activate, and look again.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled], backing: .buffered, defer: false)
window.title = "membership probe"
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0))
print("frontmost now: \(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil") (own pid \(ProcessInfo.processInfo.processIdentifier))")
let after = read()
let ownIsListed = after.contains { ($0["pid"] as? NSNumber)?.int32Value == ProcessInfo.processInfo.processIdentifier }
print("after activating as accessory: LS array has \(after.count) entries; own process listed: \(ownIsListed)")
if ownIsListed { dump(after.prefix(3).map { $0 }) }
window.orderOut(nil)
exit(0)
