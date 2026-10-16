import AppKit
import QuartzCore

/// Both switchers' window: borderless, non-activating, click-through, screen-saver level on every Space and beside
/// full-screen apps, never key. Its content is Liquid Glass under `roundedClip`. Presents at once or with a short
/// appear animation; dismisses with a 150 ms fade (at once with Reduce motion) unless presented again meanwhile.
class OverlayPanel: NSPanel {
    private static let fadeKey = "fade"
    private static let appearDuration: CFTimeInterval = 0.12
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

    /// Fully opaque and in front, dropping any fade still running. `animated` (never with Reduce motion) fades it in
    /// briefly instead of showing it at once.
    func present(animated: Bool) {
        isPresented = true
        generation += 1
        guard let layer = contentView?.layer else { return orderFrontRegardless() }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.removeAnimation(forKey: Self.fadeKey)
        layer.opacity = 1
        CATransaction.commit()
        if animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            let appear = CABasicAnimation(keyPath: "opacity")
            appear.fromValue = 0
            appear.toValue = 1
            appear.duration = Self.appearDuration
            appear.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(appear, forKey: Self.fadeKey)
        }
        orderFrontRegardless()
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
