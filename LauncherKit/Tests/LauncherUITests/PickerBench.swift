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
    let view: PickerButton

    /// The app each `choose` call named, and nil for each `chooseNone` call.
    var chosen: [String?] = []
    var chooseCalls = 0
    var noneCalls = 0
    private let hasNone: Bool
    private let unavailable: BundleID?
    var otherCalls = 0
    var otherCompletion: ((AppEntry?) -> Void)?
    var animation: PickAnimation? = .shipped
    private var current: RowApp

    static let names = ["Safari", "Mail", "Music", "Calendar", "Finder", "Notes"]

    init(
        showing name: String?, animation: PickAnimation? = .shipped, installed: [String] = PickerBench.names,
        unavailable: BundleID? = nil, hasNone: Bool = true
    ) {
        self.hasNone = hasNone
        self.unavailable = unavailable
        var entries: [String: AppEntry] = [:]
        for name in Set(Self.names + installed) {
            entries[name] = AppEntry(
                bundleID: BundleID(rawValue: "com.test.\(name.lowercased().replacingOccurrences(of: " ", with: "-"))"), name: name,
                url: URL(filePath: "/Applications/\(name).app"))
        }
        self.entries = entries
        self.installed = InstalledApps(recent: [], others: installed.map { entries[$0]! })
        buttonIcons = Dictionary(uniqueKeysWithValues: entries.values.map { ($0.url, Self.solidIcon()) })
        menuIcons = Dictionary(uniqueKeysWithValues: entries.values.map { ($0.url, Self.solidIcon()) })
        current = name.map { .present(entries[$0]!) } ?? .unassigned
        self.animation = animation
        let coordinator = AppPicker.Coordinator()
        self.coordinator = coordinator
        view = AppPicker(
            current: .unassigned, unavailable: nil, installedApps: .empty, cachedIcon: { _ in NSImage() },
            icon: { _ in NSImage() },
            choose: { _ in nil }, chooseNone: nil, chooseOther: { _ in }, pickAnimation: { nil }
        ).makeView(coordinator: coordinator)
        render(current)
    }

    /// A 16 pt icon with every pixel painted, so a drawn icon is never mistaken for a clear slot holder.
    static func solidIcon() -> NSImage {
        NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
            return true
        }
    }

    private func picker() -> AppPicker {
        AppPicker(
            current: current, unavailable: unavailable, installedApps: installed,
            cachedIcon: { [menuIcons] in menuIcons[$0]! }, icon: { [buttonIcons] in buttonIcons[$0]! },
            choose: { [unowned self] choice in
                chooseCalls += 1
                guard case .app(let entry) = choice else { return nil }
                chosen.append(entry.name)
                return entry
            },
            chooseNone: hasNone
                ? { [unowned self] in
                    noneCalls += 1
                    chosen.append(nil)
                } : nil,
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
                current: app, unavailable: picker.unavailable, installedApps: installed, cachedIcon: picker.cachedIcon,
                icon: picker.icon,
                choose: picker.choose, chooseNone: picker.chooseNone, chooseOther: picker.chooseOther,
                pickAnimation: picker.pickAnimation)
        }
        picker.update(view, coordinator: coordinator)
        layOut()
    }

    func layOut() {
        view.setFrameSize(view.intrinsicContentSize)
        view.layoutSubtreeIfNeeded()
    }

    /// Picks the menu item titled `title`, as a click on it does.
    func pick(_ title: String) {
        let menu = view.menu!
        coordinator.menuNeedsUpdate(menu)
        let item = menu.items.first { $0.title == title }!
        _ = item.target?.perform(item.action, with: item)
        layOut()
    }

    /// What the button draws: its display item, never one of the menu's.
    var displayItem: NSMenuItem { (view.cell as! NSPopUpButtonCell).menuItem! }

    func entry(_ name: String) -> AppEntry { entries[name]! }

    func icon(_ name: String) -> NSImage { buttonIcons[entries[name]!.url]! }

    var iconLayerContents: AnyObject? { view.iconLayer.contents as AnyObject? }

    /// Every layer the picker owns apart from the icon layer: none may ever animate.
    var otherLayersAreStill: Bool {
        [view.layer, view.iconLayer.superlayer].allSatisfy { ($0?.animationKeys() ?? []).isEmpty }
    }

    var iconLayerAnimationKeys: [String] { view.iconLayer.animationKeys() ?? [] }

    var noLayerAnimates: Bool { iconLayerAnimationKeys.isEmpty && otherLayersAreStill }

    func clearAnimations() { view.iconLayer.removeAllAnimations() }

    /// The icon layer shows `name`'s icon, unhidden, and plays the shipped pick animation from its start.
    func expectPlaysPickAnimation(of name: String, sourceLocation: SourceLocation = #_sourceLocation) {
        Self.expectPlaysPickAnimation(on: view, icon: icon(name), sourceLocation: sourceLocation)
    }

    /// `button`'s icon layer shows `icon`, unhidden, and plays the shipped pick animation from its start.
    static func expectPlaysPickAnimation(
        on button: PickerButton, icon: NSImage, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let layer = button.iconLayer
        let iconLayerAnimationKeys = layer.animationKeys() ?? []
        let otherLayersAreStill = [button.layer, layer.superlayer].allSatisfy { ($0?.animationKeys() ?? []).isEmpty }
        #expect(!layer.isHidden, sourceLocation: sourceLocation)
        #expect(layer.contents as AnyObject? === icon, sourceLocation: sourceLocation)
        #expect(layer.anchorPoint == CGPoint(x: 0.5, y: 0.5), sourceLocation: sourceLocation)
        #expect(layer.opacity == 1, sourceLocation: sourceLocation)
        #expect(CATransform3DIsIdentity(layer.transform), sourceLocation: sourceLocation)
        #expect(iconLayerAnimationKeys == [PickerButton.pickKey], sourceLocation: sourceLocation)
        let animation = layer.animation(forKey: PickerButton.pickKey) as? CAKeyframeAnimation
        #expect(animation?.keyPath == "transform", sourceLocation: sourceLocation)
        #expect(abs((animation?.duration ?? 0) - 0.26) < 1e-9, sourceLocation: sourceLocation)
        let frames = PickAnimation.shipped.keyframes(perSecond: 240)
        let transforms = animation?.values?.compactMap { ($0 as? NSValue)?.caTransform3DValue } ?? []
        #expect(transforms.map(\.m11) == frames.scales.map { CGFloat($0) }, sourceLocation: sourceLocation)
        let keyTimes = animation?.keyTimes?.map(\.doubleValue)
        #expect(keyTimes == frames.keyTimes, sourceLocation: sourceLocation)
        #expect(transforms.count == 64, sourceLocation: sourceLocation)
        #expect(keyTimes?.first == 0 && keyTimes?.last == 1, sourceLocation: sourceLocation)
        #expect(
            transforms.allSatisfy { $0.m11 == $0.m22 && $0.m33 == 1 && $0.m41 == 0 }, "uniform scales, no sideways move",
            sourceLocation: sourceLocation)

        // Where the icon's bottom edge sits, in points below its resting place: the icon view is flipped and the
        // layer's anchor its centre, so the edge sits at m42 + side / 2 × scale − side / 2.
        let half = PickerButton.iconSide / 2
        let bottoms = transforms.map { $0.m42 + half * $0.m11 - half }
        #expect(abs((transforms.first?.m11 ?? 0) - 0.55) < 1e-9, sourceLocation: sourceLocation)
        #expect(abs((bottoms.first ?? 0) - 9) < 1e-9, "starts 9 pt below its place", sourceLocation: sourceLocation)
        #expect(transforms.last.map(CATransform3DIsIdentity) == true, "rests in place", sourceLocation: sourceLocation)
        let peak = keyTimes?.indices.first { abs(keyTimes![$0] * PickAnimation.shipped.duration - 0.16) < 1e-9 }
        #expect(peak != nil, "a sample at 0.16 s", sourceLocation: sourceLocation)
        if let peak, peak < transforms.count {
            #expect(abs(transforms[peak].m11 - 1.08) < 1e-9, sourceLocation: sourceLocation)
            #expect(transforms.allSatisfy { $0.m11 <= transforms[peak].m11 + 1e-9 }, sourceLocation: sourceLocation)
            #expect(bottoms[peak] < 0, "jumps a little past its place", sourceLocation: sourceLocation)
            for i in 1...peak { #expect(bottoms[i] < bottoms[i - 1], "rises", sourceLocation: sourceLocation) }
        }
        #expect(otherLayersAreStill, sourceLocation: sourceLocation)
    }
}
