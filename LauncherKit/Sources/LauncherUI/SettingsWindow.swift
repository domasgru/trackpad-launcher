import AppKit
import SwiftUI

/// The settings window: an ordinary titled window with the close and minimise buttons, on the system's window
/// background. It hosts the SwiftUI view, built once and kept so the pickers open instantly.
final class SettingsWindow: NSWindow {
    /// The appearance the window and its app icons are drawn in, whatever the system's; `nil` follows the system.
    /// Light until the dark theme is designed.
    static let pinnedAppearance = NSAppearance(named: .aqua)

    var onCancel: () -> Void = {}

    private var hosting: NSHostingView<AnyView>?

    init() {
        super.init(
            contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: true)
        title = "Trackpad Launcher"
        isReleasedWhenClosed = false
        level = .normal
        appearance = Self.pinnedAppearance
    }

    func install(content: some View) {
        let hosting = NSHostingView(rootView: AnyView(content))
        contentView = hosting
        self.hosting = hosting
    }

    /// The content's natural size.
    var contentFittingSize: NSSize { hosting?.fittingSize ?? .zero }

    /// Escape.
    override func cancelOperation(_ sender: Any?) { onCancel() }
}
