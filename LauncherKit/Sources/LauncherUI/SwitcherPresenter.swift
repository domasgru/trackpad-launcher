import AppKit
import LauncherCore
import Observation

/// Renders `launcher.switcher` and holds nothing the model holds. Owned by `MenuBarShell`.
///
/// The panel is created now so a swipe never pays the first window's cost, and the 80 pt icons of the running Dock apps
/// are drawn before any swipe: at `startIconPasses()` (waited for), again off the main actor for each app the workspace
/// reports launched and for every running app on an appearance change, and dropped when it reports an app terminated.
final class SwitcherPresenter {
    private let launcher: Launcher
    private let panel = SwitcherPanel()
    private let icons = AppIcons(side: SwitcherPanel.iconSide)
    private var observations: [Task<Void, Never>] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var appearanceObservation: NSKeyValueObservation?
    private var laidOutRow: [AppEntry] = []
    private var lastStretch = 0.0
    private var isShown = false
    /// Bumped by every open and close, so a fade's completion that a later open or close outlived does nothing.
    private var fadeGeneration = 0

    init(launcher: Launcher) {
        self.launcher = launcher
        startIconPasses()
        observations.append(
            Task { [weak self] in
                for await shown in Observations({ launcher.switcher }) { self?.render(shown) }
            })
    }

    isolated deinit {
        observations.forEach { $0.cancel() }
        stopIconPasses()
    }

    /// Draws every running Dock app's icon now and waits, then keeps the cache current. A no-op while started.
    func startIconPasses() {
        guard workspaceObservers.isEmpty else { return }
        icons.renderOnMainActor(urls: Self.runningDockApps().map(\.location))
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers = [
            center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) {
                [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                MainActor.assumeIsolated { self?.launched(app) }
            },
            center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) {
                [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                MainActor.assumeIsolated { self?.terminated(app) }
            },
        ]
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.redrawRunningApps() }
        }
    }

    /// Removes the observers and empties the cache; a pass in flight is discarded.
    func stopIconPasses() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { center.removeObserver($0) }
        workspaceObservers = []
        appearanceObservation = nil
        icons.removeAll()
    }

    private func launched(_ app: NSRunningApplication?) {
        guard let location = app.flatMap(Self.dockLocation) else { return }
        pass(over: [location])
    }

    private func terminated(_ app: NSRunningApplication?) {
        guard let location = app?.bundleURL.map(Self.location) else { return }
        // A second copy of the same bundle may still be running.
        guard !Self.runningDockApps().contains(where: { $0.location == location }) else { return }
        icons.evict(location)
    }

    private func redrawRunningApps() { pass(over: Self.runningDockApps().map(\.location)) }

    /// Draws away from the main actor, then drops icons of apps that quit while it ran.
    private func pass(over urls: [URL]) {
        Task { [weak self] in
            guard let self else { return }
            await icons.renderOffMainActor(urls: urls)
            guard !workspaceObservers.isEmpty else { return }
            icons.retainOnly(Set(Self.runningDockApps().map(\.location)))
        }
    }

    /// The same spelling of a bundle's location the running-apps read uses.
    private static func location(_ bundleURL: URL) -> URL { URL(fileURLWithPath: bundleURL.path, isDirectory: true) }

    private static func dockLocation(_ app: NSRunningApplication) -> URL? {
        guard app.activationPolicy == .regular, let bundleURL = app.bundleURL else { return nil }
        return location(bundleURL)
    }

    private static func runningDockApps() -> [(app: NSRunningApplication, location: URL)] {
        NSWorkspace.shared.runningApplications.compactMap { app in dockLocation(app).map { (app, $0) } }
    }

    /// nil hides: opacity to 0 over 150 ms, then out, unless a switcher opened meanwhile (Reduce motion: at once).
    /// A switcher that is not on screen yet, or whose row differs from the laid-out one, is laid out and shown first.
    private func render(_ switcher: Switcher?) {
        guard let switcher else {
            hide()
            return
        }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if !isShown || switcher.row != laidOutRow { open(switcher.row) }
        panel.show(
            position: CGFloat(switcher.position), selected: switcher.selected, name: switcher.selectedApp.name,
            animatesSize: !reduceMotion)
        if switcher.stretch != lastStretch, switcher.stretch != 0, !reduceMotion {
            panel.springHighlight(from: CGFloat(switcher.stretch) * SwitcherPanel.iconPitch)
        }
        lastStretch = switcher.stretch
    }

    private func open(_ row: [AppEntry]) {
        let screen = Self.screen(under: NSEvent.mouseLocation)
        panel.layoutRow(
            row.map { icons.icon(forSwitcher: $0) }, on: screen?.frame ?? .zero,
            scale: screen?.backingScaleFactor ?? 2)
        laidOutRow = row
        lastStretch = 0
        isShown = true
        fadeGeneration += 1
        panel.restoreOpacity()
        panel.orderFrontRegardless()
    }

    private func hide() {
        guard isShown else { return }
        isShown = false
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.orderOut(nil)
            return
        }
        fadeGeneration += 1
        let generation = fadeGeneration
        panel.fadeOut(duration: 0.15) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.fadeGeneration == generation else { return }
                self.panel.orderOut(nil)
            }
        }
    }

    /// AppKit's own rule for which display holds the pointer; the nearest display when none does.
    private static func screen(under pointer: NSPoint) -> NSScreen? {
        let screens = NSScreen.screens
        return screens.first { NSMouseInRect(pointer, $0.frame, false) }
            ?? screens.min { distance(from: pointer, to: $0.frame) < distance(from: pointer, to: $1.frame) }
    }

    private static func distance(from point: NSPoint, to rect: NSRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }
}
