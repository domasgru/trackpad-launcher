import AppKit
import LauncherCore
import SwiftUI

/// The app picker: an `NSPopUpButton` whose delegate rebuilds the items from `installedApps()` every time the
/// menu opens, so the list is never older than the click that opened it. Between openings the menu holds only
/// the row's current app, which is what the button shows.
struct AppPicker: NSViewRepresentable {
    let app: RowApp
    let installedApps: () -> [AppEntry]
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
        coordinator.choose = choose
        coordinator.chooseOther = chooseOther
        guard !coordinator.isMenuOpen else { return }
        coordinator.showCurrentOnly()
    }

    @MainActor final class Coordinator: NSObject, NSMenuDelegate {
        weak var button: NSPopUpButton?
        var app: RowApp = .unassigned
        var installedApps: () -> [AppEntry] = { [] }
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

        /// Runs each time the menu is about to open: the one place the installed apps are enumerated.
        /// The list is installed apps, then Other…, then None; the row's own app is checked when installed.
        func menuNeedsUpdate(_ menu: NSMenu) {
            guard let button else { return }
            menu.removeAllItems()
            var selected: NSMenuItem?
            for entry in installedApps() {
                let item = appItem(entry)
                menu.addItem(item)
                if case .present(let current) = app, current.bundleID == entry.bundleID { selected = item }
            }
            menu.addItem(.separator())
            menu.addItem(actionItem(title: "Other…", action: #selector(pickOther)))
            let none = actionItem(title: "None", action: #selector(pick(_:)))
            none.representedObject = AppChoice.unassigned
            menu.addItem(none)
            button.select(selected)
        }

        private func currentItem() -> NSMenuItem {
            switch app {
            case .unassigned:
                return placeholder(title: "Choose app…", symbol: nil)
            case .present(let entry):
                return appItem(entry)
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

        private func appItem(_ entry: AppEntry) -> NSMenuItem {
            let item = NSMenuItem(title: entry.name, action: #selector(pick(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = AppChoice.app(entry)
            if let icon = NSWorkspace.shared.icon(forFile: entry.url.path).copy() as? NSImage {
                icon.size = NSSize(width: 16, height: 16)
                item.image = icon
            }
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
