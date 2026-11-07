import AppKit
import SwiftUI

/// The update card's picture: a tray with an arrow-shaped hole and the arrow above it. Only the arrow and its hole
/// drift, both by the same animation, so the render server plays them in step and no code of ours runs per frame. The
/// drift exists while the view is in a window that is on screen and the system's Reduce motion setting is off.
final class UpdatePictureView: NSView {
    static let width: CGFloat = 71
    static let height: CGFloat = 89
    static let drift: CGFloat = 4
    /// Seconds from one end of the drift to the other; the whole cycle takes twice this.
    static let halfPeriod: CFTimeInterval = 1.5
    static let animationKey = "drift"
    /// The hole's mask is taller than the picture by the drift at each end, so the moving hole never uncovers an edge.
    static let maskHeight = height + 2 * drift
    private static let maskScale: CGFloat = 4

    let trayLayer = CALayer()
    let arrowLayer = CALayer()
    /// The tray's layer is masked by this, which has the arrow knocked out of it; it drifts with the arrow.
    let maskLayer = CALayer()
    private let arrowClip = CALayer()
    private let clipMask = CALayer()
    private let tray: NSImage?
    private let arrow: NSImage?
    private let isOnScreen: (NSWindow) -> Bool
    private let reduceMotion: () -> Bool
    private var isObservingDisplayOptions = false
    private weak var observedWindow: NSWindow?

    init(
        tray: NSImage?, arrow: NSImage?, isOnScreen: @escaping (NSWindow) -> Bool, reduceMotion: @escaping () -> Bool
    ) {
        self.tray = tray
        self.arrow = arrow
        self.isOnScreen = isOnScreen
        self.reduceMotion = reduceMotion
        super.init(frame: NSRect(x: 0, y: 0, width: Self.width, height: Self.height))
        wantsLayer = true
        let silent: [String: CAAction] = [
            "contents": NSNull(), "bounds": NSNull(), "position": NSNull(), "transform": NSNull(),
            "contentsScale": NSNull(),
        ]
        for layer in [trayLayer, arrowClip, arrowLayer] {
            layer.bounds = CGRect(x: 0, y: 0, width: Self.width, height: Self.height)
            layer.position = CGPoint(x: Self.width / 2, y: Self.height / 2)
            layer.actions = silent
        }
        for layer in [maskLayer, clipMask] {
            layer.bounds = CGRect(x: 0, y: 0, width: Self.width, height: Self.maskHeight)
            layer.position = CGPoint(x: Self.width / 2, y: Self.height / 2)
            layer.actions = silent
            layer.contentsScale = Self.maskScale
        }
        maskLayer.contents = arrow.flatMap(Self.knockout)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        clipMask.contents = tray.flatMap(Self.knockout)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        trayLayer.mask = maskLayer
        // The design's arrow is filled only where the tray is not: inside the tray it is the hole. The clip stays
        // still while the arrow drifts inside it.
        arrowClip.mask = clipMask
        arrowClip.addSublayer(arrowLayer)
        self.layer?.addSublayer(trayLayer)
        self.layer?.addSublayer(arrowClip)
        updateContents()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    /// A solid rectangle the size of a mask layer with `shape` knocked out, the shape sitting where the picture's layers
    /// sit, `drift` in from the mask's edges.
    static func knockout(_ shape: NSImage) -> NSImage? {
        let size = NSSize(width: width, height: maskHeight)
        let pixelsWide = Int(size.width * maskScale)
        let pixelsHigh = Int(size.height * maskScale)
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: pixelsWide, pixelsHigh: pixelsHigh, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
                bitsPerPixel: 0)
        else { return nil }
        rep.size = size
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor.black.setFill()
        NSRect(origin: .zero, size: size).fill()
        shape.draw(
            in: NSRect(x: 0, y: drift, width: width, height: height), from: .zero, operation: .destinationOut,
            fraction: 1)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }

    override var intrinsicContentSize: NSSize { NSSize(width: Self.width, height: Self.height) }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateContents()
        stopObservingWindow()
        if let window {
            observedWindow = window
            NotificationCenter.default.addObserver(
                self, selector: #selector(windowStateChanged), name: NSWindow.didChangeOcclusionStateNotification,
                object: window)
            startObservingDisplayOptions()
        } else {
            stopObservingDisplayOptions()
        }
        applyMotion()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateContents()
    }

    private func updateContents() {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        for (layer, image) in [(trayLayer, tray), (arrowLayer, arrow)] {
            layer.contentsScale = scale
            layer.contents = image?.layerContents(forContentsScale: scale)
        }
    }

    private func stopObservingWindow() {
        guard let observedWindow else { return }
        NotificationCenter.default.removeObserver(
            self, name: NSWindow.didChangeOcclusionStateNotification, object: observedWindow)
        self.observedWindow = nil
    }

    private func startObservingDisplayOptions() {
        guard !isObservingDisplayOptions else { return }
        isObservingDisplayOptions = true
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(windowStateChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    }

    private func stopObservingDisplayOptions() {
        guard isObservingDisplayOptions else { return }
        isObservingDisplayOptions = false
        NSWorkspace.shared.notificationCenter.removeObserver(
            self, name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    }

    @objc private func windowStateChanged(_ notification: Notification) {
        applyMotion()
    }

    private func applyMotion() {
        let moves = window.map(isOnScreen) == true && !reduceMotion()
        for layer in [arrowLayer, maskLayer] {
            if !moves {
                layer.removeAnimation(forKey: Self.animationKey)
            } else if layer.animation(forKey: Self.animationKey) == nil {
                let drift = CABasicAnimation(keyPath: "position.y")
                drift.byValue = -Self.drift
                drift.duration = Self.halfPeriod
                drift.autoreverses = true
                drift.repeatCount = .infinity
                drift.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                // Not a no-op, though the drift never completes: without it a real window opens with the arrow still.
                drift.isRemovedOnCompletion = false
                layer.add(drift, forKey: Self.animationKey)
            }
        }
    }
}

/// The card's picture, drifting for as long as its window is on screen.
struct DriftingUpdatePicture: NSViewRepresentable {
    func makeNSView(context: Context) -> UpdatePictureView {
        UpdatePictureView(
            tray: BundleImage.nsImage("update-tray"), arrow: BundleImage.nsImage("update-arrow"),
            isOnScreen: { $0.occlusionState.contains(.visible) },
            reduceMotion: { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion })
    }

    func updateNSView(_ view: UpdatePictureView, context: Context) {}
}
