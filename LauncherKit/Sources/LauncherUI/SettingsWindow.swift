import AppKit
import SwiftUI

/// The settings window: an ordinary titled window with the close and minimise buttons. Its content is an
/// `NSGlassEffectView` hosting the SwiftUI view, built once and kept so the pickers open instantly.
final class SettingsWindow: NSWindow {
    var onCancel: () -> Void = {}

    private var hosting: NSHostingView<AnyView>?

    init() {
        super.init(
            contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: true)
        title = "Trackpad Launcher"
        isReleasedWhenClosed = false
        level = .normal
    }

    func install(content: some View) {
        let hosting = NSHostingView(rootView: AnyView(content))
        let glass = NSGlassEffectView()
        glass.style = .regular
        glass.contentView = hosting
        contentView = glass
        self.hosting = hosting
    }

    /// The content's natural size.
    var contentFittingSize: NSSize { hosting?.fittingSize ?? .zero }

    /// Escape.
    override func cancelOperation(_ sender: Any?) { onCancel() }
}
