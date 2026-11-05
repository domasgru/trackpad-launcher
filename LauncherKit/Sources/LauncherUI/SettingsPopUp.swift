import AppKit
import SwiftUI

/// The system's pop-up button drawn as in System Settings: chevrons in a round badge and the bezel only on hover.
/// SwiftUI's menu picker and a plain `NSPopUpButton` draw the standard bordered look, the bezel always on, outside a
/// SwiftUI grouped Form; the settings window is not one.
class SettingsPopUpButton: NSPopUpButton {
    /// AppKit's semantic context for a grouped form, which SwiftUI's grouped Form sets: the pop-up then draws as in
    /// System Settings. AppKit has no public way to set it outside a SwiftUI Form; without the private setter the
    /// button keeps the standard bordered look and works the same.
    private static let formSemanticContext = 8

    init() {
        super.init(frame: .zero, pullsDown: false)
        let setter = NSSelectorFromString("_setSemanticContext:")
        guard responds(to: setter) else { return }
        typealias Setter = @convention(c) (AnyObject, Selector, Int) -> Void
        unsafeBitCast(method(for: setter), to: Setter.self)(self, setter, Self.formSemanticContext)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
}

/// A settings row's pop-up of a few fixed choices, in System Settings' style: one item per option, the selection
/// checked. Picking an option sends it to `select`; the button shows `selection` from then on, as the model answers.
struct SettingsPopUp<Option: Hashable>: NSViewRepresentable {
    let options: [Option]
    let title: (Option) -> String
    let selection: Option
    let select: (Option) -> Void
    let accessibilityLabel: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SettingsPopUpButton { makeView(coordinator: context.coordinator) }

    func updateNSView(_ button: SettingsPopUpButton, context: Context) {
        update(button, coordinator: context.coordinator)
    }

    func makeView(coordinator: Coordinator) -> SettingsPopUpButton {
        let button = SettingsPopUpButton()
        button.target = coordinator
        button.action = #selector(Coordinator.picked(_:))
        return button
    }

    func update(_ button: SettingsPopUpButton, coordinator: Coordinator) {
        coordinator.options = options
        coordinator.select = select
        let titles = options.map(title)
        if button.itemTitles != titles {
            button.removeAllItems()
            button.addItems(withTitles: titles)
        }
        if let index = options.firstIndex(of: selection) { button.selectItem(at: index) }
        button.setAccessibilityLabel(accessibilityLabel)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView button: SettingsPopUpButton, context: Context) -> CGSize? {
        button.intrinsicContentSize
    }

    @MainActor final class Coordinator: NSObject {
        var options: [Option] = []
        var select: (Option) -> Void = { _ in }

        @objc func picked(_ button: NSPopUpButton) {
            let index = button.indexOfSelectedItem
            guard options.indices.contains(index) else { return }
            select(options[index])
        }
    }
}
