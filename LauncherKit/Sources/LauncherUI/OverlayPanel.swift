import AppKit
import QuartzCore

/// How an overlay appears: an opacity fade-in, and optionally a spring up from a smaller scale anchored at the panel's
/// top-left corner.
struct OverlayAppear {
    var duration: CFTimeInterval
    var fromScale: CGFloat?
    var stiffness = 0.0
    var damping = 0.0
}

/// Both switchers' window: borderless, non-activating, click-through, screen-saver level on every Space and beside
/// full-screen apps, never key. Its content is Liquid Glass under `roundedClip`. Presents at once, or with an
/// `OverlayAppear` when one is given; dismisses with a 150 ms fade (at once with Reduce motion) unless presented again
/// meanwhile.
class OverlayPanel: NSPanel {
    private static let fadeKey = "fade"
    private static let appearScaleKey = "appearScale"
    private static let fadeDuration: CFTimeInterval = 0.15

    /// On screen, or about to be: true from `present` until `dismiss`, even while the fade still runs.
    private(set) var isPresented = false
    /// Bumped by every present and dismiss, so a fade's completion that a later one outlived does nothing.
    private var generation = 0

    init(cornerRadius: CGFloat, content: NSView) {
        super.init(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        animationBehavior = .none
        isReleasedWhenClosed = false

        let glass = NSGlassEffectView()
        glass.style = .regular
        glass.cornerRadius = cornerRadius
        glass.contentView = content
        contentView = roundedClip(glass, cornerRadius: cornerRadius)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Fully opaque and in front, dropping any fade still running. With `appear` (never with Reduce motion) it plays
    /// that appear instead of showing at once.
    func present(appear: OverlayAppear?) {
        isPresented = true
        generation += 1
        guard let layer = contentView?.layer else { return orderFrontRegardless() }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.removeAnimation(forKey: Self.fadeKey)
        layer.removeAnimation(forKey: Self.appearScaleKey)
        layer.opacity = 1
        CATransaction.commit()
        if let appear, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.toValue = 1
            fade.duration = appear.duration
            fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(fade, forKey: Self.fadeKey)
            if let scale = appear.fromScale {
                let spring = CASpringAnimation(keyPath: "transform")
                spring.fromValue = NSValue(caTransform3D: Self.transform(layer, scaledBy: scale))
                spring.toValue = NSValue(caTransform3D: CATransform3DIdentity)
                spring.stiffness = appear.stiffness
                spring.damping = appear.damping
                spring.duration = spring.settlingDuration
                layer.add(spring, forKey: Self.appearScaleKey)
            }
        }
        orderFrontRegardless()
    }

    /// `layer` scaled by `scale` about its top-left corner, wherever its anchor point is.
    private static func transform(_ layer: CALayer, scaledBy scale: CGFloat) -> CATransform3D {
        let bounds = layer.bounds
        let anchor = CGPoint(x: layer.anchorPoint.x * bounds.width, y: layer.anchorPoint.y * bounds.height)
        let topLeft = CGPoint(x: 0, y: layer.isGeometryFlipped ? 0 : bounds.height)
        return CATransform3DConcat(
            CATransform3DMakeScale(scale, scale, 1),
            CATransform3DMakeTranslation((topLeft.x - anchor.x) * (1 - scale), (topLeft.y - anchor.y) * (1 - scale), 0))
    }

    /// Opacity to 0 over 150 ms on the render server, then out, unless presented again meanwhile (Reduce motion: out
    /// at once). A no-op while not presented.
    func dismiss() {
        guard isPresented else { return }
        isPresented = false
        generation += 1
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, let layer = contentView?.layer else {
            return removeNow()
        }
        let current = generation
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.generation == current else { return }
                self.removeNow()
            }
        }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = layer.presentation()?.opacity ?? layer.opacity
        fade.toValue = 0
        fade.duration = Self.fadeDuration
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.opacity = 0
        layer.add(fade, forKey: Self.fadeKey)
        CATransaction.commit()
    }

    /// Runs once the panel is out (after the fade). Subclasses override to drop what they hold.
    func emptied() {}

    private func removeNow() {
        orderOut(nil)
        emptied()
    }
}
