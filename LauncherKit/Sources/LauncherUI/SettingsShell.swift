import AppKit
import LauncherCore
import Observation
import UniformTypeIdentifiers

#if DEBUG
    /// A reference the shell and its actions share, so the actions, built before the shell exists, read the hook at call
    /// time.
    private final class TuningHook {
        var read: (() -> SettingsShell.PickTuning)?
    }
#endif

/// The thin AppKit shell: maps AppKit signals to `Launcher` intents and renders `Launcher` state.
/// Create it before `Launcher.start()`: its first icon pass must finish before gestures run.
///
/// It renders `launcher.window`: the settings window opens centred on the pointer's display and the app joins the
/// Dock and ⌘-Tab; closing it removes both. It is the only place the activation policy changes. The window closes
/// only through the model: the close button, ⌘W, Escape and Close Settings (⌘Q) all send `closeWindow()`.
public final class SettingsShell: NSObject, NSWindowDelegate {
    /// What the Debug tuner hands each pick: the animation to play and whether to pretend Reduce motion is on.
    public typealias PickTuning = (animation: PickAnimation, simulateReduceMotion: Bool)
    private let launcher: Launcher
    private let updater: Updater?
    private let icons = AppIcons { SettingsWindow.pinnedAppearance ?? NSApp.effectiveAppearance }
    private let switcherPresenter: SwitcherPresenter
    private let windowSwitcherPresenter: WindowSwitcherPresenter
    private let window: SettingsWindow
    private var isShown = false
    private var observations: [Task<Void, Never>] = []
    #if DEBUG
        /// The Debug tuner's pick animation and Reduce motion switch, read at every pick. The composition root sets it;
        /// Release builds carry none of it.
        public var pickTuning: (() -> PickTuning)? {
            get { tuningHook.read }
            set { tuningHook.read = newValue }
        }
        private let tuningHook = TuningHook()
        private let currentPickAnimation: () -> PickAnimation?
    #endif

    /// Everything that decides the window's height.
    private struct Fit: Equatable {
        let inactiveNotice: String?
        let showsAccessibilityHint: Bool
        let isSwipeOn: Bool
        let screenRecordingHint: ScreenRecordingHint?
        let card: UpdateCard.Layout?
    }

    public init(launcher: Launcher, updater: Updater?, quit: @escaping () -> Void) {
        self.launcher = launcher
        self.updater = updater
        icons.renderOnMainActor(Self.iconTargets(launcher))
        let window = SettingsWindow()
        #if DEBUG
            let hook = tuningHook
            let tuned: () -> PickTuning? = { hook.read?() }
        #else
            let tuned: () -> PickTuning? = { nil }
        #endif
        let actions = Self.makeActions(
            launcher: launcher, icons: icons, window: window, quit: quit, tuned: tuned)
        window.install(content: SettingsView(launcher: launcher, updater: updater, actions: actions))
        #if DEBUG
            currentPickAnimation = actions.pickAnimation
        #endif
        self.window = window
        switcherPresenter = SwitcherPresenter(launcher: launcher)
        windowSwitcherPresenter = WindowSwitcherPresenter(launcher: launcher)
        super.init()

        window.delegate = self
        window.onCancel = { [launcher] in launcher.closeWindow() }
        NSApp.mainMenu = makeMainMenu()

        observations.append(
            Task { [weak self] in
                var last: Fit?
                for await fit in Observations({
                    Fit(
                        inactiveNotice: launcher.inactiveNotice, showsAccessibilityHint: launcher.showsAccessibilityHint,
                        isSwipeOn: launcher.isSwipeOn, screenRecordingHint: launcher.screenRecordingHint,
                        card: updater?.card?.layout)
                }) {
                    // The card's progress changes what the observation reads, never what this holds.
                    guard fit != last else { continue }
                    last = fit
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
            // Closing while hidden (the Dock's Quit) must not leave the process hidden with no window.
            if NSApp.isHidden { NSApp.unhideWithoutActivation() }
        case .open:
            if !isShown {
                isShown = true
                NSApp.setActivationPolicy(.regular)
                renderIcons()
                fit()
                centre()
            }
            if window.isMiniaturized { window.deminiaturize(nil) }
            // An opening by hand while the app is hidden shows the window where it was; this also covers a window
            // closed while hidden and reopened.
            if NSApp.isHidden { NSApp.unhide(nil) }
            window.makeKeyAndOrderFront(nil)
            AppActivation.activateOverOtherApps()
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

    #if DEBUG
        /// Debug builds' tuner button: plays the pick animation, as a pick would (so Reduce motion, the system's or
        /// the tuner's simulated one, applies), on every picker showing an installed app's icon in the open settings
        /// window. No assignment changes.
        public func previewPickAnimation() {
            guard case .open = launcher.window, let animation = currentPickAnimation() else { return }
            for picker in pickers(in: window.contentView) where !picker.iconLayer.isHidden {
                picker.play(animation)
            }
        }

        /// True while the settings window is open and some row shows an installed app. Reads observed state, so a
        /// SwiftUI body calling it follows the model.
        public var canPreviewPickAnimation: Bool {
            guard case .open = launcher.window else { return false }
            return launcher.rows.contains { if case .present = $0.app { true } else { false } }
        }

        private func pickers(in view: NSView?) -> [PickerButton] {
            guard let view else { return [] }
            return (view as? PickerButton).map { [$0] } ?? view.subviews.flatMap { pickers(in: $0) }
        }
    #endif

    /// What the pick animation plays now: nothing under Reduce motion, the system's or the tuner's simulated one;
    /// otherwise the tuner's values when it is wired, else the shipped ones.
    static func pickAnimation(
        reduceMotion: Bool, tuned: PickTuning?
    ) -> PickAnimation? {
        if reduceMotion { return nil }
        guard let tuned else { return .shipped }
        return tuned.simulateReduceMotion ? nil : tuned.animation
    }

    private static func makeActions(
        launcher: Launcher, icons: AppIcons, window: SettingsWindow, quit: @escaping () -> Void,
        tuned: @escaping () -> PickTuning?
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
            pickAnimation: {
                pickAnimation(
                    reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, tuned: tuned())
            },
            openSettings: { pane in NSWorkspace.shared.open(pane.url) },
            quit: quit)
    }
}
