import AppKit
import LauncherCore
import Observation

/// Renders `launcher.windowSwitcher` and holds nothing the model holds. Owned by `MenuBarShell` beside
/// `SwitcherPresenter`. The panel is created now, so a window swipe never pays the first window's cost. Its own icons
/// take the frontmost app's icon from the running app (about 0.1 ms), so it needs none of the swipe setting's icon
/// passes. Each window swipe that shows previews starts one capture, whose pictures go straight into the panel.
final class WindowSwitcherPresenter {
    private let launcher: Launcher
    private let look = WindowSwitcherLook.shipped
    private let panel: WindowSwitcherPanel
    private let icons = AppIcons(side: WindowColumnLayout.iconSide)
    private var observation: Task<Void, Never>?
    /// The shown window swipe's previews being taken.
    private var capture: Task<Void, Never>?
    /// The window swipe whose switcher is laid out, so each window swipe lays out once.
    private var shownSerial: Int?
    private var layout = WindowColumnLayout(rowCount: 0, displayHeight: 0)
    private var lastStretch = 0.0

    init(launcher: Launcher) {
        self.launcher = launcher
        panel = WindowSwitcherPanel(look: look)
        observation = Task { [weak self] in
            for await shown in Observations({ launcher.windowSwitcher }) { self?.render(shown) }
        }
    }

    isolated deinit {
        observation?.cancel()
        capture?.cancel()
    }

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// nil hides with the overlay's fade. A new window swipe's switcher is laid out and shown first.
    private func render(_ switcher: WindowSwitcher?) {
        guard let switcher else {
            capture?.cancel()
            capture = nil
            shownSerial = nil
            // Fades, then the panel drops every picture.
            panel.dismiss()
            return
        }
        if switcher.serial != shownSerial { open(switcher) }
        let selection = switcher.selection
        panel.show(position: selection.position, selected: selection.selected)
        if selection.stretch != lastStretch, selection.stretch != 0, !reduceMotion {
            panel.springHighlight(fromY: selection.stretch * layout.pitch)
        }
        lastStretch = selection.stretch
    }

    /// The column sits in the top-left corner of the pointer's display, a margin inside its visible frame: below the
    /// menu bar and clear of a Dock on the left, in both hand modes. The capture starts first, so it runs off the main
    /// actor while the panel is laid out and shown; its pictures land after `open` returns, into slots left empty.
    private func open(_ switcher: WindowSwitcher) {
        let screen = Displays.screen(under: NSEvent.mouseLocation)
        let visible = screen?.visibleFrame ?? .zero
        let rows = switcher.rows
        layout = WindowColumnLayout(rowCount: rows.count, displayHeight: Double(visible.height))
        shownSerial = switcher.serial
        lastStretch = 0
        capture(switcher, rows: rows, scale: Double(screen?.backingScaleFactor ?? 2))
        panel.lay(
            out: rows, icon: icons.icon(forSwitcher: switcher.app), layout: layout,
            topLeft: NSPoint(x: visible.minX + WindowColumnLayout.margin, y: visible.maxY - WindowColumnLayout.margin))
        let previewWindows = Set(switcher.previewWindows)
        panel.awaitPreviews(rows: rows.indices.filter { previewWindows.contains(rows[$0].window) })
        panel.present(
            appear: reduceMotion
                ? nil
                : OverlayAppear(
                    duration: look.appearDuration, fromScale: look.appearScale, stiffness: look.springStiffness,
                    damping: look.springDamping))
    }

    /// Replaces any earlier window swipe's capture with this one's, whose pictures go into the panel's rows. A row
    /// whose window yielded no picture gets the icon back once the capture is over.
    private func capture(_ switcher: WindowSwitcher, rows: [WindowSwitcher.Row], scale: Double) {
        capture?.cancel()
        capture = nil
        let windows = switcher.previewWindows
        guard !windows.isEmpty else { return }
        let serial = switcher.serial
        let pictures = PreviewCapture.pictures(of: windows, fitting: layout.previewPixels(scale: scale))
        capture = Task { [weak self] in
            for await (window, picture) in pictures {
                guard let self, shownSerial == serial else { return }
                if let row = rows.firstIndex(where: { $0.window == window }) {
                    panel.setPreview(picture, row: row, animated: !reduceMotion)
                }
            }
            guard let self, !Task.isCancelled, shownSerial == serial else { return }
            panel.showIconsWithoutPreview(animated: !reduceMotion)
        }
    }
}
