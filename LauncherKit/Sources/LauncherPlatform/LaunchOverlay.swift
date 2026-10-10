import AppKit
import Dispatch
import LauncherCore
import QuartzCore
import Synchronization

/// Plays launch animations. Each play gets its own borderless, click-through panel above everything on every Space,
/// holding one icon layer that Core Animation drives through the keyframes `LaunchFlight` staged. The panel is closed
/// from the animation's completion callback; no code of ours runs while it plays.
@MainActor final class LaunchOverlay {
    private var flights = LaunchFlights()
    /// Rendered app icons, keyed by bundle location.
    private var icons: [URL: CGImage] = [:]
    /// Panels still playing. AppKit keeps closed panels in its window list, so the overlay tracks its own.
    private var playingPanels: Set<NSPanel> = []

    init() {
        // A process's first window-server window costs about 27 ms to create, against 1 ms afterwards; pay it now
        // instead of at the first gesture.
        Self.makePanel(frame: CGRect(x: 0, y: 0, width: 1, height: 1))?.panel.close()
    }

    /// Renders each app's icon away from the main actor, then replaces the previous set: a first render of an icon at
    /// this size can take over 100 ms, which must land on neither a gesture nor a click. Until the new set arrives the
    /// old one serves. Overlapping passes are harmless: the last to finish wins.
    func prepare(for apps: [AppEntry]) {
        let urls = apps.map(\.url)
        let pixels = Self.pixels(at: Self.highestScale)
        Task {
            icons = await Self.renderOffMain(urls, pixels: pixels)
        }
    }

    func play(for app: AppEntry) {
        let pointer = NSEvent.mouseLocation
        let displays = NSScreen.screens.map { LaunchDisplay(frame: $0.frame, scale: $0.backingScaleFactor) }
        let reduceMotion =
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || LaunchTuning.current.forceReduceMotion
        let flight = flights.next(draw: .random(in: -1...1), reduceMotion: reduceMotion)
        guard let stage = flight.staged(at: pointer, among: displays),
              case let (panel, host)? = Self.makePanel(frame: stage.frame)
        else { return }
        playingPanels.insert(panel)
        panel.orderFrontRegardless()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock { [weak self] in
            MainActor.assumeIsolated {
                panel.close()
                self?.playingPanels.remove(panel)
            }
        }
        let icon = CALayer()
        icon.bounds = CGRect(x: 0, y: 0, width: stage.iconSide, height: stage.iconSide)
        icon.position = stage.iconCentre
        icon.contents = bitmap(for: app, scale: stage.scale)
        icon.contentsScale = stage.scale
        icon.minificationFilter = .trilinear
        icon.allowsEdgeAntialiasing = true
        for animation in stage.animations {
            guard let keyPath = animation.keyPath else { continue }
            // The model holds the last keyframe, so nothing flashes once the animation is removed.
            icon.setValue(animation.values?.last, forKeyPath: keyPath)
            icon.add(animation, forKey: keyPath)
        }
        host.addSublayer(icon)
        CATransaction.commit()
    }

    /// The app's icon with at least `scale` pixels per point, from the cache when it holds one that sharp. Otherwise,
    /// because the app moved or a sharper display was connected since the last prepare, it is rendered and cached now.
    private func bitmap(for app: AppEntry, scale: CGFloat) -> CGImage? {
        let pixels = Self.pixels(at: scale)
        if let cached = icons[app.url], cached.width >= pixels { return cached }
        let rendered = Self.renderIcon(of: app.url, pixels: pixels)
        icons[app.url] = rendered
        return rendered
    }

    /// Renders on all cores away from the main actor, so a first render never delays a click.
    @concurrent private static func renderOffMain(_ urls: [URL], pixels: Int) async -> [URL: CGImage] {
        let results = Mutex<[URL: CGImage]>([:])
        DispatchQueue.concurrentPerform(iterations: urls.count) { index in
            guard let icon = renderIcon(of: urls[index], pixels: pixels) else { return }
            results.withLock { $0[urls[index]] = icon }
        }
        return results.withLock { $0 }
    }

    private static var highestScale: CGFloat {
        NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
    }

    /// The icon's side at the pop's peak, in pixels at `scale`.
    private static func pixels(at scale: CGFloat) -> Int {
        Int((LaunchFlight.peakSide * scale).rounded())
    }

    /// The icon Finder shows for the app, as a bitmap of the icon's peak size in pixels at `scale`, so it never
    /// has to be scaled up.
    private nonisolated static func renderIcon(of app: URL, pixels: Int) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.displayP3),
              let context = CGContext(
                data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        NSWorkspace.shared.icon(forFile: app.path).draw(in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()
    }

    /// Borderless, non-activating, click-through and never key. Screen-saver level puts it above the menu bar, menus,
    /// the launcher window and full-screen apps; it shows on every Space and holds still while Spaces slide. Its
    /// content view is plain, non-flipped and layer-backed, so the staged y-up keyframes apply to its sublayers as
    /// they are. Nil when the content view gets no layer, which is known before any window exists.
    private static func makePanel(frame: CGRect) -> (panel: NSPanel, host: CALayer)? {
        let content = NSView(frame: CGRect(origin: .zero, size: frame.size))
        content.wantsLayer = true
        guard let host = content.layer else { return nil }
        let panel = NSPanel(
            contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // The icon art carries its own shadow.
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        // The app is never active, so it never deactivates either.
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.isReleasedWhenClosed = false
        panel.contentView = content
        return (panel, host)
    }
}
