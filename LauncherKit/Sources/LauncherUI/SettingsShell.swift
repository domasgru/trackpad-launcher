import AppKit
import LauncherCore
import Observation
import UniformTypeIdentifiers

/// The thin AppKit shell: maps AppKit signals to `Launcher` intents and renders `Launcher` state.
/// Create it before `Launcher.start()`: its first icon pass must finish before gestures run.
///
/// It renders `launcher.window`: the settings window opens centred on the pointer's display and the app joins the
/// Dock and ⌘-Tab; closing it removes both. It is the only place the activation policy changes. The window closes
/// only through the model: the close button, ⌘W, Escape and Close Settings (⌘Q) all send `closeWindow()`.
public final class SettingsShell: NSObject, NSWindowDelegate {
    private let launcher: Launcher
    private let icons = AppIcons()
    private let switcherPresenter: SwitcherPresenter
    private let windowSwitcherPresenter: WindowSwitcherPresenter
    private let window: SettingsWindow
    private var isShown = false
    private var observations: [Task<Void, Never>] = []

    public init(launcher: Launcher, quit: @escaping () -> Void) {
        self.launcher = launcher
        icons.renderOnMainActor(Self.iconTargets(launcher))
        let window = SettingsWindow()
        let actions = Self.makeActions(launcher: launcher, icons: icons, window: window, quit: quit)
        window.install(content: SettingsView(launcher: launcher, actions: actions))
        self.window = window
        switcherPresenter = SwitcherPresenter(launcher: launcher)
        windowSwitcherPresenter = WindowSwitcherPresenter(launcher: launcher)
        super.init()

        window.delegate = self
        window.onCancel = { [launcher] in launcher.closeWindow() }
        NSApp.mainMenu = makeMainMenu()

        observations.append(
            Task { [weak self] in
                for await _ in Observations({
                    (
                        launcher.activity, launcher.isAccessibilityGranted, launcher.isSwipeOn,
                        launcher.screenRecordingHint
                    )
                }) {
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
                for await state in Observations({ launcher.window }) {
                    self?.render(state)
                }
            })
    }

    isolated deinit {
        observations.forEach { $0.cancel() }
    }

    /// The close button and ⌘W.
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        launcher.closeWindow()
        return false
    }

    @objc private func closeSettings(_ sender: Any?) { launcher.closeWindow() }

    /// The app menu holds Close Settings (⌘Q) where Quit would be; the Window menu holds Minimize and Close.
    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let close = NSMenuItem(title: Copy.closeSettings, action: #selector(closeSettings), keyEquivalent: "q")
        close.target = self
        appMenu.addItem(close)
        appItem.submenu = appMenu
        main.addItem(appItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(
            withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        NSApp.windowsMenu = windowMenu
        return main
    }

    private func render(_ state: Launcher.Window) {
        switch state {
        case .closed:
            guard isShown else { return }
            isShown = false
            if let sheet = window.attachedSheet { window.endSheet(sheet, returnCode: .cancel) }
            window.orderOut(nil)
            NSApp.setActivationPolicy(.accessory)
        case .open:
            if !isShown {
                isShown = true
                NSApp.setActivationPolicy(.regular)
                renderIcons()
                fit()
                centre()
            }
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
        }
    }

    /// The picker's apps plus the present apps of the gesture rows, which may sit outside it.
    private static func iconTargets(_ launcher: Launcher) -> [AppEntry] {
        let rowApps = launcher.rows.compactMap { row -> AppEntry? in
            if case .present(let entry) = row.app { entry } else { nil }
        }
        return launcher.installedApps.all + rowApps
    }

    private func renderIcons() { icons.renderOffMainActor(Self.iconTargets(launcher)) }

    /// Sizes the window to its content, keeping the top edge where it is.
    private func fit() {
        let top = window.frame.maxY
        window.setContentSize(window.contentFittingSize)
        window.setFrameTopLeftPoint(NSPoint(x: window.frame.minX, y: top))
    }

    private func refit() {
        guard isShown else { return }
        fit()
    }

    /// The middle of the visible frame of the display under the pointer.
    private func centre() {
        guard let screen = Displays.screen(under: NSEvent.mouseLocation) else { return window.center() }
        let visible = screen.visibleFrame
        let size = window.frame.size
        window.setFrameOrigin(
            NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2))
    }

    private static func makeActions(
        launcher: Launcher, icons: AppIcons, window: SettingsWindow, quit: @escaping () -> Void
    ) -> LauncherActions {
        LauncherActions(
            cachedIcon: { icons.cachedIcon(for: $0) },
            icon: { icons.iconDrawingIfMissing(for: $0) },
            chooseOtherApp: { [weak window] completion in
                guard let window else { return }
                let chooser = NSOpenPanel()
                chooser.allowedContentTypes = [.application]
                chooser.canChooseDirectories = false
                chooser.allowsMultipleSelection = false
                chooser.directoryURL = URL(filePath: "/Applications")
                chooser.beginSheetModal(for: window) { response in
                    if response == .OK, let url = chooser.url { completion(url) }
                }
            },
            openSettings: { pane in NSWorkspace.shared.open(pane.url) },
            quit: quit)
    }
}
