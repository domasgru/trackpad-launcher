import AppKit
import SwiftUI

/// Borderless, non-activating, key-capable; pop-up-menu level; joins every Space and full-screen apps.
/// Its content is an `NSGlassEffectView` hosting the SwiftUI view.
final class LauncherPanel: NSPanel {
    var onCancel: () -> Void = {}
    var onResignKey: () -> Void = {}

    private let hosting: NSHostingView<AnyView>

    init(content: some View) {
        hosting = NSHostingView(rootView: AnyView(content))
        super.init(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        let glass = NSGlassEffectView()
        glass.style = .regular
        glass.cornerRadius = Self.cornerRadius
        glass.contentView = hosting
        contentView = Self.roundedClip(glass)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
    }

    private static let cornerRadius: CGFloat = 26
    private static let screenMargin: CGFloat = 8

    /// The glass alone leaves faint full-rectangle content behind its rounded corners, and the window shadow
    /// traces that rectangle as a square outline. Clipping the content to the glass's shape makes everything
    /// outside the rounded corners transparent, so the shadow follows the rounded edge.
    private static func roundedClip(_ glass: NSGlassEffectView) -> NSView {
        let clip = NSView()
        clip.wantsLayer = true
        clip.layer?.cornerRadius = cornerRadius
        clip.layer?.cornerCurve = .continuous
        clip.layer?.masksToBounds = true
        glass.translatesAutoresizingMaskIntoConstraints = false
        clip.addSubview(glass)
        NSLayoutConstraint.activate([
            glass.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: clip.trailingAnchor),
            glass.topAnchor.constraint(equalTo: clip.topAnchor),
            glass.bottomAnchor.constraint(equalTo: clip.bottomAnchor),
        ])
        return clip
    }

    override var canBecomeKey: Bool { true }

    /// Escape.
    override func cancelOperation(_ sender: Any?) { onCancel() }

    override func resignKey() {
        super.resignKey()
        onResignKey()
    }

    /// Sizes the panel to its content, keeping the top edge where it is, and clamps it into `screenFrame`. The height
    /// stops at the screen's height less a margin; the content's one scrolling region absorbs what does not fit.
    func fitToContent(centeredOn anchorX: CGFloat, topEdge: CGFloat, within screenFrame: NSRect) {
        var size = hosting.fittingSize
        size.height = min(size.height, screenFrame.height - Self.screenMargin * 2)
        let x = min(max(anchorX - size.width / 2, screenFrame.minX + 8), screenFrame.maxX - size.width - 8)
        let y = max(topEdge - size.height, screenFrame.minY + Self.screenMargin)
        setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        invalidateShadow()
    }
}
