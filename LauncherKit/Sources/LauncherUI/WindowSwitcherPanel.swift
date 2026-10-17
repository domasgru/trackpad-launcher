import AppKit
import LauncherCore
import QuartzCore

/// The window switcher's look and motion, in one value whose defaults are the shipped look, as `LaunchTuning` is for
/// the launch animation: refining it later touches no policy. Sizes that decide whether the column fits live in
/// `WindowColumnLayout`; the dismissal is the overlay's shared fade.
struct WindowSwitcherLook: Sendable {
    /// The highlight's radius is the panel's less its padding, so the two corners are concentric.
    var panelRadius = 22.0, highlightRadius = 14.0
    var previewRadius = 6.0, previewFade = 0.08, minimisedAlpha = 0.55, badgeSize = 10.0
    var titleWeight = NSFont.Weight.medium
    var appearDuration = 0.1, appearScale = 0.96
    var springStiffness = 420.0, springDamping = 22.0

    static let shipped = WindowSwitcherLook()
}

/// The window switcher: one `.regular` glass panel, ten pre-created rows, one `.clear` glass highlight inside the panel
/// glass's content. `WindowSwitcherPresenter` decides what shows.
final class WindowSwitcherPanel: OverlayPanel {
    private let look: WindowSwitcherLook
    private let content = NSView()
    private let highlight = NSGlassEffectView()
    private let rowViews: [WindowRowView]
    private var layout = WindowColumnLayout(rowCount: 0, displayHeight: 0)
    private var shownRows = 0

    init(look: WindowSwitcherLook = .shipped) {
        self.look = look
        rowViews = (0..<GestureRules.windowSwitcherMaxRows).map { _ in WindowRowView(look: look) }
        super.init(cornerRadius: look.panelRadius, content: content)
        content.wantsLayer = true
        highlight.style = .clear
        highlight.wantsLayer = true
        content.addSubview(highlight)
        rowViews.forEach(content.addSubview)
    }

    private var titleFont: NSFont { .systemFont(ofSize: WindowColumnLayout.titleSize, weight: look.titleWeight) }

    /// Sizes the panel to `layout` with its top-left corner at `topLeft` and fills one row per entry of `rows`, each
    /// showing `icon` in its preview slot.
    func lay(out rows: [WindowSwitcher.Row], icon: NSImage, layout: WindowColumnLayout, topLeft: NSPoint) {
        self.layout = layout
        shownRows = min(rows.count, rowViews.count)
        let size = CGSize(width: layout.panelSize.width, height: layout.panelSize.height)
        setFrame(NSRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height), display: false)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        content.frame = NSRect(origin: .zero, size: size)
        highlight.cornerRadius = look.highlightRadius * layout.scale
        highlight.frame = rowFrame(at: 0)
        for (index, view) in rowViews.enumerated() {
            // Every slot back to the icon, so nothing taken for one window swipe shows in the next.
            view.dropPreview()
            guard index < shownRows else {
                view.isHidden = true
                continue
            }
            view.isHidden = false
            view.frame = rowFrame(at: Double(index))
            view.fill(rows[index], icon: icon, layout: layout, font: titleFont)
        }
        CATransaction.commit()
        invalidateShadow()
    }

    /// Empties the slots of `rows`, whose pictures are being taken: a picture then appears in an empty slot rather than
    /// replacing the icon a moment after it showed, which reads as a flicker.
    func awaitPreviews(rows: [Int]) {
        for row in rows where row < shownRows { rowViews[row].awaitPreview() }
    }

    /// Fades the picture into the row's slot, sized by `layout.previewSize(aspect:)`; at once unless `animated`.
    func setPreview(_ picture: CGImage, row: Int, animated: Bool) {
        guard row < shownRows, picture.height > 0 else { return }
        let size = layout.previewSize(aspect: Double(picture.width) / Double(picture.height))
        rowViews[row].showPreview(
            picture, size: CGSize(width: size.width, height: size.height), duration: animated ? look.previewFade : 0)
    }

    /// The capture is over: every slot still empty fades back to the icon; at once unless `animated`.
    func showIconsWithoutPreview(animated: Bool) {
        for view in rowViews.prefix(shownRows) { view.showIconIfEmpty(duration: animated ? look.previewFade : 0) }
    }

    /// The panel is out: every picture goes.
    override func emptied() {
        rowViews.forEach { $0.dropPreview() }
    }

    /// The highlight sits `position` rows from the top, with actions disabled; the selected title takes `labelColor`.
    func show(position: Double, selected: Int) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        highlight.frame = rowFrame(at: position)
        CATransaction.commit()
        for (index, view) in rowViews.prefix(shownRows).enumerated() { view.isSelected = index == selected }
    }

    /// An additive spring from `offset` points below the highlight's resting place (above when negative) back to it;
    /// keyed, so each one replaces the one before.
    func springHighlight(fromY offset: Double) {
        guard let layer = highlight.layer else { return }
        let spring = CASpringAnimation(keyPath: "position.y")
        spring.isAdditive = true
        // The content is not flipped: down is negative.
        spring.fromValue = -offset
        spring.toValue = 0
        spring.mass = 1
        spring.stiffness = look.springStiffness
        spring.damping = look.springDamping
        spring.duration = spring.settlingDuration
        layer.add(spring, forKey: "stretch")
    }

    /// A row's frame in the panel's content, `position` rows from the top.
    private func rowFrame(at position: Double) -> NSRect {
        NSRect(
            x: layout.padding, y: layout.panelSize.height - layout.rowTop(at: position) - layout.rowHeight,
            width: layout.panelSize.width - 2 * layout.padding, height: layout.rowHeight)
    }
}

/// One row: the preview slot holding the app icon or the window's picture, the title on one line, and for a minimised
/// window the badge.
private final class WindowRowView: NSView {
    private let look: WindowSwitcherLook
    private let slot = NSView()
    private let iconView = NSImageView()
    /// The only holder of a picture: its `contents`.
    private let preview = CALayer()
    private let title = NSTextField(labelWithString: "")
    private let badge = NSTextField(labelWithString: Copy.minimisedBadge)
    private let badgeBackground = NSView()

    var isSelected = false {
        didSet { title.textColor = isSelected ? .labelColor : .secondaryLabelColor }
    }

    init(look: WindowSwitcherLook) {
        self.look = look
        super.init(frame: .zero)
        wantsLayer = true
        slot.wantsLayer = true
        slot.layer?.masksToBounds = true
        preview.masksToBounds = true
        preview.contentsGravity = .resizeAspectFill
        preview.opacity = 0
        iconView.imageScaling = .scaleProportionallyUpOrDown
        title.lineBreakMode = .byTruncatingTail
        title.maximumNumberOfLines = 1
        title.textColor = .secondaryLabelColor
        badge.textColor = .secondaryLabelColor
        badge.alignment = .center
        badgeBackground.wantsLayer = true
        badgeBackground.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        addSubview(slot)
        slot.addSubview(iconView)
        slot.layer?.addSublayer(preview)
        addSubview(title)
        addSubview(badgeBackground)
        badgeBackground.addSubview(badge)
    }

    required init?(coder: NSCoder) { nil }

    /// An empty slot, waiting for its picture.
    func awaitPreview() {
        iconView.alphaValue = 0
    }

    /// `picture` centred in the slot at `size` in place of the icon, fading in over `duration`.
    func showPreview(_ picture: CGImage, size: CGSize, duration: CFTimeInterval) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        preview.contents = picture
        preview.cornerRadius = slot.layer?.cornerRadius ?? 0
        preview.frame = CGRect(
            x: (slot.bounds.width - size.width) / 2, y: (slot.bounds.height - size.height) / 2,
            width: size.width, height: size.height)
        CATransaction.commit()
        iconView.alphaValue = 0
        CATransaction.begin()
        CATransaction.setDisableActions(duration == 0)
        CATransaction.setAnimationDuration(duration)
        preview.opacity = 1
        CATransaction.commit()
    }

    /// The icon fades back in over `duration` when the slot holds no picture.
    func showIconIfEmpty(duration: CFTimeInterval) {
        guard preview.contents == nil, iconView.alphaValue == 0 else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            iconView.animator().alphaValue = 1
        }
    }

    /// Back to the icon, holding no picture.
    func dropPreview() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        preview.removeAllAnimations()
        preview.contents = nil
        preview.opacity = 0
        CATransaction.commit()
        iconView.layer?.removeAllAnimations()
        iconView.alphaValue = 1
    }

    func fill(_ row: WindowSwitcher.Row, icon: NSImage, layout: WindowColumnLayout, font: NSFont) {
        let scale = layout.scale
        let isMinimised = if case .minimised = row { true } else { false }
        alphaValue = isMinimised ? look.minimisedAlpha : 1

        slot.frame = NSRect(x: layout.inset, y: layout.inset, width: layout.slot.width, height: layout.slot.height)
        slot.layer?.cornerRadius = look.previewRadius * scale
        iconView.image = icon
        iconView.frame = NSRect(
            x: (layout.slot.width - layout.icon) / 2, y: (layout.slot.height - layout.icon) / 2,
            width: layout.icon, height: layout.icon)

        title.font = NSFont(descriptor: font.fontDescriptor, size: layout.fontSize) ?? font
        title.stringValue = row.title
        let lineHeight = (title.font.map { $0.ascender - $0.descender + $0.leading } ?? layout.fontSize).rounded(.up)
        let badgeFont = NSFont.systemFont(ofSize: look.badgeSize * scale, weight: .medium)
        let badgeHeight = (badgeFont.ascender - badgeFont.descender).rounded(.up) + 2 * scale
        let gap = 4 * scale
        let stack = isMinimised ? lineHeight + gap + badgeHeight : lineHeight
        let titleY = (bounds.height - stack) / 2 + (isMinimised ? badgeHeight + gap : 0)
        title.frame = NSRect(x: layout.titleLeading, y: titleY, width: layout.titleWidth, height: lineHeight)

        badgeBackground.isHidden = !isMinimised
        badge.font = badgeFont
        let badgeWidth = (badge.intrinsicContentSize.width + 12 * scale).rounded(.up)
        badgeBackground.frame = NSRect(
            x: layout.titleLeading, y: (bounds.height - stack) / 2, width: badgeWidth, height: badgeHeight)
        badgeBackground.layer?.cornerRadius = badgeHeight / 2
        badge.frame = NSRect(x: 0, y: (badgeHeight - badge.intrinsicContentSize.height) / 2, width: badgeWidth,
                             height: badge.intrinsicContentSize.height)
    }
}
