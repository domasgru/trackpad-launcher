import AppKit
import LauncherCore
import SwiftUI

/// A gesture row's app picker: the app's icon and name, then, 12 pt after, the chevron in a 16 pt badge, as wide as
/// they need up to 128 pt. A click anywhere on it opens the menu. It shows the row's app and checks it in the menu;
/// the menu ends in Other… and None. An app picked through Other… from outside the list, and a missing app, show in
/// the button without joining the menu.
///
/// The icon and name are the system's borderless pop-up button with its arrows turned off; the delegate builds the
/// items from the launcher's list each time the menu opens, from values already in memory: no disk, Spotlight or icon
/// drawing runs on the click path. Between openings the button holds only the item it shows, so the window builds no
/// menus when it opens.
///
/// The button shortens a long name itself, so the cut is always at the end of the name with an ellipsis.
///
/// The icon is drawn by a layer of the picker's own, over the button's image slot, which holds a clear image of the
/// icon's size: the button lays out and shortens the name exactly as if it drew the icon, and the pick animation
/// scales that layer alone, never the name or the chevron. Picking an app plays the pick animation on it.
struct AppPicker: NSViewRepresentable {
    let current: RowApp
    let installedApps: InstalledApps
    /// Never draws: the menu's icons.
    let cachedIcon: (URL) -> NSImage
    /// Draws a missing icon on the spot: the button's icon only.
    let icon: (URL) -> NSImage
    /// nil = None. Answers the app the row now shows present, which is what plays the pick animation.
    let choose: (AppChoice?) -> AppEntry?
    /// Hands the completion to the model's Other… path; the completion gets the app the row now shows present, or nil.
    let chooseOther: (@escaping (AppEntry?) -> Void) -> Void
    /// The pick animation to play for a pick now, or nil to swap the icon at once.
    let pickAnimation: () -> PickAnimation?

    static let maxWidth: CGFloat = 128
    /// What the pop-up button may take: the whole width less the gap and the chevron badge.
    static let buttonMaxWidth = maxWidth - PickerView.chevronSpace

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> PickerView { makeView(coordinator: context.coordinator) }

    func updateNSView(_ view: PickerView, context: Context) { update(view, coordinator: context.coordinator) }

    func makeView(coordinator: Coordinator) -> PickerView {
        let view = PickerView()
        let button = view.button
        button.menu?.autoenablesItems = false
        // The delegate checks the row's app itself: the selected item is always the first, see `menuNeedsUpdate`.
        (button.cell as? NSPopUpButtonCell)?.altersStateOfSelectedItem = false
        button.menu?.delegate = coordinator
        coordinator.pickerView = view
        return view
    }

    func update(_ view: PickerView, coordinator: Coordinator) {
        coordinator.current = current
        coordinator.installedApps = installedApps
        coordinator.cachedIcon = cachedIcon
        coordinator.icon = icon
        coordinator.choose = choose
        coordinator.chooseOther = chooseOther
        coordinator.pickAnimation = pickAnimation
        guard !coordinator.isMenuOpen else { return }
        coordinator.showCurrentOnly()
        view.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView view: PickerView, context: Context) -> CGSize? {
        view.intrinsicContentSize
    }

    @MainActor final class Coordinator: NSObject, NSMenuDelegate {
        weak var pickerView: PickerView?
        var button: NSPopUpButton? { pickerView?.button }
        var current = RowApp.unassigned
        var installedApps = InstalledApps.empty
        var cachedIcon: (URL) -> NSImage = { _ in NSImage() }
        var icon: (URL) -> NSImage = { _ in NSImage() }
        var choose: (AppChoice?) -> AppEntry? = { _ in nil }
        var chooseOther: (@escaping (AppEntry?) -> Void) -> Void = { _ in }
        var pickAnimation: () -> PickAnimation? = { nil }
        private(set) var isMenuOpen = false

        func showCurrentOnly() {
            guard let button, let pickerView else { return }
            button.removeAllItems()
            let presentIcon: NSImage?
            if case .present(let entry) = current { presentIcon = icon(entry.url) } else { presentIcon = nil }
            let item = closedItem(current, icon: presentIcon)
            button.menu?.addItem(item)
            button.selectItem(at: 0)
            shortenToFit(item, in: button)
            pickerView.showIcon(presentIcon)
            // A missing app's name takes the button's whole width, so "not found" is in the tooltip.
            if case .missing(let name) = current { button.toolTip = "\(name) not found" } else { button.toolTip = nil }
        }

        func menuWillOpen(_ menu: NSMenu) { isMenuOpen = true }

        /// Deferred so a chosen item's action still finds its item; the closed button goes back to holding only the
        /// row's app.
        func menuDidClose(_ menu: NSMenu) {
            isMenuOpen = false
            Task { @MainActor [weak self] in
                guard let self, !isMenuOpen else { return }
                showCurrentOnly()
            }
        }

        /// Runs each time the menu is about to open. A list that arrived while a menu was open is applied here. The
        /// row's app, matched by bundle identifier, is checked. The pop-up button opens its menu with the selected
        /// item over itself, so the first item is the selected one: the list opens at its top whatever the row holds.
        func menuNeedsUpdate(_ menu: NSMenu) {
            guard let button else { return }
            menu.removeAllItems()
            for pickerItem in installedApps.pickerMenu(checking: current) {
                switch pickerItem {
                case .app(let entry, let state):
                    let item = actionItem(title: entry.name, action: #selector(pick(_:)))
                    item.representedObject = entry
                    item.image = cachedIcon(entry.url)
                    item.state = state == .current ? .on : .off
                    menu.addItem(item)
                case .divider:
                    menu.addItem(.separator())
                case .other:
                    menu.addItem(actionItem(title: "Other…", action: #selector(pickOther)))
                case .unassigned:
                    menu.addItem(actionItem(title: "None", action: #selector(pick(_:))))
                }
            }
            button.selectItem(at: 0)
        }

        /// The closed button's only item; never in the open menu.
        private func closedItem(_ app: RowApp, icon: NSImage?) -> NSMenuItem {
            switch app {
            case .unassigned:
                return titledItem("Choose app…")
            case .present(let entry):
                let item = titledItem(entry.name)
                item.image = icon.map { Self.clearImage(sized: Self.spacedSize($0)) }
                return item
            case .missing(let name):
                let item = titledItem(name, color: .tertiaryLabelColor)
                item.image = NSImage(systemSymbolName: "questionmark.app.dashed", accessibilityDescription: "not found")
                    .map(Self.spaced)
                return item
            }
        }

        private func titledItem(_ title: String, color: NSColor = .labelColor) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.attributedTitle = NSAttributedString(
                string: title, attributes: [.foregroundColor: color, .font: Self.font])
            return item
        }

        private func actionItem(title: String, action: Selector) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            return item
        }

        /// An item without a represented app is None: it plays nothing. The button shows the pick at once rather than
        /// at the model's next update.
        @objc private func pick(_ sender: NSMenuItem) {
            let entry = sender.representedObject as? AppEntry
            let answer = choose(entry.map(AppChoice.app))
            if let answer {
                show(picked: answer)
            } else if entry == nil {
                current = .unassigned
                pickerView?.stopPickAnimation()
                showCurrentOnly()
            }
        }

        /// Other… is not an app: the button goes back to what it showed, and only an app the model accepts shows and
        /// plays. A cancelled chooser never calls back.
        @objc private func pickOther() {
            chooseOther { [weak self] answer in
                guard let answer else { return }
                self?.show(picked: answer)
            }
            showCurrentOnly()
        }

        /// The picked app in the button, with the pick animation unless the supplier has none (Reduce motion).
        private func show(picked entry: AppEntry) {
            current = .present(entry)
            showCurrentOnly()
            if let animation = pickAnimation() {
                pickerView?.play(animation)
            } else {
                pickerView?.stopPickAnimation()
            }
            pickerView?.invalidateIntrinsicContentSize()
        }

        /// The window's labels: 13 pt medium.
        private static let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        /// Clear room after the icon, on top of the pop-up button's own gap: 6 pt between icon and name in all.
        private static let iconTrailingSpace: CGFloat = 1

        private static func spacedSize(_ image: NSImage) -> NSSize {
            NSSize(width: image.size.width + iconTrailingSpace, height: image.size.height)
        }

        /// What holds the icon's slot in the button while the picker's icon layer draws the icon.
        private static func clearImage(sized size: NSSize) -> NSImage {
            NSImage(size: size, flipped: false) { _ in true }
        }

        /// `image` with `iconTrailingSpace` of clear room on its right. A template image stays one, so the symbol
        /// still takes the button's colour.
        private static func spaced(_ image: NSImage) -> NSImage {
            let size = spacedSize(image)
            let spaced = NSImage(size: size, flipped: false) { _ in
                image.draw(in: NSRect(origin: .zero, size: image.size))
                return true
            }
            spaced.isTemplate = image.isTemplate
            spaced.accessibilityDescription = image.accessibilityDescription
            return spaced
        }

        /// Cuts the closed item's name until the button fits `maxWidth`. Everything around the name (the icon, the
        /// gaps, the chevron) keeps its width, so the name gets what the button is over by taken off.
        private func shortenToFit(_ item: NSMenuItem, in button: NSPopUpButton) {
            let over = button.intrinsicContentSize.width - AppPicker.buttonMaxWidth
            guard over > 0, let attributes = item.attributedTitle?.attributes(at: 0, effectiveRange: nil) else { return }
            let name = item.title
            let fitted = Self.fitted(name, within: Self.textWidth(name) - over)
            item.title = fitted
            item.attributedTitle = NSAttributedString(string: fitted, attributes: attributes)
            button.synchronizeTitleAndSelectedItem()
        }

        private static func textWidth(_ text: String) -> CGFloat {
            (text as NSString).size(withAttributes: [.font: font]).width
        }

        /// `name`, cut at the end with an ellipsis until it fits `width`.
        private static func fitted(_ name: String, within width: CGFloat) -> String {
            guard textWidth(name) > width else { return name }
            var kept = name
            while !kept.isEmpty, textWidth(kept + "…") > width { kept.removeLast() }
            return kept.trimmingCharacters(in: .whitespaces) + "…"
        }
    }
}

/// The pop-up button without its arrows, then the chevron badge. Every click inside goes to the button, so the badge
/// opens the menu too. The present app's icon is drawn by `iconLayer`, over the button's image slot.
final class PickerView: NSView {
    /// 12 pt from the name to the badge, less the clear room the arrowless pop-up button keeps after its title
    /// (4 pt, measured on macOS 26).
    static let chevronGap: CGFloat = 12 - 4
    static let badgeSize: CGFloat = 16
    static let chevronSpace = chevronGap + badgeSize

    /// The icon's side.
    static let iconSide: CGFloat = 16
    /// The key the pick animation runs under, so a new one replaces a running one.
    static let pickKey = "pick"
    /// Samples a second of the pick animation, like the launch animation's.
    private static let keyframesPerSecond: Double = 240

    let button = NSPopUpButton(frame: .zero, pullsDown: false)
    let badge = ChevronBadge()
    /// The icon's own layer. Its implicit actions are off: the pick animation is the only animation it plays.
    let iconLayer = CALayer()

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        // The pick animation's peak is bigger than the icon's slot and draws past it.
        layer?.masksToBounds = false
        iconLayer.masksToBounds = false
        iconLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        iconLayer.isHidden = true
        iconLayer.actions = [
            "contents": NSNull(), "bounds": NSNull(), "position": NSNull(), "hidden": NSNull(),
            "transform": NSNull(), "opacity": NSNull(), "contentsScale": NSNull(),
        ]
        button.isBordered = false
        (button.cell as? NSPopUpButtonCell)?.arrowPosition = .noArrow
        for view in [button, badge] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.centerYAnchor.constraint(equalTo: centerYAnchor),
            button.trailingAnchor.constraint(equalTo: badge.leadingAnchor, constant: -Self.chevronGap),
            badge.trailingAnchor.constraint(equalTo: trailingAnchor),
            badge.centerYAnchor.constraint(equalTo: centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: Self.badgeSize),
            badge.heightAnchor.constraint(equalToConstant: Self.badgeSize),
        ])
        layer?.addSublayer(iconLayer)
        updateContentsScale()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        let natural = button.intrinsicContentSize
        return NSSize(
            width: min(natural.width, AppPicker.buttonMaxWidth) + Self.chevronSpace,
            height: max(natural.height, Self.badgeSize))
    }

    override func layout() {
        super.layout()
        placeIconLayer()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateContentsScale()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateContentsScale()
    }

    private func updateContentsScale() {
        iconLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }

    /// The leading square of the button cell's image slot, where the cell would draw the icon.
    private func placeIconLayer() {
        guard let cell = button.cell as? NSPopUpButtonCell else { return }
        let slot = convert(cell.imageRect(forBounds: button.bounds), from: button)
        iconLayer.bounds = CGRect(x: 0, y: 0, width: Self.iconSide, height: Self.iconSide)
        iconLayer.position = CGPoint(x: slot.minX + Self.iconSide / 2, y: slot.minY + Self.iconSide / 2)
    }

    /// The icon in its slot with nothing playing, or hidden for nil. A running pick animation is left alone.
    func showIcon(_ image: NSImage?) {
        iconLayer.contents = image
        iconLayer.isHidden = image == nil
        placeIconLayer()
        needsLayout = true
    }

    /// Plays `animation` on the icon alone from its start; a running one is replaced. The model transform stays
    /// identity, so when it ends the icon rests at full size with nothing to clean up.
    func play(_ animation: PickAnimation) {
        let frames = animation.keyframes(perSecond: Self.keyframesPerSecond)
        let grow = CAKeyframeAnimation(keyPath: "transform")
        grow.values = frames.scales.map { NSValue(caTransform3D: CATransform3DMakeScale($0, $0, 1)) }
        grow.keyTimes = frames.keyTimes.map { NSNumber(value: $0) }
        grow.duration = animation.duration
        grow.calculationMode = .linear
        iconLayer.add(grow, forKey: Self.pickKey)
    }

    func stopPickAnimation() { iconLayer.removeAnimation(forKey: Self.pickKey) }

    override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? button : nil }
}

/// `chevron.up.chevron.down`, 11 pt bold, centred in a 16 pt circle of the faint fill pop-up buttons use.
final class ChevronBadge: NSView {
    private let chevron = NSImageView()

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = PickerView.badgeSize / 2
        chevron.image = NSImage(systemSymbolName: "chevron.up.chevron.down", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 11, weight: .bold))
        chevron.contentTintColor = .labelColor
        chevron.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chevron)
        NSLayoutConstraint.activate([
            chevron.centerXAnchor.constraint(equalTo: centerXAnchor),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override var wantsUpdateLayer: Bool { true }

    /// Resolved here so the fill follows light and dark.
    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.tertiarySystemFill.cgColor
        }
    }
}
