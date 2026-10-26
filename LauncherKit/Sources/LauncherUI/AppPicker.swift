import AppKit
import LauncherCore
import SwiftUI

/// A gesture row's app picker: the system pop-up button, 132 pt wide. It shows the row's app and checks it in the
/// menu; the menu ends in Other… and None. An app picked through Other… from outside the list, and a missing app, show
/// in the button without joining the menu.
///
/// The delegate builds the items from the launcher's list each time the menu opens, from values already in memory: no
/// disk, Spotlight or icon drawing runs on the click path. Between openings the button holds only the item it shows,
/// so the window builds no menus when it opens.
///
/// The button shortens a long name itself. Left to it, the pop-up button first narrows its left margin, by up to 7 pt,
/// and only then truncates, so a long name would start further left than a short one.
struct AppPicker: NSViewRepresentable {
    let current: RowApp
    let installedApps: InstalledApps
    /// Never draws: the menu's icons.
    let cachedIcon: (URL) -> NSImage
    /// Draws a missing icon on the spot: the button's icon only.
    let icon: (URL) -> NSImage
    /// nil = None.
    let choose: (AppChoice?) -> Void
    let chooseOther: () -> Void

    private static let width: CGFloat = 132

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.menu?.autoenablesItems = false
        button.menu?.delegate = context.coordinator
        context.coordinator.button = button
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        let coordinator = context.coordinator
        coordinator.current = current
        coordinator.installedApps = installedApps
        coordinator.cachedIcon = cachedIcon
        coordinator.icon = icon
        coordinator.choose = choose
        coordinator.chooseOther = chooseOther
        guard !coordinator.isMenuOpen else { return }
        coordinator.showCurrentOnly()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView button: NSPopUpButton, context: Context) -> CGSize? {
        CGSize(width: Self.width, height: button.intrinsicContentSize.height)
    }

    @MainActor final class Coordinator: NSObject, NSMenuDelegate {
        weak var button: NSPopUpButton?
        var current = RowApp.unassigned
        var installedApps = InstalledApps.empty
        var cachedIcon: (URL) -> NSImage = { _ in NSImage() }
        var icon: (URL) -> NSImage = { _ in NSImage() }
        var choose: (AppChoice?) -> Void = { _ in }
        var chooseOther: () -> Void = {}
        private(set) var isMenuOpen = false

        func showCurrentOnly() {
            guard let button else { return }
            button.removeAllItems()
            button.menu?.addItem(closedItem(current))
            button.selectItem(at: 0)
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
        /// pop-up button checks the selected item: the row's app, matched by bundle identifier.
        func menuNeedsUpdate(_ menu: NSMenu) {
            guard let button else { return }
            menu.removeAllItems()
            var selected: NSMenuItem?
            for pickerItem in installedApps.pickerMenu(checking: current) {
                switch pickerItem {
                case .app(let entry, let state):
                    let item = actionItem(title: entry.name, action: #selector(pick(_:)))
                    item.representedObject = entry
                    item.image = cachedIcon(entry.url)
                    if state == .current { selected = item }
                    menu.addItem(item)
                case .divider:
                    menu.addItem(.separator())
                case .other:
                    menu.addItem(actionItem(title: "Other…", action: #selector(pickOther)))
                case .unassigned:
                    menu.addItem(actionItem(title: "None", action: #selector(pick(_:))))
                }
            }
            button.select(selected)
        }

        /// The closed button's only item; never in the open menu.
        private func closedItem(_ app: RowApp) -> NSMenuItem {
            switch app {
            case .unassigned:
                return titledItem("Choose app…", color: .secondaryLabelColor)
            case .present(let entry):
                let item = titledItem(Self.fitted(entry.name, within: Self.nameWidth))
                item.image = Self.spaced(icon(entry.url))
                return item
            case .missing(let name):
                let item = titledItem(Self.fitted(name, within: Self.nameWidth), color: .tertiaryLabelColor)
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

        /// An item without a represented app is None. The button shows the pick at once rather than at the model's
        /// next update.
        @objc private func pick(_ sender: NSMenuItem) {
            let entry = sender.representedObject as? AppEntry
            current = entry.map(RowApp.present) ?? .unassigned
            showCurrentOnly()
            choose(entry.map(AppChoice.app))
        }

        /// Other… is not an app: the button goes back to what it showed.
        @objc private func pickOther() {
            chooseOther()
            showCurrentOnly()
        }

        private static let font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular))
        /// The pop-up button starts the title 2 pt after the image; the design has 4 pt between icon and name.
        private static let iconTrailingSpace: CGFloat = 2

        /// `image` with `iconTrailingSpace` of clear room on its right. A template image stays one, so the symbol
        /// still takes the button's colour.
        private static func spaced(_ image: NSImage) -> NSImage {
            let size = NSSize(width: image.size.width + iconTrailingSpace, height: image.size.height)
            let spaced = NSImage(size: size, flipped: false) { _ in
                image.draw(in: NSRect(origin: .zero, size: image.size))
                return true
            }
            spaced.isTemplate = image.isTemplate
            spaced.accessibilityDescription = image.accessibilityDescription
            return spaced
        }

        /// What the pop-up button keeps around a name beside a 16 pt icon at its full left margin: the margins, the
        /// icon with its trailing space and the arrows. Measured on macOS 26.
        private static let chrome: CGFloat = 66 + iconTrailingSpace
        private static let nameWidth = AppPicker.width - chrome

        /// `name`, cut at the end with an ellipsis until it fits `width`.
        private static func fitted(_ name: String, within width: CGFloat) -> String {
            func textWidth(_ text: String) -> CGFloat { (text as NSString).size(withAttributes: [.font: font]).width }
            guard textWidth(name) > width else { return name }
            var kept = name
            while !kept.isEmpty, textWidth(kept + "…") > width { kept.removeLast() }
            return kept.trimmingCharacters(in: .whitespaces) + "…"
        }
    }
}
