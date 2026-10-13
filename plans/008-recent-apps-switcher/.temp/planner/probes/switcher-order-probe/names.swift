// Probe: where the Finder display name of a running app can be read cheaply. `FileManager.displayName(atPath:)`
// costs about 5 ms per app; this compares it with the URL resource value, the LaunchServices dictionary's own
// name keys, and NSRunningApplication's name, for every regular running app, and shows where they disagree.
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
let asns = copyOrder(0xFFFF_FFFE)?.takeRetainedValue() as? [CFTypeRef] ?? []
let keys = ["pid", "LSDisplayName", "CFBundleDisplayName", "CFBundleName", "CFBundleIdentifier", "LSBundlePath"] as CFArray
let infos = time("LS info with 6 keys × \(asns.count)") {
    asns.compactMap { copyInfo(-2, $0, keys)?.takeRetainedValue() as? [String: Any] }
}
_ = time("LS info with 6 keys × \(asns.count), again") {
    asns.compactMap { copyInfo(-2, $0, keys)?.takeRetainedValue() as? [String: Any] }
}
let apps = time("NSRunningApplication(pid:) + bundleURL × \(infos.count)") {
    infos.compactMap { ($0["pid"] as? NSNumber).flatMap { NSRunningApplication(processIdentifier: $0.int32Value) } }
        .map { ($0, $0.bundleURL) }
}
let urls = apps.compactMap(\.1)
let viaDisplayName = time("displayName(atPath:) × \(urls.count)") { urls.map { FileManager.default.displayName(atPath: $0.path) } }
let viaResource = time("resourceValues(.localizedNameKey) × \(urls.count)") {
    urls.map { (try? $0.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? "nil" }
}
_ = time("resourceValues(.localizedNameKey) × \(urls.count), again") {
    urls.map { (try? $0.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? "nil" }
}
let viaNameKey = time("resourceValues(.nameKey) × \(urls.count)") {
    urls.map { (try? $0.resourceValues(forKeys: [.nameKey]).name) ?? "nil" }
}
_ = time("displayName(atPath:) on /usr/bin × 14") { (0..<14).map { _ in FileManager.default.displayName(atPath: "/usr/bin") } }
print("")
print(String(format: "%-22@ %-22@ %-22@ %-22@ %-22@ %-22@", "displayName", "localizedNameKey", "nameKey", "LSDisplayName", "CFBundleDisplayName", "localizedName"))
for (index, info) in infos.enumerated() where index < urls.count {
    let ls = info["LSDisplayName"] as? String ?? "nil"
    let display = info["CFBundleDisplayName"] as? String ?? "nil"
    let running = apps[index].0.localizedName ?? "nil"
    let path = info["LSBundlePath"] as? String ?? "nil"
    print(String(format: "%-22@ %-22@ %-22@ %-22@ %-22@ %-22@  %@", viaDisplayName[index], viaResource[index], viaNameKey[index], ls, display, running, path == urls[index].path ? "path=same" : "path=\(path)"))
}
