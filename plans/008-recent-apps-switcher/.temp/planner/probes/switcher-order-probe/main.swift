// Probe: the ⌘-Tab order through the private LaunchServices call, resolved with dlsym from the LaunchServices
// already loaded by AppKit (no link flag); what each half of it costs; what parsing one Info.plist per running app
// costs the way AppCatalog.entry(at:) does it, split into the plist read and the Finder display name; and what the
// running apps' icons cost to read and to draw at 80 pt, first and second time. Prints the order, the regular apps
// NSWorkspace knows, and the timings.
import AppKit
import Foundation

typealias CopyOrder = @convention(c) (UInt32) -> Unmanaged<CFArray>?
typealias CopyInfo = @convention(c) (Int32, CFTypeRef, CFArray?) -> Unmanaged<CFDictionary>?

func symbol<T>(_ name: String, as type: T.Type) -> T? {
    dlsym(UnsafeMutableRawPointer(bitPattern: -2), name).map { unsafeBitCast($0, to: type) }  // RTLD_DEFAULT
}

func time<T>(_ label: String, _ body: () -> T) -> T {
    let start = DispatchTime.now().uptimeNanoseconds
    let result = body()
    let end = DispatchTime.now().uptimeNanoseconds
    print(String(format: "%@: %.3f ms", label, Double(end - start) / 1e6))
    return result
}

guard let copyOrder = symbol("_LSCopyApplicationArrayInFrontToBackOrder", as: CopyOrder.self),
      let copyInfo = symbol("_LSCopyApplicationInformation", as: CopyInfo.self)
else {
    print("private symbols not found")
    exit(1)
}

let asns = time("LS order: ASN array") { copyOrder(0xFFFF_FFFE)?.takeRetainedValue() as? [CFTypeRef] ?? [] }
_ = time("LS order: ASN array again") { copyOrder(0xFFFF_FFFE)?.takeRetainedValue() as? [CFTypeRef] ?? [] }
let pids = time("LS order: pid per ASN, all keys") {
    asns.compactMap { asn -> pid_t? in
        let info = copyInfo(-2, asn, nil)?.takeRetainedValue() as? [String: Any]
        return (info?["pid"] as? NSNumber)?.int32Value
    }
}
let pidsKeyed = time("LS order: pid per ASN, keys [pid]") {
    asns.compactMap { asn -> pid_t? in
        let info = copyInfo(-2, asn, ["pid" as CFString] as CFArray)?.takeRetainedValue() as? [String: Any]
        return (info?["pid"] as? NSNumber)?.int32Value
    }
}
print("keyed answer equal: \(pids == pidsKeyed)")
if let first = asns.first, let info = copyInfo(-2, first, nil)?.takeRetainedValue() as? [String: Any] {
    print("info keys of the first ASN: \(info.keys.sorted())")
}
let apps = pids.compactMap { NSRunningApplication(processIdentifier: $0) }
print("⌘-Tab order (\(apps.count)):")
for app in apps {
    print("  \(app.localizedName ?? "?")  policy=\(app.activationPolicy.rawValue) hidden=\(app.isHidden) url=\(app.bundleURL?.path ?? "nil")")
}
let regular = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
print("NSWorkspace regular apps: \(regular.count); same set: \(Set(regular.map(\.processIdentifier)) == Set(pids))")
print("frontmost: \(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil") first in order: \(apps.first?.localizedName ?? "nil")")

let urls = apps.compactMap(\.bundleURL)
func plistID(_ url: URL) -> String? {
    guard let data = try? Data(contentsOf: url.appending(path: "Contents/Info.plist")),
          let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    else { return nil }
    return plist["CFBundleIdentifier"] as? String
}
_ = time("plist read+parse × \(urls.count), first") { urls.compactMap(plistID) }
_ = time("plist read+parse × \(urls.count), second") { urls.compactMap(plistID) }
_ = time("displayName(atPath:) × \(urls.count), first") { urls.map { FileManager.default.displayName(atPath: $0.path) } }
_ = time("displayName(atPath:) × \(urls.count), second") { urls.map { FileManager.default.displayName(atPath: $0.path) } }
_ = time("Bundle(url:).bundleIdentifier × \(urls.count)") { urls.compactMap { Bundle(url: $0)?.bundleIdentifier } }
_ = time("localizedName/bundleIdentifier × \(urls.count)") { apps.map { ($0.localizedName, $0.bundleIdentifier) } }
for app in apps {
    let finder = FileManager.default.displayName(atPath: app.bundleURL!.path).replacingOccurrences(of: ".app", with: "")
    if finder != app.localizedName { print("  name differs: running=\(app.localizedName ?? "?") finder=\(finder)") }
}

func bitmap(of source: NSImage, side: CGFloat) -> NSImage {
    let size = NSSize(width: side, height: side)
    let image = NSImage(size: size)
    for scale in [1, 2] {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(side) * scale, pixelsHigh: Int(side) * scale, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { continue }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        source.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        image.addRepresentation(rep)
    }
    return image
}
let runningIcons = time("NSRunningApplication.icon × \(apps.count), first") { apps.compactMap(\.icon) }
_ = time("NSRunningApplication.icon × \(apps.count), second") { apps.compactMap(\.icon) }
_ = time("draw running icons at 80 pt × \(runningIcons.count), first") { runningIcons.map { bitmap(of: $0, side: 80) } }
_ = time("draw running icons at 80 pt × \(runningIcons.count), second") { runningIcons.map { bitmap(of: $0, side: 80) } }
let fileIcons = time("NSWorkspace.icon(forFile:) × \(urls.count), first") { urls.map { NSWorkspace.shared.icon(forFile: $0.path) } }
_ = time("NSWorkspace.icon(forFile:) × \(urls.count), second") { urls.map { NSWorkspace.shared.icon(forFile: $0.path) } }
_ = time("draw file icons at 80 pt × \(fileIcons.count), first") { fileIcons.map { bitmap(of: $0, side: 80) } }
_ = time("draw file icons at 80 pt × \(fileIcons.count), second") { fileIcons.map { bitmap(of: $0, side: 80) } }
if let one = apps.first {
    _ = time("one app: icon + draw (\(one.localizedName ?? "?"))") { one.icon.map { bitmap(of: $0, side: 80) } }
}
