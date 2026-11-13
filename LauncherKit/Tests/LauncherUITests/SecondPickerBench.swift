import AppKit
@testable import LauncherCore
import Testing
@testable import LauncherUI

/// A `SecondAppPicker` driven the way SwiftUI drives it: the same make and update functions, a coordinator the test
/// holds, and picks sent through the real menus. A menu is read as it is about to open, without its modal tracking.
final class SecondPickerBench {
    let entries: [String: AppEntry]
    let installed: InstalledApps
    let buttonIcons: [URL: NSImage]
    let menuIcons: [URL: NSImage]
    let coordinator = AppPicker.Coordinator()
    private(set) lazy var view = picker(slot).makeView(coordinator: coordinator)

    var chosen: [String] = []
    var otherCalls = 0
    var otherCompletion: ((AppEntry?) -> Void)?
    var removed = 0
    var animation: PickAnimation? = .shipped
    private var slot: SecondSlot
    private let unavailable: BundleID?

    init(slot: SecondSlot, unavailable: BundleID? = nil, longName: String? = nil) {
        var entries: [String: AppEntry] = [:]
        for name in Set(PickerBench.names + (longName.map { [$0] } ?? [])) {
            entries[name] = AppEntry(
                bundleID: BundleID(rawValue: "com.test.\(name.lowercased())"), name: name,
                url: URL(filePath: "/Applications/\(name).app"))
        }
        self.entries = entries
        installed = InstalledApps(recent: [], others: PickerBench.names.map { entries[$0]! })
        buttonIcons = Dictionary(uniqueKeysWithValues: entries.values.map { ($0.url, PickerBench.solidIcon()) })
        menuIcons = Dictionary(uniqueKeysWithValues: entries.values.map { ($0.url, PickerBench.solidIcon()) })
        self.slot = slot
        self.unavailable = unavailable
        render(slot)
    }

    private func picker(_ slot: SecondSlot) -> SecondAppPicker {
        SecondAppPicker(
            slot: slot, unavailable: unavailable, installedApps: installed,
            cachedIcon: { [menuIcons] in menuIcons[$0]! }, icon: { [buttonIcons] in buttonIcons[$0]! },
            choose: { [unowned self] choice in
                guard case .app(let entry) = choice else { return nil }
                chosen.append(entry.name)
                return entry
            },
            chooseOther: { [unowned self] completion in
                otherCalls += 1
                otherCompletion = completion
            },
            remove: { [unowned self] in removed += 1 },
            pickAnimation: { [unowned self] in animation })
    }

    func render(_ slot: SecondSlot) {
        self.slot = slot
        picker(slot).update(view, coordinator: coordinator)
        layOut()
    }

    func layOut() {
        view.setFrameSize(view.intrinsicContentSize)
        view.layoutSubtreeIfNeeded()
    }

    /// The plus button's menu as it opens: AppKit has placed it from the selection, then asks for the items.
    func plusMenu() throws -> NSMenu {
        let menu = try #require(view.plusButton.menu)
        coordinator.menuNeedsUpdate(menu)
        return menu
    }

    func pressMinus() {
        view.minusButton.performClick(nil)
        layOut()
    }

    /// Picks the item titled `title` in `menu`, as a click on it does.
    func pick(_ title: String, from menu: NSMenu) throws {
        let item = try #require(menu.items.first { $0.title == title })
        _ = item.target?.perform(item.action, with: item)
        layOut()
    }

    /// Picks from the picker's own menu.
    func pickFromPicker(_ title: String) throws {
        let menu = try #require(view.picker.menu)
        coordinator.menuNeedsUpdate(menu)
        try pick(title, from: menu)
    }

    var pickerButton: PickerButton { view.picker }
    var displayItem: NSMenuItem { (view.picker.cell as! NSPopUpButtonCell).menuItem! }
    func entry(_ name: String) -> AppEntry { entries[name]! }
    func icon(_ name: String) -> NSImage { buttonIcons[entries[name]!.url]! }
    var iconLayerAnimationKeys: [String] { view.picker.iconLayer.animationKeys() ?? [] }
    var noLayerAnimates: Bool {
        iconLayerAnimationKeys.isEmpty
            && [view.picker.layer, view.picker.iconLayer.superlayer].allSatisfy { ($0?.animationKeys() ?? []).isEmpty }
    }
    func clearAnimations() { view.picker.iconLayer.removeAllAnimations() }

    /// What the slot shows: the plus button alone, or the minus button and the picker.
    var showsPlus: Bool { !view.plusButton.isHidden && view.minusButton.isHidden && view.picker.isHidden }
    var showsMinusAndPicker: Bool { view.plusButton.isHidden && !view.minusButton.isHidden && !view.picker.isHidden }
}
