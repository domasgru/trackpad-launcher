import AppKit
import LauncherCore
import QuartzCore

/// The app switcher's window: an overlay panel holding one container layer per app, its icon last and any window stack's
/// copies behind it, and the glass highlight under them; `SwitcherPresenter` decides everything shown.
final class SwitcherPanel: OverlayPanel {
    private static let cornerRadius: CGFloat = 34

    private let content: NSView
    private let highlight = NSGlassEffectView()
    private let iconsHost = NSView()
    /// One per slot, never clipping. A sublayer draws above its parent's contents, so each container holds the copies
    /// first, farthest first, and the icon last.
    private(set) var slotLayers: [CALayer] = []
    private var scale: CGFloat = 2
    private var layout = SwitcherRowLayout(iconCount: 0, displayWidth: 0)

    init() {
        let content = NSView()
        self.content = content
        super.init(cornerRadius: Self.cornerRadius, content: content)

        content.wantsLayer = true
        iconsHost.wantsLayer = true
        highlight.style = .clear
        highlight.cornerRadius = 24
        highlight.wantsLayer = true
        content.addSubview(highlight)
        content.addSubview(iconsHost)
    }

    /// Replaces the slot containers with one per image, left to right, centred by `layout`, and centres the panel on
    /// `screen`. Each holds only its icon, sized by `layout`.
    func layoutRow(_ images: [NSImage], layout: SwitcherRowLayout, on screen: NSRect, scale: CGFloat) {
        self.layout = layout
        self.scale = scale
        let panelSize = layout.panelSize
        let size = CGSize(width: panelSize.width, height: panelSize.height)
        setFrame(
            NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2, width: size.width, height: size.height),
            display: false)
        content.frame = NSRect(origin: .zero, size: size)
        iconsHost.frame = content.bounds
        highlight.frame.size = CGSize(width: layout.highlightSide, height: layout.highlightSide)
        highlight.frame.origin.y = layout.centreY - layout.highlightSide / 2

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        slotLayers.forEach { $0.removeFromSuperlayer() }
        slotLayers = images.enumerated().map { index, image in
            let container = CALayer()
            container.bounds = CGRect(x: 0, y: 0, width: layout.iconSide, height: layout.iconSide)
            container.position = CGPoint(x: layout.centreX(at: Double(index)), y: layout.centreY)
            let bitmapSide = SwitcherRowLayout.fullIconSide * scale
            var proposed = CGRect(x: 0, y: 0, width: bitmapSide, height: bitmapSide)
            let icon = Self.imageLayer(side: layout.iconSide, centredAt: 0, in: layout.iconSide, scale: scale)
            icon.contents = image.cgImage(forProposedRect: &proposed, context: nil, hints: nil)
            container.addSublayer(icon)
            iconsHost.layer?.addSublayer(container)
            return container
        }
        CATransaction.commit()
        invalidateShadow()
    }

    /// Where the highlight sits, in icons from the first, and which icon is drawn larger. Stretch past an end is
    /// animated by `springHighlight`.
    func show(position: CGFloat, selected: Int, animatesSize: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        highlight.frame.origin.x = layout.centreX(at: Double(position)) - layout.highlightSide / 2
        CATransaction.commit()

        CATransaction.begin()
        CATransaction.setDisableActions(!animatesSize)
        CATransaction.setAnimationDuration(0.12)
        for (index, layer) in slotLayers.enumerated() {
            let scale = index == selected ? CGFloat(SwitcherRowLayout.selectedIconScale) : 1
            layer.transform = CATransform3DMakeScale(scale, scale, 1)
        }
        CATransaction.commit()
    }

    /// Inserts `copies` behind the slot's icon, sharing its image, at rest: nearest copy just behind the icon.
    func addStack(at slot: Int, copies: [WindowStackLayout.Copy]) {
        guard slotLayers.indices.contains(slot), let icon = slotLayers[slot].sublayers?.last else { return }
        let container = slotLayers[slot]
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, copy) in copies.enumerated().reversed() {
            let layer = Self.imageLayer(side: copy.side, centredAt: copy.rise, in: layout.iconSide, scale: scale)
            layer.contents = icon.contents
            container.insertSublayer(layer, at: UInt32(copies.count - 1 - index))
        }
        CATransaction.commit()
    }

    /// A layer `side` points square, centred `rise` above the middle of a container `container` points square.
    private static func imageLayer(side: Double, centredAt rise: Double, in container: Double, scale: CGFloat) -> CALayer {
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        layer.position = CGPoint(x: container / 2, y: container / 2 + rise)
        layer.contentsScale = scale
        layer.minificationFilter = .trilinear
        return layer
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
