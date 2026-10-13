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
        contentView = roundedClip(glass, cornerRadius: Self.cornerRadius)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
    }

    private static let cornerRadius: CGFloat = 26
    private static let screenEdgeInset: CGFloat = 8

    override var canBecomeKey: Bool { true }

    /// Escape.
    override func cancelOperation(_ sender: Any?) { onCancel() }

    override func resignKey() {
        super.resignKey()
        onResignKey()
    }

    /// Sizes the panel to its content, keeping the top edge where it is, and clamps it into `screenFrame`.
    func fitToContent(centeredOn anchorX: CGFloat, topEdge: CGFloat, within screenFrame: NSRect) {
        let size = hosting.fittingSize
        let x = min(max(anchorX - size.width / 2, screenFrame.minX + Self.screenEdgeInset), screenFrame.maxX - size.width - Self.screenEdgeInset)
        let y = max(topEdge - size.height, screenFrame.minY + Self.screenEdgeInset)
        setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        invalidateShadow()
    }
}
