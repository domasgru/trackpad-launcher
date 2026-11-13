import AppKit
import LauncherCore
import SwiftUI

/// The second slot of a gesture row: the plus button, or the minus button and the second app's picker. One NSView
/// holding three controls, driven by an `AppPicker.Coordinator` for the picker, the plus button and their menus.
/// - The plus button is a pop-up button of its own, its menu filled by the same coordinator: it opens, looks and picks
///   exactly as the picker does, with the app icons, its top item over the button, nothing checked, the first app
///   disabled.
/// - An accepted pick, from the plus button's menu or the picker's, shows the minus button and the picker at once, and
///   the picker's icon plays the pick animation. Renders never play it.
/// - None from either menu is inert, as closing the menu is.
/// - The minus button removes the second app and shows the plus button at once.
struct SecondAppPicker: NSViewRepresentable {
    let slot: SecondSlot
    /// The first app: shown disabled in both menus.
    let unavailable: BundleID?
    let installedApps: InstalledApps
    /// Never draws: the menus' icons.
    let cachedIcon: (URL) -> NSImage
    /// Draws a missing icon on the spot: the picker button's icon only.
    let icon: (URL) -> NSImage
    let choose: (AppChoice) -> AppEntry?
    let chooseOther: (@escaping (AppEntry?) -> Void) -> Void
    let remove: () -> Void
    let pickAnimation: () -> PickAnimation?

    func makeCoordinator() -> AppPicker.Coordinator { AppPicker.Coordinator() }

    func makeNSView(context: Context) -> SecondSlotView { makeView(coordinator: context.coordinator) }

    func updateNSView(_ view: SecondSlotView, context: Context) { update(view, coordinator: context.coordinator) }

    func makeView(coordinator: AppPicker.Coordinator) -> SecondSlotView {
        let view = SecondSlotView(coordinator: coordinator)
        coordinator.willShowPick = { [unowned view] in view.show(.app) }
        return view
    }

    func update(_ view: SecondSlotView, coordinator: AppPicker.Coordinator) {
        view.remove = remove
        let shown: RowApp
        switch slot {
        case .add:
            view.show(.add)
            shown = .unassigned
        case .app(let held):
            view.show(.app)
            switch held {
            case .present(let entry): shown = .present(entry)
            case .missing(let name, _): shown = .missing(name: name)
            }
        }
        AppPicker(
            current: shown, unavailable: unavailable, installedApps: installedApps, cachedIcon: cachedIcon,
            icon: icon, choose: choose, chooseNone: nil, chooseOther: chooseOther, pickAnimation: pickAnimation
        ).update(view.picker, coordinator: coordinator)
        if view.shownSlot != slot {
            view.shownSlot = slot
            view.needsLayout = true
            view.invalidateIntrinsicContentSize()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView view: SecondSlotView, context: Context) -> CGSize? {
        view.intrinsicContentSize
    }
}

final class SecondSlotView: NSView {
    enum Mode { case add, app }

    /// The plus and minus buttons' side.
    static let buttonSide = CircleSymbol.side
    /// From the minus button to the picker's frame, whose own 12 pt of leading inset make the design's 12 pt gap.
    static let gapBeforePicker = 12 - AppPicker.contentInsets.leading

    let plusButton = AddAppButton()
    let minusButton: NSButton
    let picker = PickerButton()
    var remove: () -> Void = {}
    private(set) var mode = Mode.add
    /// The slot the last update showed, so an update that changes nothing leaves the layout alone.
    var shownSlot: SecondSlot?

    init(coordinator: AppPicker.Coordinator) {
        minusButton = NSButton(frame: NSRect(x: 0, y: 0, width: Self.buttonSide, height: Self.buttonSide))
        super.init(frame: .zero)
        coordinator.attach(to: picker)
        coordinator.attachAdd(plusButton)
        minusButton.image = CircleSymbol.image("minus.circle.fill", label: Copy.removeSecondApp)
        minusButton.imagePosition = .imageOnly
        minusButton.imageScaling = .scaleNone
        minusButton.isBordered = false
        minusButton.toolTip = Copy.removeSecondApp
        minusButton.setAccessibilityLabel(Copy.removeSecondApp)
        minusButton.target = self
        minusButton.action = #selector(minusPressed)
        for subview in [plusButton, minusButton, picker] { addSubview(subview) }
        apply()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    /// Switches what shows; the picker's pick animation stops when it hides.
    func show(_ mode: Mode) {
        guard mode != self.mode else { return }
        self.mode = mode
        apply()
    }

    private func apply() {
        plusButton.isHidden = mode != .add
        minusButton.isHidden = mode != .app
        picker.isHidden = mode != .app
        if mode == .add { picker.stopPickAnimation() }
        invalidateIntrinsicContentSize()
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    /// The line's height: the picker's, which the plus button and the minus button are centred on.
    private var lineHeight: CGFloat { max(Self.buttonSide, picker.intrinsicContentSize.height) }

    override var intrinsicContentSize: NSSize {
        switch mode {
        case .add: NSSize(width: Self.buttonSide, height: lineHeight)
        case .app:
            NSSize(
                width: Self.buttonSide + Self.gapBeforePicker + picker.intrinsicContentSize.width, height: lineHeight)
        }
    }

    override func layout() {
        super.layout()
        let height = bounds.height
        let buttonY = ((height - Self.buttonSide) / 2).rounded()
        let side = Self.buttonSide
        plusButton.frame = NSRect(x: 0, y: buttonY, width: side, height: side)
        minusButton.frame = NSRect(x: 0, y: buttonY, width: side, height: side)
        let size = picker.intrinsicContentSize
        picker.frame = NSRect(
            x: side + Self.gapBeforePicker, y: ((height - size.height) / 2).rounded(), width: size.width,
            height: size.height)
    }

    @objc private func minusPressed() {
        remove()
        show(.add)
    }
}

/// The plus button: a borderless pop-up button that draws only the plus symbol, no bezel and no chevrons. Being the
/// system's pop-up button, its menu draws, places and tracks as the picker's does; its coordinator fills the menu.
final class AddAppButton: NSPopUpButton {
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: CircleSymbol.side, height: CircleSymbol.side), pullsDown: false)
        guard let cell = cell as? NSPopUpButtonCell else { preconditionFailure("NSPopUpButton without its cell") }
        cell.usesItemFromMenu = false
        // Nothing is ever checked: the second slot holds no app while the plus shows.
        cell.altersStateOfSelectedItem = false
        cell.arrowPosition = .noArrow
        cell.imagePosition = .imageOnly
        cell.imageScaling = .scaleNone
        isBordered = false
        menu?.autoenablesItems = false
        let display = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        display.image = CircleSymbol.image("plus.circle.fill", label: Copy.addSecondApp)
        cell.menuItem = display
        toolTip = Copy.addSecondApp
        setAccessibilityLabel(Copy.addSecondApp)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override class var cellClass: AnyClass? {
        get { Cell.self }
        set {}
    }

    override var intrinsicContentSize: NSSize { NSSize(width: CircleSymbol.side, height: CircleSymbol.side) }

    /// Draws the display item's image alone, unscaled and centred in the button, as a plain image button does. A pop-up
    /// cell lays its item's image out as a menu item, after a leading inset and off the button's centre, which would
    /// draw the circle off its frame. The button has no title, arrow or border to draw.
    private final class Cell: NSPopUpButtonCell {
        override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
            guard let image = menuItem?.image else { return }
            let size = image.size
            image.draw(
                in: NSRect(
                    x: cellFrame.midX - size.width / 2, y: cellFrame.midY - size.height / 2, width: size.width,
                    height: size.height),
                from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
    }
}

/// The plus and minus buttons' symbols, drawn as the picker's chevron badge is: a 20 pt circle in the badge's fill,
/// its sign in the chevrons' colour and about their weight.
enum CircleSymbol {
    /// The circle's diameter, and the buttons' side: the chevron badge's 20 pt as the system draws it.
    static let side: CGFloat = 20
    /// The light weight's sign is the closest to the chevrons' strokes: measured at 2 px per point, the chevrons'
    /// stroke is 3.2 px, light's 2.7 and regular's 3.4, and regular's long arms read bolder still.
    static let weight = NSFont.Weight.light
    /// At light weight and medium scale, 20.5 pt draws the circle exactly `side` across, inside a 25 pt image with
    /// 2.5 pt of clear margin on each side (measured on macOS 26).
    static let pointSize: CGFloat = 20.5

    /// `name` at `pointSize` and `weight`. A button shows it unscaled and centred in its 20 pt frame, so the circle
    /// fills the frame. Palette colours are the system's own, so both appearances follow.
    static func image(_ name: String, label: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight, scale: .medium)
            .applying(.init(paletteColors: [.labelColor, .secondarySystemFill]))
        return NSImage(systemSymbolName: name, accessibilityDescription: label)?.withSymbolConfiguration(configuration)
    }
}
