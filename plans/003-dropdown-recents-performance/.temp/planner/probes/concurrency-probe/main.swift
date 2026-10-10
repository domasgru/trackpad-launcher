// Swift 6 strict-concurrency facts the plan relies on: NSImage/CGImage Sendable, NSWorkspace off main,
// kMDItemLastUsedDate from nonisolated code, and the cost of rendering icons into bitmaps off the main actor
// then building menu items from them on main.
import AppKit
import CoreServices

func requireSendable<T: Sendable>(_: T.Type) {}
requireSendable(NSImage.self)
requireSendable(CGImage.self)

nonisolated func lastOpened(_ url: URL) -> Date? {
    guard let item = MDItemCreateWithURL(nil, url as CFURL) else { return nil }
    return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
}

/// Off the main actor: the workspace icon drawn once into a 32x32-pixel bitmap shown at 16 pt.
nonisolated func renderedIcon(_ url: URL) -> NSImage {
    let source = NSWorkspace.shared.icon(forFile: url.path)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: 32, pixelsHigh: 32, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: 16, height: 16)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    source.draw(in: NSRect(x: 0, y: 0, width: 16, height: 16))
    NSGraphicsContext.restoreGraphicsState()
    let image = NSImage(size: NSSize(width: 16, height: 16))
    image.addRepresentation(rep)
    return image
}

@concurrent func renderAll(_ urls: [URL]) async -> [URL: NSImage] {
    var out: [URL: NSImage] = [:]
    for url in urls { out[url] = renderedIcon(url) }
    return out
}

func ms(_ start: ContinuousClock.Instant) -> String {
    let d = ContinuousClock.now - start
    return String(format: "%.1f ms", Double(d.components.attoseconds) / 1e15 + Double(d.components.seconds) * 1000)
}

@MainActor func run() async {
    let roots = ["/Applications", "/System/Applications"].map { URL(filePath: $0) }
    var urls: [URL] = []
    for root in roots {
        let children = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        urls += children.filter { $0.pathExtension == "app" }
    }
    var t = ContinuousClock.now
    let icons = await renderAll(urls)
    print("off-main render \(icons.count) icons: \(ms(t))")
    t = ContinuousClock.now
    let menu = NSMenu()
    for url in urls {
        let item = NSMenuItem(title: url.deletingPathExtension().lastPathComponent, action: nil, keyEquivalent: "")
        item.image = icons[url]
        menu.addItem(item)
    }
    print("main: build \(menu.items.count) items from rendered icons: \(ms(t))")
    t = ContinuousClock.now
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: 32, pixelsHigh: 32, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    for image in icons.values { image.draw(in: NSRect(x: 0, y: 0, width: 16, height: 16)) }
    NSGraphicsContext.restoreGraphicsState()
    print("main: draw all rendered icons at 16 pt: \(ms(t))")
    t = ContinuousClock.now
    let dated = await Task.detached { urls.compactMap { lastOpened($0) }.count }.value
    print("off-main MDItem lastUsed: \(dated)/\(urls.count) in \(ms(t))")
}

Task { @MainActor in
    await run()
    exit(0)
}
RunLoop.main.run()
