import AppKit
import LauncherCore
import Observation

/// Renders `launcher.windowSwitcher` and holds nothing the model holds. Owned by `MenuBarShell` beside
/// `SwitcherPresenter`. The panel is created now, so a window swipe never pays the first window's cost. Its own icons
/// take the frontmost app's icon from the running app (about 0.1 ms), so it needs none of the swipe setting's icon
/// passes.
final class WindowSwitcherPresenter {
    private let launcher: Launcher
    private let look = WindowSwitcherLook.shipped
    private let panel: WindowSwitcherPanel
    private let icons = AppIcons(side: WindowColumnLayout.iconSide)
    private var observation: Task<Void, Never>?
    /// The window swipe whose switcher is laid out, so each window swipe lays out once.
    private var shownSerial: Int?
    private var layout = WindowColumnLayout(rowCount: 0, widestTitle: 0, displayHeight: 0)
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
    }

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// nil hides with the overlay's fade. A new window swipe's switcher is laid out and shown first.
    private func render(_ switcher: WindowSwitcher?) {
        guard let switcher else {
            shownSerial = nil
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
    /// menu bar and clear of a Dock on the left, in both hand modes.
    private func open(_ switcher: WindowSwitcher) {
        let visible = Displays.screen(under: NSEvent.mouseLocation)?.visibleFrame ?? .zero
        let rows = switcher.rows
        layout = WindowColumnLayout(
            rowCount: rows.count, widestTitle: panel.widestTitle(rows), displayHeight: Double(visible.height))
        panel.lay(
            out: rows, icon: switcher.app.map { icons.icon(forSwitcher: $0) }, layout: layout,
            topLeft: NSPoint(x: visible.minX + WindowColumnLayout.margin, y: visible.maxY - WindowColumnLayout.margin))
        shownSerial = switcher.serial
        lastStretch = 0
        panel.present(
            appear: reduceMotion
                ? nil
                : OverlayAppear(
                    duration: look.appearDuration, fromScale: look.appearScale, stiffness: look.springStiffness,
                    damping: look.springDamping))
    }
}
