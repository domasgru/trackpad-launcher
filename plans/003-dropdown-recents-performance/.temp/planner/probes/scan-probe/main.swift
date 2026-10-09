// Measures the picker's costs on this Mac: folder enumeration + Info.plist reads, Spotlight last-used dates
// (NSMetadataItem and MDItem), the lastuseddate xattr, icon loading on and off the main thread, NSMenuItem creation.
import AppKit
import CoreServices
import Foundation

func ms(_ start: DispatchTime) -> String {
    String(format: "%.1f ms", Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e6)
}

struct Entry { let bundleID: String; let name: String; let url: URL }

func appBundles(under directory: URL) -> [URL] {
    let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
    let children = (try? FileManager.default.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
    return children.sorted { $0.path < $1.path }.flatMap { child -> [URL] in
        if child.pathExtension == "app" { return [child] }
        let values = try? child.resourceValues(forKeys: Set(keys))
        guard values?.isDirectory == true, values?.isSymbolicLink != true else { return [] }
        return appBundles(under: child)
    }
}

func entry(at url: URL) -> Entry? {
    guard url.pathExtension == "app",
          let data = try? Data(contentsOf: url.appending(path: "Contents/Info.plist")),
          let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
          let identifier = plist["CFBundleIdentifier"] as? String, !identifier.isEmpty
    else { return nil }
    var name = FileManager.default.displayName(atPath: url.path)
    if name.hasSuffix(".app") { name.removeLast(4) }
    return Entry(bundleID: identifier, name: name, url: url)
}

let roots = [
    URL(filePath: "/Applications"),
    URL(filePath: "/System/Applications"),
    FileManager.default.homeDirectoryForCurrentUser.appending(path: "Applications"),
]
let extras = [URL(filePath: "/System/Library/CoreServices/Finder.app")]

// 1. Enumeration + plist parse, twice (cold-ish then warm).
var apps: [Entry] = []
for pass in 1...2 {
    let t = DispatchTime.now()
    var seen = Set<String>()
    var found: [Entry] = []
    for url in roots.flatMap(appBundles(under:)) + extras {
        guard let e = entry(at: url), seen.insert(e.bundleID).inserted else { continue }
        found.append(e)
    }
    apps = found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    print("enumerate+plist pass \(pass): \(apps.count) apps in \(ms(t))")
}

// 2. Spotlight last-used via NSMetadataItem(url:).
var dates: [String: Date] = [:]
for pass in 1...2 {
    let t = DispatchTime.now()
    dates = [:]
    for e in apps {
        if let item = NSMetadataItem(url: e.url),
           let d = item.value(forAttribute: NSMetadataItemLastUsedDateKey) as? Date {
            dates[e.bundleID] = d
        }
    }
    print("NSMetadataItem lastUsed pass \(pass): \(dates.count)/\(apps.count) dated in \(ms(t))")
}
// 2b. Same via MDItemCreateWithURL.
do {
    let t = DispatchTime.now()
    var n = 0
    for e in apps {
        if let item = MDItemCreateWithURL(nil, e.url as CFURL),
           MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date != nil { n += 1 }
    }
    print("MDItem lastUsed: \(n)/\(apps.count) dated in \(ms(t))")
}
// 2c. One MDQuery over the roots, synchronous.
do {
    let t = DispatchTime.now()
    let query = MDQueryCreate(nil, "kMDItemContentType == 'com.apple.application-bundle' && kMDItemLastUsedDate > $time.iso(1970-01-01T00:00:00Z)" as CFString, nil, nil)!
    MDQuerySetSearchScope(query, (roots.map(\.path) + ["/System/Library/CoreServices"]) as CFArray, 0)
    MDQueryExecute(query, CFOptionFlags(kMDQuerySynchronous.rawValue))
    let count = MDQueryGetResultCount(query)
    print("MDQuery sync: \(count) dated app bundles under roots in \(ms(t))")
}

let recent = apps.compactMap { e in dates[e.bundleID].map { (e.name, $0, e.url.path) } }
    .sorted { $0.1 > $1.1 }.prefix(14)
print("Top recent by Spotlight:")
let f = ISO8601DateFormatter()
for (name, d, path) in recent { print("  \(f.string(from: d))  \(name)  [\(path.hasPrefix("/System") ? "system" : "data")]") }

// 3. xattr com.apple.lastuseddate#PS presence, data vs system volume.
func hasXattr(_ url: URL) -> Bool { getxattr(url.path, "com.apple.lastuseddate#PS", nil, 0, 0, 0) > 0 }
let dataApps = apps.filter { !$0.url.path.hasPrefix("/System") }
let sysApps = apps.filter { $0.url.path.hasPrefix("/System") }
print("xattr lastuseddate#PS: data-volume \(dataApps.filter { hasXattr($0.url) }.count)/\(dataApps.count), system-volume \(sysApps.filter { hasXattr($0.url) }.count)/\(sysApps.count); dated-by-Spotlight on system volume: \(sysApps.filter { dates[$0.bundleID] != nil }.count)")

// 4. Icons on the main thread, two passes.
var icons: [String: NSImage] = [:]
for pass in 1...2 {
    let t = DispatchTime.now()
    for e in apps {
        if let icon = NSWorkspace.shared.icon(forFile: e.url.path).copy() as? NSImage {
            icon.size = NSSize(width: 16, height: 16)
            icons[e.bundleID] = icon
        }
    }
    print("icon(forFile:) main pass \(pass): \(icons.count) in \(ms(t))")
}
// 4b. Draw each icon once at 16 pt into a bitmap: the cost the menu pays on first display.
do {
    let t = DispatchTime.now()
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 32, pixelsHigh: 32, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    for icon in icons.values { icon.draw(in: NSRect(x: 0, y: 0, width: 16, height: 16)) }
    NSGraphicsContext.restoreGraphicsState()
    print("draw all icons at 16pt: \(ms(t))")
}

// 5. NSMenuItem creation with images.
do {
    let t = DispatchTime.now()
    let menu = NSMenu()
    for e in apps {
        let item = NSMenuItem(title: e.name, action: nil, keyEquivalent: "")
        item.image = icons[e.bundleID]
        menu.addItem(item)
    }
    print("NSMenuItem x\(menu.items.count) with images: \(ms(t))")
}

// 6. Off-main icon priming in a fresh process: run with `prime` argument to measure icon(forFile:) off main first,
// then on main.
if CommandLine.arguments.contains("prime") {
    let group = DispatchGroup()
    group.enter()
    let t = DispatchTime.now()
    DispatchQueue.global(qos: .utility).async {
        for e in apps { _ = NSWorkspace.shared.icon(forFile: e.url.path) }
        group.leave()
    }
    group.wait()
    print("off-main prime: \(ms(t))")
    let t2 = DispatchTime.now()
    for e in apps { _ = NSWorkspace.shared.icon(forFile: e.url.path) }
    print("main after prime: \(ms(t2))")
}
