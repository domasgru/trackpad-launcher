import AppKit
import LauncherCore
import SwiftUI

/// An `NSPopUpButton` whose delegate rebuilds the items from the launcher's list every time the menu opens. That is
/// only building items from values already in memory: no disk, Spotlight or icon drawing runs on the click path.
/// Between openings the menu holds only what the button shows. One coordinator serves both forms.
struct AppMenuButton: NSViewRepresentable {
    enum Form {
        /// A gesture row's picker: shows the row's app and checks it in the menu; the menu ends in None.
        case popUp(current: RowApp)
        /// The switcher's Add app…: shows the title; listed apps are checked and disabled; no None.
        case pullDown(title: String, listed: Set<BundleID>)
    }

    let form: Form
    let installedApps: InstalledApps
    let cachedIcon: (URL) -> NSImage
    let icon: (URL) -> NSImage
    /// nil = None.
    let choose: (AppChoice?) -> Void
    let chooseOther: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: form.pullsDown)
        switch form {
        case .popUp:
            button.isBordered = false
        case .pullDown:
            button.bezelStyle = .rounded
            button.controlSize = .large
        }
        button.font = .systemFont(ofSize: 13)
        button.menu?.autoenablesItems = false
        button.menu?.delegate = context.coordinator
        context.coordinator.button = button
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        let coordinator = context.coordinator
        coordinator.form = form
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
        var form = Form.popUp(current: .unassigned)
        var installedApps = InstalledApps.empty
        var cachedIcon: (URL) -> NSImage = { _ in NSImage() }
        var icon: (URL) -> NSImage = { _ in NSImage() }
        var choose: (AppChoice?) -> Void = { _ in }
        var chooseOther: () -> Void = {}
        private(set) var isMenuOpen = false

        func showCurrentOnly() {
            guard let button else { return }
            button.removeAllItems()
            button.menu?.addItem(shownItem())
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
            let pickerItems: [PickerItem]
            switch form {
            case .popUp(let current):
                pickerItems = installedApps.pickerMenu(checking: current)
            case .pullDown(let title, let listed):
                menu.addItem(NSMenuItem(title: title, action: nil, keyEquivalent: ""))
                pickerItems = installedApps.addMenu(listing: listed)
            }
            for pickerItem in pickerItems {
                switch pickerItem {
                case .app(let entry, let state):
                    let item = appItem(entry, icon: cachedIcon(entry.url))
                    switch state {
                    case .plain: break
                    case .current: selected = item
                    case .listed:
                        item.state = .on
                        item.isEnabled = false
                    }
                    menu.addItem(item)
                case .divider:
                    menu.addItem(.separator())
                case .other:
                    menu.addItem(actionItem(title: "Other…", action: #selector(pickOther)))
                case .unassigned:
                    let none = actionItem(title: "None", action: #selector(pick(_:)))
                    menu.addItem(none)
                }
            }
            button.select(selected)
        }

        private func shownItem() -> NSMenuItem {
            switch form {
            case .popUp(let current): currentItem(current)
            case .pullDown(let title, _): NSMenuItem(title: title, action: nil, keyEquivalent: "")
            }
        }

        private func currentItem(_ app: RowApp) -> NSMenuItem {
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

        /// An item without a represented app is None.
        @objc private func pick(_ sender: NSMenuItem) {
            choose(sender.representedObject as? AppChoice)
        }

        /// Choosing an item selects it in the button; Other… is not an app, so show what the button showed before.
        @objc private func pickOther() {
            chooseOther()
            showCurrentOnly()
        }
    }
}

private extension AppMenuButton.Form {
    var pullsDown: Bool {
        if case .pullDown = self { true } else { false }
    }
}
