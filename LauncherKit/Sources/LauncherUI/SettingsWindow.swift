import AppKit
import SwiftUI

/// The settings window: an ordinary titled window with the close and minimise buttons, on the system's window
/// background. It hosts the SwiftUI view, built once and kept so the pickers open instantly, as the document of a
/// scroll view: the content keeps its own size, pinned to the top, and the system's vertical scroller shows only when
/// the shell has capped the window's height below it.
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
        hosting.translatesAutoresizingMaskIntoConstraints = false
        let scroll = NSScrollView()
        scroll.contentView = TopAnchoredClipView()
        scroll.documentView = hosting
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        let clip = scroll.contentView
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: clip.topAnchor),
            hosting.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
        ])
        contentView = scroll
        self.hosting = hosting
    }

    /// The title bar's height: the window's frame less its content.
    var titleBarHeight: CGFloat {
        frameRect(forContentRect: NSRect(origin: .zero, size: NSSize(width: 100, height: 100))).height - 100
    }

    /// Shows the top of the content.
    func scrollToTop() {
        guard let scroll = contentView as? NSScrollView else { return }
        scroll.contentView.scroll(to: .zero)
        scroll.reflectScrolledClipView(scroll.contentView)
    }

    /// The content's own size, whatever height the window has.
    var contentFittingSize: NSSize { hosting?.fittingSize ?? .zero }

    /// Escape.
    override func cancelOperation(_ sender: Any?) { onCancel() }
}

/// A clip view whose origin is its top, so the document starts at the top and grows downward.
private final class TopAnchoredClipView: NSClipView {
    override var isFlipped: Bool { true }
}
