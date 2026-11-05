import AppKit
import LauncherCore
import SwiftUI

/// A gesture row's app picker: System Settings' own pop-up button, its content as wide as it needs up to 128 pt. It shows the
/// row's app's icon and name and checks the app in the menu; the menu ends in Other… and None. An app picked through
/// Other… from outside the list, and a missing app, show in the button without joining the menu.
///
/// Everything the user sees and touches is the system's: the bezel that shows on hover, the chevrons, the font, the
/// click target, the menu and where it opens (the row's app over the button, checked). The picker changes three
/// things only:
/// - The menu is built from values already in memory, no disk, Spotlight or icon drawing: whenever the row's app or
///   the list changes, with the row's app selected, because AppKit places the menu from the selection before it
///   asks for the items; and again as it opens, for icons drawn since (about 0.3 ms for 60 apps).
/// - The button draws a display item of the picker's own rather than the menu's selected item, so it is always as wide
///   as the row's app needs, and a pick shows nothing until the picker shows it. The display item's image has clear
///   room after it: 6 pt between icon and name.
/// - The icon is drawn by a layer of the picker's own, over the display item's image slot, which holds a clear image
///   of the same size: the button lays out exactly as if it drew the icon, and the pick animation scales that layer
///   alone. Picking an app plays it.
///
/// The button shortens a long name itself, so the cut is always at the end of the name with an ellipsis.
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

    /// The widest the content may be, from the icon's or name's leading edge to the chevrons' trailing one.
    static let maxContentWidth: CGFloat = 128
    /// The button's frame around its content (measured on macOS 26): 12 pt before it, where the bezel shown on hover
    /// pads it, and 3.5 pt after the chevrons.
    static let contentInsets = (leading: CGFloat(12), trailing: CGFloat(3.5))
    /// The widest the button may be.
    static let maxWidth = maxContentWidth + contentInsets.leading + contentInsets.trailing

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> PickerButton { makeView(coordinator: context.coordinator) }

    func updateNSView(_ button: PickerButton, context: Context) { update(button, coordinator: context.coordinator) }

    func makeView(coordinator: Coordinator) -> PickerButton {
        let button = PickerButton()
        button.menu?.delegate = coordinator
        coordinator.button = button
        return button
    }

    func update(_ button: PickerButton, coordinator: Coordinator) {
        coordinator.current = current
        coordinator.installedApps = installedApps
        coordinator.cachedIcon = cachedIcon
        coordinator.icon = icon
        coordinator.choose = choose
        coordinator.chooseOther = chooseOther
        coordinator.pickAnimation = pickAnimation
        coordinator.showCurrent()
        coordinator.buildMenuIfChanged()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView button: PickerButton, context: Context) -> CGSize? {
        button.intrinsicContentSize
    }

    @MainActor final class Coordinator: NSObject, NSMenuDelegate {
        weak var button: PickerButton?
        var current = RowApp.unassigned
        var installedApps = InstalledApps.empty
        var cachedIcon: (URL) -> NSImage = { _ in NSImage() }
        var icon: (URL) -> NSImage = { _ in NSImage() }
        var choose: (AppChoice?) -> AppEntry? = { _ in nil }
        var chooseOther: (@escaping (AppEntry?) -> Void) -> Void = { _ in }
        var pickAnimation: () -> PickAnimation? = { nil }

        /// The row's app in the button. A running pick animation is left alone.
        func showCurrent() {
            guard let button else { return }
            let presentIcon: NSImage?
            if case .present(let entry) = current { presentIcon = icon(entry.url) } else { presentIcon = nil }
            button.show(displayItem(current), icon: presentIcon)
            // A missing app's name takes the button's whole width, so "not found" is in the tooltip.
            if case .missing(let name) = current { button.toolTip = "\(name) not found" } else { button.toolTip = nil }
        }

        /// The row's app and the list the menu was last built from.
        private var builtFrom: (app: RowApp, list: InstalledApps)?

        /// Builds the menu when the row's app or the list changed since it was last built.
        func buildMenuIfChanged() {
            guard let menu = button?.menu, builtFrom?.app != current || builtFrom?.list != installedApps else { return }
            build(menu)
        }

        /// Runs each time the menu is about to open, once AppKit has placed it: the same items again, with any icon
        /// drawn since the last build.
        func menuNeedsUpdate(_ menu: NSMenu) { build(menu) }

        /// The menu for the row's app and the list. The row's app, matched by bundle identifier, is checked and
        /// selected, so the menu opens with it over the button; with no row app in the menu, it opens at its top.
        private func build(_ menu: NSMenu) {
            guard let button else { return }
            builtFrom = (current, installedApps)
            menu.removeAllItems()
            var selected = 0
            for pickerItem in installedApps.pickerMenu(checking: current) {
                switch pickerItem {
                case .app(let entry, let state):
                    let item = actionItem(title: entry.name, action: #selector(pick(_:)))
                    item.representedObject = entry
                    item.image = cachedIcon(entry.url)
                    if state == .current {
                        item.state = .on
                        selected = menu.numberOfItems
                    }
                    menu.addItem(item)
                case .divider:
                    menu.addItem(.separator())
                case .other:
                    menu.addItem(actionItem(title: "Other…", action: #selector(pickOther)))
                case .unassigned:
                    menu.addItem(actionItem(title: "None", action: #selector(pick(_:))))
                }
            }
            button.selectItem(at: selected)
        }

        /// What the button draws for `app`; never in the menu.
        private func displayItem(_ app: RowApp) -> NSMenuItem {
            switch app {
            case .unassigned:
                return NSMenuItem(title: "Choose app…", action: nil, keyEquivalent: "")
            case .present(let entry):
                let item = NSMenuItem(title: entry.name, action: nil, keyEquivalent: "")
                item.image = PickerButton.clearIconSlot
                return item
            case .missing(let name):
                let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
                item.attributedTitle = NSAttributedString(
                    string: name, attributes: [.foregroundColor: NSColor.tertiaryLabelColor])
                item.image = NSImage(systemSymbolName: "questionmark.app.dashed", accessibilityDescription: "not found")
                    .map(PickerButton.spaced)
                return item
            }
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
                button?.stopPickAnimation()
                showCurrent()
                buildMenuIfChanged()
            }
        }

        /// Other… is not an app: the button keeps what it shows, and only an app the model accepts shows and plays. A
        /// cancelled chooser never calls back.
        @objc private func pickOther() {
            chooseOther { [weak self] answer in
                guard let answer else { return }
                self?.show(picked: answer)
            }
        }

        /// The picked app in the button, with the pick animation unless the supplier has none (Reduce motion).
        private func show(picked entry: AppEntry) {
            current = .present(entry)
            showCurrent()
            buildMenuIfChanged()
            if let animation = pickAnimation() {
                button?.play(animation)
            } else {
                button?.stopPickAnimation()
            }
        }
    }
}

/// The system's pop-up button in System Settings' style (`SettingsPopUpButton`), drawing a display item of the picker's own, with the present
/// app's icon drawn by `iconLayer` over the display item's image slot.
final class PickerButton: SettingsPopUpButton {
    /// The icon's side.
    static let iconSide: CGFloat = 16
    /// Clear room after the icon, on top of the button's own 2 pt: 6 pt between the icon and the name's text box
    /// (measured on macOS 26).
    static let iconTrailingSpace: CGFloat = 4
    /// The key the pick animation runs under, so a new one replaces a running one.
    static let pickKey = "pick"
    /// Samples a second of the pick animation, like the launch animation's.
    private static let keyframesPerSecond: Double = 240

    /// What holds the icon's slot in the display item while `iconLayer` draws the icon.
    static let clearIconSlot = NSImage(
        size: NSSize(width: iconSide + iconTrailingSpace, height: iconSide), flipped: false
    ) { _ in true }

    /// The icon's own layer. Its implicit actions are off: the pick animation is the only animation it plays.
    var iconLayer: CALayer { iconView.iconLayer }
    private let iconView = IconView()

    override init() {
        super.init()
        guard let cell = cell as? NSPopUpButtonCell else { preconditionFailure("NSPopUpButton without its cell") }
        cell.usesItemFromMenu = false
        // The delegate checks the row's app itself, so a missing app selects the first item without checking it.
        cell.altersStateOfSelectedItem = false
        menu?.autoenablesItems = false
        iconView.frame = bounds
        iconView.autoresizingMask = [.width, .height]
        addSubview(iconView)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    /// `item` drawn by the button, its name shortened to fit; `icon` drawn over its image slot, or no icon for nil. A
    /// running pick animation is left alone.
    func show(_ item: NSMenuItem, icon: NSImage?) {
        guard let cell = cell as? NSPopUpButtonCell else { return }
        cell.menuItem = item
        shortenToFit(item)
        iconLayer.contents = icon
        iconLayer.isHidden = icon == nil
        invalidateIntrinsicContentSize()
        needsLayout = true
        placeIconLayer()
    }

    override func layout() {
        super.layout()
        // Above whatever AppKit adds to draw the button, which it may add or re-add as the button changes.
        if subviews.last !== iconView { addSubview(iconView, positioned: .above, relativeTo: nil) }
        placeIconLayer()
    }

    /// The leading square of the display item's image slot, where the button would draw the icon.
    private func placeIconLayer() {
        guard let cell = cell as? NSPopUpButtonCell else { return }
        let slot = iconView.convert(cell.imageRect(forBounds: bounds), from: self)
        iconLayer.bounds = CGRect(x: 0, y: 0, width: Self.iconSide, height: Self.iconSide)
        iconLayer.position = CGPoint(x: slot.minX + Self.iconSide / 2, y: slot.midY)
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

    /// `image` with `iconTrailingSpace` of clear room on its right. A template image stays one, so the symbol still
    /// takes the button's colour.
    static func spaced(_ image: NSImage) -> NSImage {
        let spaced = NSImage(
            size: NSSize(width: image.size.width + iconTrailingSpace, height: image.size.height), flipped: false
        ) { _ in
            image.draw(in: NSRect(origin: .zero, size: image.size))
            return true
        }
        spaced.isTemplate = image.isTemplate
        spaced.accessibilityDescription = image.accessibilityDescription
        return spaced
    }

    /// Cuts the display item's name until the button fits `AppPicker.maxWidth`. Everything around the name (the
    /// icon, the gaps, the chevrons) keeps its width, so the name gets what the button is over by taken off.
    private func shortenToFit(_ item: NSMenuItem) {
        let over = intrinsicContentSize.width - AppPicker.maxWidth
        guard over > 0 else { return }
        let attributes = item.attributedTitle?.attributes(at: 0, effectiveRange: nil) ?? [:]
        let font = font ?? .systemFont(ofSize: NSFont.systemFontSize)
        let fitted = Self.fitted(item.title, within: Self.textWidth(item.title, font: font) - over, font: font)
        item.title = fitted
        if item.attributedTitle != nil { item.attributedTitle = NSAttributedString(string: fitted, attributes: attributes) }
        (cell as? NSPopUpButtonCell)?.menuItem = item
    }

    private static func textWidth(_ text: String, font: NSFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    /// `name`, cut at the end with an ellipsis until it fits `width`.
    private static func fitted(_ name: String, within width: CGFloat, font: NSFont) -> String {
        guard textWidth(name, font: font) > width else { return name }
        var kept = name
        while !kept.isEmpty, textWidth(kept + "…", font: font) > width { kept.removeLast() }
        return kept.trimmingCharacters(in: .whitespaces) + "…"
    }
}

/// Holds the icon layer above the button's own drawing. Never takes a click or the pointer, so the button keeps its
/// hover, its click target and its menu; never clips, so the pick animation's peak draws past the icon's slot.
private final class IconView: NSView {
    let iconLayer = CALayer()

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        clipsToBounds = false
        layer?.masksToBounds = false
        iconLayer.masksToBounds = false
        iconLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        iconLayer.isHidden = true
        iconLayer.actions = [
            "contents": NSNull(), "bounds": NSNull(), "position": NSNull(), "hidden": NSNull(),
            "transform": NSNull(), "opacity": NSNull(), "contentsScale": NSNull(),
        ]
        layer?.addSublayer(iconLayer)
        updateContentsScale()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

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
}
