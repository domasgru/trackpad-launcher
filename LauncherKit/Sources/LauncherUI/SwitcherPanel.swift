import AppKit
import LauncherCore
import QuartzCore

/// The switcher's window: the launch overlay's configuration (borderless, non-activating, click-through, above
/// everything on every Space, never key) around Liquid Glass. It holds the icon layers, the glass highlight under
/// them and the selected app's name; `SwitcherPresenter` decides everything shown.
final class SwitcherPanel: NSPanel {
    static let selectedScale: CGFloat = 1.12

    private static let cornerRadius: CGFloat = 34
    private static let topPadding: CGFloat = 22
    private static let bottomPadding: CGFloat = 18
    private static let nameHeight: CGFloat = 18
    private static let nameGap: CGFloat = 10

    private static let fadeKey = "fade"

    private let content = NSView()
    private let highlight = NSGlassEffectView()
    private let iconsHost = NSView()
    private let name = NSTextField(labelWithString: "")
    private var iconLayers: [CALayer] = []
    private var layout = SwitcherRowLayout(iconCount: 0, displayWidth: 0)

    init() {
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

        content.wantsLayer = true
        iconsHost.wantsLayer = true
        highlight.style = .clear
        highlight.cornerRadius = 24
        highlight.wantsLayer = true
        name.alignment = .center
        name.font = .systemFont(ofSize: 13, weight: .medium)
        name.textColor = .labelColor
        name.lineBreakMode = .byTruncatingTail
        content.addSubview(highlight)
        content.addSubview(iconsHost)
        content.addSubview(name)

        let glass = NSGlassEffectView()
        glass.style = .regular
        glass.cornerRadius = Self.cornerRadius
        glass.contentView = content
        contentView = roundedClip(glass, cornerRadius: Self.cornerRadius)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Opacity to 0 over `duration` on the render server; `completion` runs when the animation ends or is removed.
    func fadeOut(duration: CFTimeInterval, completion: @escaping () -> Void) {
        guard let layer = contentView?.layer else { return completion() }
        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = layer.presentation()?.opacity ?? layer.opacity
        fade.toValue = 0
        fade.duration = duration
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.opacity = 0
        layer.add(fade, forKey: Self.fadeKey)
        CATransaction.commit()
    }

    /// Fully opaque again, dropping any fade still running.
    func restoreOpacity() {
        guard let layer = contentView?.layer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.removeAnimation(forKey: Self.fadeKey)
        layer.opacity = 1
        CATransaction.commit()
    }

    /// Replaces the icon layers with one layer per image, left to right, sized and spaced by `layout`, and centres
    /// the panel on `screen`.
    func layoutRow(_ images: [NSImage], layout: SwitcherRowLayout, on screen: NSRect, scale: CGFloat) {
        self.layout = layout
        let size = CGSize(
            width: layout.panelWidth,
            height: Self.bottomPadding + Self.nameHeight + Self.nameGap + layout.highlightSide + Self.topPadding)
        setFrame(
            NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2, width: size.width, height: size.height),
            display: false)
        content.frame = NSRect(origin: .zero, size: size)
        iconsHost.frame = content.bounds
        let rowY = Self.bottomPadding + Self.nameHeight + Self.nameGap
        name.frame = NSRect(
            x: SwitcherRowLayout.padding, y: Self.bottomPadding, width: size.width - 2 * SwitcherRowLayout.padding,
            height: Self.nameHeight)
        highlight.frame.size = CGSize(width: layout.highlightSide, height: layout.highlightSide)
        highlight.frame.origin.y = rowY

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        iconLayers.forEach { $0.removeFromSuperlayer() }
        iconLayers = images.enumerated().map { index, image in
            let layer = CALayer()
            layer.bounds = CGRect(x: 0, y: 0, width: layout.iconSide, height: layout.iconSide)
            layer.position = CGPoint(x: layout.centreX(at: Double(index)), y: rowY + layout.highlightSide / 2)
            let bitmapSide = SwitcherRowLayout.fullIconSide * scale
            var proposed = CGRect(x: 0, y: 0, width: bitmapSide, height: bitmapSide)
            layer.contents = image.cgImage(forProposedRect: &proposed, context: nil, hints: nil)
            layer.contentsScale = scale
            layer.minificationFilter = .trilinear
            iconsHost.layer?.addSublayer(layer)
            return layer
        }
        CATransaction.commit()
        invalidateShadow()
    }

    /// Where the highlight sits, in icons from the first, and which icon is drawn larger. Stretch past an end is
    /// animated by `springHighlight`.
    func show(position: CGFloat, selected: Int, name selectedName: String, animatesSize: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        highlight.frame.origin.x = layout.centreX(at: Double(position)) - layout.highlightSide / 2
        CATransaction.commit()

        CATransaction.begin()
        CATransaction.setDisableActions(!animatesSize)
        CATransaction.setAnimationDuration(0.12)
        for (index, layer) in iconLayers.enumerated() {
            let scale = index == selected ? Self.selectedScale : 1
            layer.transform = CATransform3DMakeScale(scale, scale, 1)
        }
        CATransaction.commit()
        name.stringValue = selectedName
    }

    /// An additive spring from `offset` points past the highlight's resting place back to it; keyed, so each one
    /// replaces the one before.
    func springHighlight(from offset: CGFloat) {
        guard let layer = highlight.layer else { return }
        let spring = CASpringAnimation(keyPath: "position.x")
        spring.isAdditive = true
        spring.fromValue = offset
        spring.toValue = 0
        spring.mass = 1
        spring.stiffness = 420
        spring.damping = 22
        spring.duration = spring.settlingDuration
        layer.add(spring, forKey: "stretch")
    }
}
