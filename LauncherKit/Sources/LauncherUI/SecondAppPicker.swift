import AppKit
import LauncherCore
import SwiftUI

/// The second slot of a gesture row: the plus button, or the minus button and the second app's picker. One NSView
/// holding three controls, driven by an `AppPicker.Coordinator` for the picker and its menu.
/// - The plus button pops up a menu built by the coordinator's own builder, nothing checked, the first app disabled.
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
    /// How the plus button's menu opens. A real pop-up runs a modal tracking loop, so a bench replaces it.
    var popUp: @MainActor (NSMenu, NSView) -> Void = { menu, button in
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.isFlipped ? button.bounds.maxY : 0), in: button)
    }

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
        view.popUp = popUp
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
    static let buttonSide: CGFloat = 16
    /// From the minus button to the picker's frame, whose own 12 pt of leading inset make the design's 12 pt gap.
    static let gapBeforePicker = 12 - AppPicker.contentInsets.leading

    let plusButton: NSButton
    let minusButton: NSButton
    let picker = PickerButton()
    var remove: () -> Void = {}
    var popUp: @MainActor (NSMenu, NSView) -> Void = { _, _ in }
    private(set) var mode = Mode.add
    /// The slot the last update showed, so an update that changes nothing leaves the layout alone.
    var shownSlot: SecondSlot?
    private let coordinator: AppPicker.Coordinator

    init(coordinator: AppPicker.Coordinator) {
        self.coordinator = coordinator
        plusButton = Self.button(symbol: "plus.circle.fill", label: Copy.addSecondApp)
        minusButton = Self.button(symbol: "minus.circle.fill", label: Copy.removeSecondApp)
        super.init(frame: .zero)
        coordinator.attach(to: picker)
        plusButton.target = self
        plusButton.action = #selector(plusPressed)
        minusButton.target = self
        minusButton.action = #selector(minusPressed)
        for subview in [plusButton, minusButton, picker] { addSubview(subview) }
        apply()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    private static func button(symbol: String, label: String) -> NSButton {
        let configuration = NSImage.SymbolConfiguration(pointSize: buttonSide, weight: .regular)
            .applying(.init(paletteColors: [.secondaryLabelColor, .quaternaryLabelColor]))
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)?
            .withSymbolConfiguration(configuration)
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: buttonSide, height: buttonSide))
        button.image = image
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyUpOrDown
        button.isBordered = false
        button.toolTip = label
        button.setAccessibilityLabel(label)
        return button
    }

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

    @objc private func plusPressed() { popUp(coordinator.standaloneMenu(), plusButton) }

    @objc private func minusPressed() {
        remove()
        show(.add)
    }
}
