import AppKit
@testable import LauncherCore
import Testing
@testable import LauncherUI

/// An `AppPicker` driven the way SwiftUI drives it: the same make and update functions, a coordinator the test holds,
/// and picks sent through the real menu the coordinator builds.
final class PickerBench {
    let entries: [String: AppEntry]
    let installed: InstalledApps
    let buttonIcons: [URL: NSImage]
    let menuIcons: [URL: NSImage]
    let coordinator: AppPicker.Coordinator
    let view: PickerView

    /// The app each `choose` call named; nil for None.
    var chosen: [String?] = []
    var otherCalls = 0
    var otherCompletion: ((AppEntry?) -> Void)?
    var animation: PickAnimation? = .shipped
    private var current: RowApp

    static let names = ["Safari", "Mail", "Music", "Calendar", "Finder", "Notes"]

    init(showing name: String?, animation: PickAnimation? = .shipped, installed: [String] = PickerBench.names) {
        var entries: [String: AppEntry] = [:]
        for name in Self.names {
            entries[name] = AppEntry(
                bundleID: BundleID(rawValue: "com.test.\(name.lowercased())"), name: name,
                url: URL(filePath: "/Applications/\(name).app"))
        }
        self.entries = entries
        self.installed = InstalledApps(recent: [], others: installed.map { entries[$0]! })
        buttonIcons = Dictionary(uniqueKeysWithValues: entries.values.map { ($0.url, NSImage(size: NSSize(width: 16, height: 16))) })
        menuIcons = Dictionary(uniqueKeysWithValues: entries.values.map { ($0.url, NSImage(size: NSSize(width: 16, height: 16))) })
        current = name.map { .present(entries[$0]!) } ?? .unassigned
        self.animation = animation
        let coordinator = AppPicker.Coordinator()
        self.coordinator = coordinator
        view = AppPicker(
            current: .unassigned, installedApps: .empty, cachedIcon: { _ in NSImage() }, icon: { _ in NSImage() },
            choose: { _ in nil }, chooseOther: { _ in }, pickAnimation: { nil }
        ).makeView(coordinator: coordinator)
        render(current)
    }

    private func picker() -> AppPicker {
        AppPicker(
            current: current, installedApps: installed,
            cachedIcon: { [menuIcons] in menuIcons[$0]! }, icon: { [buttonIcons] in buttonIcons[$0]! },
            choose: { [unowned self] choice in
                switch choice {
                case .app(let entry):
                    chosen.append(entry.name)
                    return entry
                default:
                    chosen.append(nil)
                    return nil
                }
            },
            chooseOther: { [unowned self] completion in
                otherCalls += 1
                otherCompletion = completion
            },
            pickAnimation: { [unowned self] in animation })
    }

    func render(_ app: RowApp, installed: InstalledApps? = nil) {
        current = app
        var picker = picker()
        if let installed {
            picker = AppPicker(
                current: app, installedApps: installed, cachedIcon: picker.cachedIcon, icon: picker.icon,
                choose: picker.choose, chooseOther: picker.chooseOther, pickAnimation: picker.pickAnimation)
        }
        picker.update(view, coordinator: coordinator)
        layOut()
    }

    func layOut() {
        view.frame = NSRect(origin: .zero, size: view.intrinsicContentSize)
        view.layoutSubtreeIfNeeded()
    }

    /// Picks the menu item titled `title`, as a click on it does.
    func pick(_ title: String) {
        let menu = view.button.menu!
        coordinator.menuNeedsUpdate(menu)
        let item = menu.items.first { $0.title == title }!
        _ = item.target?.perform(item.action, with: item)
        layOut()
    }

    var closedItem: NSMenuItem { view.button.menu!.items[0] }

    func entry(_ name: String) -> AppEntry { entries[name]! }

    func icon(_ name: String) -> NSImage { buttonIcons[entries[name]!.url]! }

    var iconLayerContents: AnyObject? { view.iconLayer.contents as AnyObject? }

    /// Every layer the picker owns apart from the icon layer: none may ever animate.
    var otherLayersAreStill: Bool {
        [view.button.layer, view.badge.layer, view.layer].allSatisfy { ($0?.animationKeys() ?? []).isEmpty }
    }

    var iconLayerAnimationKeys: [String] { view.iconLayer.animationKeys() ?? [] }

    var noLayerAnimates: Bool { iconLayerAnimationKeys.isEmpty && otherLayersAreStill }

    func clearAnimations() { view.iconLayer.removeAllAnimations() }

    /// The icon layer shows `name`'s icon, unhidden, and plays the shipped pick animation from its start.
    func expectPlaysPickAnimation(of name: String, sourceLocation: SourceLocation = #_sourceLocation) {
        let layer = view.iconLayer
        #expect(!layer.isHidden, sourceLocation: sourceLocation)
        #expect(layer.contents as AnyObject? === icon(name), sourceLocation: sourceLocation)
        #expect(layer.anchorPoint == CGPoint(x: 0.5, y: 0.5), sourceLocation: sourceLocation)
        #expect(layer.opacity == 1, sourceLocation: sourceLocation)
        #expect(CATransform3DIsIdentity(layer.transform), sourceLocation: sourceLocation)
        #expect(iconLayerAnimationKeys == [PickerView.pickKey], sourceLocation: sourceLocation)
        let animation = layer.animation(forKey: PickerView.pickKey) as? CAKeyframeAnimation
        #expect(animation?.keyPath == "transform", sourceLocation: sourceLocation)
        #expect(animation?.duration == 0.35, sourceLocation: sourceLocation)
        let frames = PickAnimation.shipped.keyframes(perSecond: 240)
        let scales = animation?.values?.compactMap { ($0 as? NSValue)?.caTransform3DValue.m11 }
        #expect(scales == frames.scales.map { CGFloat($0) }, sourceLocation: sourceLocation)
        let keyTimes = animation?.keyTimes?.map(\.doubleValue)
        #expect(keyTimes == frames.keyTimes, sourceLocation: sourceLocation)
        #expect(otherLayersAreStill, sourceLocation: sourceLocation)
    }
}
