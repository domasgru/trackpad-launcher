import AppKit
import LauncherCore
import Observation
import UniformTypeIdentifiers

/// The thin AppKit shell: maps AppKit signals to `Launcher` intents and renders `Launcher` state.
/// Create it before `Launcher.start()`: a first-launch window needs the status item as its anchor.
///
/// Dismissal: an icon click toggles; the panel resigning key dismisses it, except for a mouse-down on the status
/// item's own button (that click is the toggle, and closing here would reopen it); a mouse-down monitor
/// exists only while the window is open and dismisses; Escape closes; a fired gesture closes it through the model.
public final class MenuBarShell: NSObject {
    private let launcher: Launcher
    private let icons = AppIcons()
    private let statusItem: NSStatusItem
    private let panel: LauncherPanel
    private var mouseDownMonitor: Any?
    private var observations: [Task<Void, Never>] = []
    private var statusWindowMoved: NSObjectProtocol?

    public init(launcher: Launcher) {
        self.launcher = launcher
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        icons.renderOnMainActor(Self.iconTargets(launcher))
        let actions = Self.makeActions(launcher: launcher, icons: icons)
        panel = LauncherPanel(content: LauncherView(launcher: launcher, actions: actions))
        super.init()

        statusItem.button?.image = StatusIcon.image(active: launcher.activity.isActive)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggleWindow)
        panel.onCancel = { [launcher] in launcher.closeWindow() }
        panel.onResignKey = { [unowned self] in resignedKey() }

        statusWindowMoved = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: statusItem.button?.window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refit() }
        }
        observations.append(
            Task { [weak self] in
                for await active in Observations({ launcher.activity.isActive }) {
                    self?.statusItem.button?.image = StatusIcon.image(active: active)
                }
            })
        observations.append(
            Task { [weak self] in
                for await _ in Observations({ (launcher.activity, launcher.isAccessibilityGranted) }) {
                    self?.refit()
                }
            })
        observations.append(
            Task { [weak self] in
                for await _ in Observations({ launcher.installedApps }) {
                    self?.renderIcons()
                }
            })
        observations.append(
            Task { [weak self] in
                for await open in Observations({ launcher.isWindowOpen }) {
                    if open { self?.show() } else { self?.hide() }
                }
            })
    }

    isolated deinit {
        observations.forEach { $0.cancel() }
        if let statusWindowMoved { NotificationCenter.default.removeObserver(statusWindowMoved) }
    }

    @objc private func toggleWindow() {
        if launcher.isWindowOpen { launcher.closeWindow() } else { launcher.openWindow() }
    }

    private func resignedKey() {
        let event = NSApp.currentEvent
        let isStatusButtonClick = event?.type == .leftMouseDown && event?.window === statusItem.button?.window
        if !isStatusButtonClick { launcher.dismissWindow() }
    }

    /// The listed apps plus the rows' present apps, which may sit outside the list.
    private static func iconTargets(_ launcher: Launcher) -> [AppEntry] {
        let rowApps = launcher.rows.compactMap { row -> AppEntry? in
            if case .present(let entry) = row.app { entry } else { nil }
        }
        return launcher.installedApps.all + rowApps
    }

    private func renderIcons() { icons.renderOffMainActor(Self.iconTargets(launcher)) }

    private func show() {
        renderIcons()
        refit()
        panel.makeKeyAndOrderFront(nil)
        guard mouseDownMonitor == nil else { return }
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [launcher] _ in
            MainActor.assumeIsolated { launcher.dismissWindow() }
        }
    }

    private func hide() {
        if let mouseDownMonitor { NSEvent.removeMonitor(mouseDownMonitor) }
        mouseDownMonitor = nil
        panel.orderOut(nil)
    }

    /// Below the icon, centred on it, clamped into the screen; the top edge stays put when the content grows.
    /// The status item's window sits off-screen until the menu bar lays it out, so until it has a real frame
    /// the panel goes to the top-right corner, and it moves under the icon when the frame arrives.
    private func refit() {
        guard launcher.isWindowOpen else { return }
        let statusWindow = statusItem.button?.window
        guard let screen = statusWindow?.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var anchorX = visible.maxX
        var topEdge = visible.maxY
        if let frame = statusWindow?.frame, frame.width > 0, frame.maxY > screen.frame.maxY - 60 {
            anchorX = frame.midX
            topEdge = min(frame.minY - 6, visible.maxY)
        }
        panel.fitToContent(centeredOn: anchorX, topEdge: topEdge, within: visible)
    }

    private static func makeActions(launcher: Launcher, icons: AppIcons) -> LauncherActions {
        LauncherActions(
            cachedIcon: { icons.cachedIcon(for: $0) },
            icon: { icons.iconDrawingIfMissing(for: $0) },
            chooseOtherApp: { gesture in
                launcher.closeWindow()
                NSApp.activate()
                let chooser = NSOpenPanel()
                chooser.allowedContentTypes = [.application]
                chooser.canChooseDirectories = false
                chooser.allowsMultipleSelection = false
                chooser.directoryURL = URL(filePath: "/Applications")
                chooser.begin { response in
                    if response == .OK, let url = chooser.url {
                        launcher.setAssignment(.appBundle(at: url), for: gesture)
                    }
                    launcher.openWindow()
                }
            },
            openSettings: { pane in
                launcher.closeWindow()
                NSWorkspace.shared.open(pane.url)
            },
            quit: { NSApp.terminate(nil) })
    }
}
