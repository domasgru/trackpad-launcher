import AppKit
import LauncherCore
import SwiftUI

/// The app picker: an `NSPopUpButton` whose delegate rebuilds the items from the launcher's list every time the
/// menu opens. That is only building items from values already in memory: no disk, Spotlight or icon drawing runs
/// on the click path. Between openings the menu holds only the row's current app, which is what the button shows.
struct AppPicker: NSViewRepresentable {
    let app: RowApp
    let installedApps: InstalledApps
    let cachedIcon: (URL) -> NSImage
    let icon: (URL) -> NSImage
    let choose: (AppChoice) -> Void
    let chooseOther: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.isBordered = false
        button.font = .systemFont(ofSize: 13)
        button.menu?.autoenablesItems = false
        button.menu?.delegate = context.coordinator
        context.coordinator.button = button
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        let coordinator = context.coordinator
        coordinator.app = app
        coordinator.installedApps = installedApps
        coordinator.cachedIcon = cachedIcon
        coordinator.icon = icon
        coordinator.choose = choose
        coordinator.chooseOther = chooseOther
        guard !coordinator.isMenuOpen else { return }
        coordinator.showCurrentOnly()
    }

    @MainActor final class Coordinator: NSObject, NSMenuDelegate {
        weak var button: NSPopUpButton?
        var app: RowApp = .unassigned
        var installedApps = InstalledApps.empty
        var cachedIcon: (URL) -> NSImage = { _ in NSImage() }
        var icon: (URL) -> NSImage = { _ in NSImage() }
        var choose: (AppChoice) -> Void = { _ in }
        var chooseOther: () -> Void = {}
        private(set) var isMenuOpen = false

        func showCurrentOnly() {
            guard let button else { return }
            button.removeAllItems()
            button.menu?.addItem(currentItem())
            button.selectItem(at: 0)
        }

        func menuWillOpen(_ menu: NSMenu) { isMenuOpen = true }

        /// Deferred so a chosen item's action still finds its item; the closed button goes back to holding
        /// only the row's current app.
        func menuDidClose(_ menu: NSMenu) {
            isMenuOpen = false
            Task { @MainActor [weak self] in
                guard let self, !isMenuOpen else { return }
                showCurrentOnly()
            }
        }

        /// Runs each time the menu is about to open. A list that arrived while a menu was open is applied here.
        func menuNeedsUpdate(_ menu: NSMenu) {
            guard let button else { return }
            menu.removeAllItems()
            var selected: NSMenuItem?
            for pickerItem in installedApps.pickerMenu(checking: app) {
                switch pickerItem {
                case .app(let entry, let checked):
                    let item = appItem(entry, icon: cachedIcon(entry.url))
                    menu.addItem(item)
                    if checked { selected = item }
                case .divider:
                    menu.addItem(.separator())
                case .other:
                    menu.addItem(actionItem(title: "Other…", action: #selector(pickOther)))
                case .unassigned:
                    let none = actionItem(title: "None", action: #selector(pick(_:)))
                    none.representedObject = AppChoice.unassigned
                    menu.addItem(none)
                }
            }
            button.select(selected)
        }

        private func currentItem() -> NSMenuItem {
            switch app {
            case .unassigned:
                return placeholder(title: "Choose app…", symbol: nil)
            case .present(let entry):
                return appItem(entry, icon: icon(entry.url))
            case .missing(let name):
                return placeholder(title: "\(name)  not found", symbol: "questionmark.app.dashed")
            }
        }

        private func placeholder(title: String, symbol: String?) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.attributedTitle = NSAttributedString(
                string: title,
                attributes: [
                    .foregroundColor: symbol == nil ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor,
                    .font: NSFont.systemFont(ofSize: 13),
                ])
            if let symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
            return item
        }

        private func appItem(_ entry: AppEntry, icon: NSImage) -> NSMenuItem {
            let item = NSMenuItem(title: entry.name, action: #selector(pick(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = AppChoice.app(entry)
            item.image = icon
            return item
        }

        private func actionItem(title: String, action: Selector) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            return item
        }

        @objc private func pick(_ sender: NSMenuItem) {
            guard let choice = sender.representedObject as? AppChoice else { return }
            choose(choice)
        }

        /// Choosing an item selects it in the button; Other… is not an app, so show the row's own app again.
        @objc private func pickOther() {
            chooseOther()
            showCurrentOnly()
        }
    }
}
