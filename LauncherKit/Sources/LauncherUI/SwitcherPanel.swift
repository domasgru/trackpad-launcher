import AppKit
import LauncherCore
import QuartzCore

extension NSRect {
    init(_ rect: LiquidRect) {
        self.init(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
    }
}

/// The app switcher's window: an overlay panel holding one Liquid Glass shape (a band, a bead per icon and a swell)
/// with the icon layers above it. It renders `LiquidFrame`s and decides nothing; every number comes from the layout or
/// the frame.
final class SwitcherPanel: OverlayPanel {
    /// Internal, not private, so tests can reach the twelve glass views. They are created with the panel and never
    /// added, removed or hidden.
    let container = NSGlassEffectContainerView()
    let band = NSGlassEffectView()
    let beads = (0..<GestureRules.switcherMaxApps).map { _ in NSGlassEffectView() }
    let swellView = NSGlassEffectView()

    private let root: NSView
    private let iconsHost = NSView()
    private let glassHost = NSView()
    private var iconLayers: [CALayer] = []
    private var layout = SwitcherRowLayout(iconCount: 0, displayWidth: 0)
    /// AppKit's render-server mirror of the glass views, matched while the panel was hidden; nil when it did not match.
    private var mirror: GlassMirror?
    /// The mirror for this swipe, set by `checkMirror()` and cleared by `lay(out:)`; nil: the rests alone show.
    private var liveMirror: GlassMirror?

    init() {
        let root = NSView()
        self.root = root
        super.init(content: root)
        root.wantsLayer = true
        iconsHost.wantsLayer = true
        container.contentView = glassHost
        for glass in [band] + beads + [swellView] {
            glass.style = .regular
            glassHost.addSubview(glass)
        }
        root.addSubview(container)
        root.addSubview(iconsHost)
        prewarm()
    }

    /// AppKit builds the mirror only once a window with glass on it is first on screen, and it takes a flush to appear.
    /// So the panel is shown once, at zero opacity and laid out at full width, which also pays the first window's cost
    /// ahead of any swipe. The ten-icon template keeps all twelve frames distinct, so each view matches one element.
    private func prewarm() {
        lay(
            out: [], layout: SwitcherRowLayout(iconCount: GestureRules.switcherMaxApps, displayWidth: 0),
            on: NSScreen.main?.frame ?? .zero, backingScale: 1)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        root.layer?.opacity = 0
        CATransaction.commit()
        orderFrontRegardless()
        CATransaction.flush()
        mirror = GlassMirror.matched(
            in: container, views: [(nil, band)] + beads.enumerated().map { (.bead($0), $1) } + [(.swell, swellView)])
        orderOut(nil)
    }

    /// Once per swipe, after `present`: whether the mirror still matches, for the whole swipe. The flush makes every
    /// element hold its view's frame; liveness is never read inside `apply`'s transaction.
    func checkMirror() -> Bool {
        CATransaction.flush()
        liveMirror = mirror?.isLive == true ? mirror : nil
        return liveMirror != nil
    }

    /// Once per swipe: centres the window on `screen`, sizes every glass view from `layout`, and replaces the icon
    /// layers with one per image. Laying out twice is harmless.
    func lay(out images: [NSImage], layout: SwitcherRowLayout, on screen: NSRect, backingScale: CGFloat) {
        self.layout = layout
        mirror?.removeLiquidAnimations()
        liveMirror = nil
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let panelSize = layout.panelSize
        let size = CGSize(width: panelSize.width, height: panelSize.height)
        setFrame(
            NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2, width: size.width, height: size.height),
            display: false)
        let bounds = NSRect(origin: .zero, size: size)
        root.frame = bounds
        container.frame = bounds
        glassHost.frame = bounds
        iconsHost.frame = bounds

        let radii = layout.radii
        place(band, at: layout.band, radius: radii.band)
        for (index, bead) in beads.enumerated() {
            place(bead, at: layout.bead(at: index), radius: index < layout.iconCount ? radii.bead : radii.band)
        }
        place(swellView, at: layout.swell(at: 0), radius: radii.swell)
        container.spacing = layout.spacing

        iconLayers.forEach { $0.removeFromSuperlayer() }
        iconLayers = images.enumerated().map { index, image in
            let layer = CALayer()
            layer.bounds = CGRect(x: 0, y: 0, width: layout.iconSide, height: layout.iconSide)
            layer.position = CGPoint(x: layout.centreX(at: Double(index)), y: layout.centreY)
            let bitmapSide = SwitcherRowLayout.fullIconSide * backingScale
            var proposed = CGRect(x: 0, y: 0, width: bitmapSide, height: bitmapSide)
            layer.contents = image.cgImage(forProposedRect: &proposed, context: nil, hints: nil)
            layer.contentsScale = backingScale
            layer.minificationFilter = .trilinear
            iconsHost.layer?.addSublayer(layer)
            return layer
        }
        CATransaction.commit()
        invalidateShadow()
    }

    private func place(_ glass: NSGlassEffectView, at rect: LiquidRect, radius: Double) {
        glass.frame = NSRect(rect)
        glass.cornerRadius = radius
    }

    /// Applies what one `follow` changed: the swell's new frame, which icon is drawn larger, and the tracks. The frame
    /// and the tracks reach the render server in one commit, so the tracks' offsets are against the new frame. With no
    /// live mirror the frames alone show the resting shape.
    func apply(_ frame: LiquidFrame) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let swell = frame.swell { swellView.frame = NSRect(swell) }
        if let icon = frame.icon { grow(icon) }
        if let liveMirror {
            for track in frame.tracks {
                let layer = liveMirror.layer(for: track.channel.element)
                layer.add(
                    LiquidKeyframes.animation(track, beginTime: layer.convertTime(track.begin.seconds, from: nil)),
                    forKey: LiquidKeyframes.key(track.channel))
            }
        }
        CATransaction.commit()
        if !frame.isEmpty { invalidateShadow() }
    }

    /// Duration 0 grows at once; otherwise linearly over it.
    private func grow(_ change: IconChange) {
        CATransaction.begin()
        CATransaction.setDisableActions(change.duration <= 0)
        CATransaction.setAnimationDuration(change.duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))
        for (index, layer) in iconLayers.enumerated() {
            let scale = index == change.selected ? CGFloat(SwitcherRowLayout.selectedIconScale) : 1
            layer.transform = CATransform3DMakeScale(scale, scale, 1)
        }
        CATransaction.commit()
    }

    /// The panel is out: no track outlives the swipe and the swell goes back to the first icon, ready for the next. The
    /// mirror is checked directly, not through `liveMirror`, which stays nil all swipe under Reduce Motion: only a
    /// mirror that is gone is rebuilt, so a failed check costs that one swipe its motion, not every later one.
    override func emptied() {
        CATransaction.flush()
        let live = mirror?.isLive == true
        mirror?.removeLiquidAnimations()
        liveMirror = nil
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        swellView.frame = NSRect(layout.swell(at: 0))
        CATransaction.commit()
        if !live { prewarm() }
    }
}
