import AppKit
import SwiftUI

/// The Accessibility hint's gear: one layer the render server turns, so no code of ours runs per frame. It turns while
/// the view is in a window and the system's Reduce motion setting is off, and rests in the design's pose otherwise.
final class GearView: NSView {
    static let side: CGFloat = 91
    /// Seconds per turn, tuned by eye.
    static let period: CFTimeInterval = 30
    static let animationKey = "turn"

    let gearLayer = CALayer()
    private let image: NSImage?
    private let reduceMotion: () -> Bool
    private var isObserving = false

    init(image: NSImage?, reduceMotion: @escaping () -> Bool) {
        self.image = image
        self.reduceMotion = reduceMotion
        super.init(frame: NSRect(x: 0, y: 0, width: Self.side, height: Self.side))
        wantsLayer = true
        gearLayer.bounds = CGRect(x: 0, y: 0, width: Self.side, height: Self.side)
        gearLayer.position = CGPoint(x: Self.side / 2, y: Self.side / 2)
        gearLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        gearLayer.actions = [
            "contents": NSNull(), "bounds": NSNull(), "position": NSNull(), "transform": NSNull(),
            "contentsScale": NSNull(),
        ]
        layer?.addSublayer(gearLayer)
        updateContents()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize { NSSize(width: Self.side, height: Self.side) }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateContents()
        if window != nil {
            startObserving()
            applyReduceMotion()
        } else {
            stopObserving()
            gearLayer.removeAnimation(forKey: Self.animationKey)
        }
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateContents()
    }

    private func updateContents() {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        gearLayer.contentsScale = scale
        gearLayer.contents = image?.layerContents(forContentsScale: scale)
    }

    private func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(displayOptionsChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    }

    private func stopObserving() {
        guard isObserving else { return }
        isObserving = false
        NSWorkspace.shared.notificationCenter.removeObserver(
            self, name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    }

    @objc private func displayOptionsChanged(_ notification: Notification) {
        guard window != nil else { return }
        applyReduceMotion()
    }

    private func applyReduceMotion() {
        if reduceMotion() {
            gearLayer.removeAnimation(forKey: Self.animationKey)
        } else if gearLayer.animation(forKey: Self.animationKey) == nil {
            // The view is flipped, so a positive angle turns clockwise on screen.
            let turn = CABasicAnimation(keyPath: "transform.rotation.z")
            turn.fromValue = 0
            turn.toValue = 2 * Double.pi
            turn.timingFunction = CAMediaTimingFunction(name: .linear)
            turn.repeatCount = .infinity
            turn.duration = Self.period
            turn.isRemovedOnCompletion = false
            gearLayer.add(turn, forKey: Self.animationKey)
        }
    }
}

/// The gear, turning for as long as it is in a window.
struct TurningGear: NSViewRepresentable {
    func makeNSView(context: Context) -> GearView {
        GearView(
            image: BundleImage.nsImage("gear"),
            reduceMotion: { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion })
    }

    func updateNSView(_ view: GearView, context: Context) {}
}
