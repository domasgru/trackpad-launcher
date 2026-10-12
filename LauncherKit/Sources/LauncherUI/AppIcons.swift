import AppKit
import Dispatch
import LauncherCore
import Synchronization

/// Square bitmap icons (16 pt for the app pickers, 80 pt for the switcher), drawn away from the click path.
///
/// An icon is keyed by app URL and stamped with its bundle's Info.plist modification date and the appearance it was
/// drawn in, so an app updated in place and a light/dark switch are redrawn by the next pass.
final class AppIcons {
    private nonisolated struct Stamp: Equatable, Sendable {
        let modified: Date?
        let appearance: NSAppearance.Name
    }

    private nonisolated struct Rendered: Sendable {
        let icon: NSImage
        let stamp: Stamp
    }

    /// `NSAppearance` is not marked `Sendable`; it is immutable and the AppKit docs allow drawing under it on any thread.
    private nonisolated struct Appearance: @unchecked Sendable {
        let value: NSAppearance
        init(_ value: NSAppearance) { self.value = value }
    }

    private var cache: [URL: Rendered] = [:]
    private let generic: NSImage
    private let side: CGFloat

    init(side: CGFloat = 16) {
        self.side = side
        let source = NSWorkspace.shared.icon(for: .applicationBundle)
        generic = Self.bitmap(of: source, side: side, appearance: NSApp.effectiveAppearance)
    }

    /// The cached icon, or a generic app icon on a miss. Never draws: the menu uses it on the click path.
    func cachedIcon(for url: URL) -> NSImage { cache[url]?.icon ?? generic }

    /// Draws a missing icon on the spot and caches it. Only for an app outside the picker's list.
    func iconDrawingIfMissing(for url: URL) -> NSImage {
        if let cached = cache[url] { return cached.icon }
        merge(Self.renderChanged(urls: [url], cached: [:], side: side, appearance: Appearance(NSApp.effectiveAppearance)))
        return cachedIcon(for: url)
    }

    /// The switcher's icon for `app`: cached in the current appearance, else the running app's already-loaded icon (about 0.1 ms), else drawn on
    /// the spot. The frontmost app is running by definition, so it takes the second path at the swipe's first frame.
    func icon(forSwitcher app: AppEntry) -> NSImage {
        let appearance = NSApp.effectiveAppearance
        if let cached = cache[app.url], cached.stamp.appearance == appearance.name { return cached.icon }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID.rawValue)
            .first { $0.bundleURL == app.url }
        guard let source = running?.icon else {
            merge(
                Self.renderChanged(
                    urls: [app.url], cached: stamps(), side: side, appearance: Appearance(appearance)))
            return cachedIcon(for: app.url)
        }
        let icon = Self.bitmap(of: source, side: side, appearance: appearance)
        cache[app.url] = Rendered(icon: icon, stamp: Stamp(modified: Self.infoModified(app.url), appearance: appearance.name))
        return icon
    }

    /// Draws every new or changed icon and waits, spreading the drawing across cores.
    func renderOnMainActor(_ apps: [AppEntry]) {
        merge(
            Self.renderChanged(
                urls: apps.map(\.url), cached: stamps(), side: side, appearance: Appearance(NSApp.effectiveAppearance)))
    }

    /// The same pass away from the main actor; the results merge here. Overlapping passes are harmless: the last
    /// write wins.
    func renderOffMainActor(_ apps: [AppEntry]) {
        let urls = apps.map(\.url)
        let cached = stamps()
        let appearance = Appearance(NSApp.effectiveAppearance)
        let side = side
        Task {
            let rendered = await Self.renderChangedOffMain(urls: urls, cached: cached, side: side, appearance: appearance)
            merge(rendered)
        }
    }

    private func stamps() -> [URL: Stamp] { cache.mapValues(\.stamp) }

    private func merge(_ rendered: [URL: Rendered]) { cache.merge(rendered) { $1 } }

    @concurrent private static func renderChangedOffMain(
        urls: [URL], cached: [URL: Stamp], side: CGFloat, appearance: Appearance
    ) async -> [URL: Rendered] {
        renderChanged(urls: urls, cached: cached, side: side, appearance: appearance)
    }

    /// Reads each bundle's stamp and draws only the icons whose stamp is new or changed.
    private nonisolated static func renderChanged(
        urls: [URL], cached: [URL: Stamp], side: CGFloat, appearance: Appearance
    ) -> [URL: Rendered] {
        let results = Mutex<[URL: Rendered]>([:])
        DispatchQueue.concurrentPerform(iterations: urls.count) { index in
            let url = urls[index]
            let stamp = Stamp(modified: infoModified(url), appearance: appearance.value.name)
            guard cached[url] != stamp else { return }
            let source = NSWorkspace.shared.icon(forFile: url.path)
            let icon = bitmap(of: source, side: side, appearance: appearance.value)
            results.withLock { $0[url] = Rendered(icon: icon, stamp: stamp) }
        }
        return results.withLock { $0 }
    }

    private nonisolated static func infoModified(_ app: URL) -> Date? {
        let values = try? app.appending(path: "Contents/Info.plist").resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate
    }

    /// `source` drawn `side` points square, at 1x and 2x pixels, in `appearance`.
    private nonisolated static func bitmap(of source: NSImage, side: CGFloat, appearance: NSAppearance) -> NSImage {
        let size = NSSize(width: side, height: side)
        let image = NSImage(size: size)
        for scale in [1, 2] {
            guard
                let rep = NSBitmapImageRep(
                    bitmapDataPlanes: nil, pixelsWide: Int(side) * scale, pixelsHigh: Int(side) * scale, bitsPerSample: 8,
                    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                    bytesPerRow: 0, bitsPerPixel: 0)
            else { continue }
            rep.size = size
            appearance.performAsCurrentDrawingAppearance {
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                source.draw(in: NSRect(origin: .zero, size: size))
                NSGraphicsContext.restoreGraphicsState()
            }
            image.addRepresentation(rep)
        }
        return image
    }
}
