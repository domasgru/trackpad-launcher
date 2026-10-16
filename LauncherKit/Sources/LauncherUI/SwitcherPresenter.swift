import AppKit
import LauncherCore
import Observation

/// Renders `launcher.switcher` and holds nothing the model holds. Owned by `MenuBarShell`.
///
/// The panel is created now so a swipe never pays the first window's cost, and the 80 pt icons of the running Dock apps
/// are drawn before any swipe: at `startIconPasses(waiting:)`, again off the main actor for each app the workspace
/// reports launched and for every running app on an appearance change, and dropped when it reports an app terminated.
/// All of it runs only while the swipe setting is on; off, the observers are removed and the cache is empty.
final class SwitcherPresenter {
    private let launcher: Launcher
    private let panel = SwitcherPanel()
    private let icons = AppIcons(side: SwitcherRowLayout.fullIconSide)
    private var observations: [Task<Void, Never>] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var appearanceObservation: NSKeyValueObservation?
    private var laidOutRow: [AppEntry] = []
    private var layout = SwitcherRowLayout(iconCount: 0, displayWidth: 0)
    private var lastStretch = 0.0

    init(launcher: Launcher) {
        self.launcher = launcher
        if launcher.isSwipeOn { startIconPasses(waiting: true) }
        observations.append(
            Task { [weak self] in
                for await shown in Observations({ launcher.switcher }) { self?.render(shown) }
            })
        observations.append(
            Task { [weak self] in
                for await on in Observations({ launcher.isSwipeOn }) {
                    if on { self?.startIconPasses(waiting: false) } else { self?.stopIconPasses() }
                }
            })
    }

    isolated deinit {
        observations.forEach { $0.cancel() }
        stopIconPasses()
    }

    /// Draws every running Dock app's icon, then keeps the cache current. `waiting` draws now and waits; otherwise the
    /// pass runs away from the main actor. A no-op while started.
    func startIconPasses(waiting: Bool) {
        guard workspaceObservers.isEmpty else { return }
        if waiting {
            icons.renderOnMainActor(urls: Self.runningDockApps().map(\.location))
        } else {
            redrawRunningApps()
        }
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
        guard let location = app.flatMap(Self.dockLocation) else { return }
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

    /// A Dock app's location (regular activation policy and a bundle), spelled as the running-apps read spells it.
    private static func dockLocation(_ app: NSRunningApplication) -> URL? {
        guard app.activationPolicy == .regular, let bundleURL = app.bundleURL else { return nil }
        return AppEntry.location(ofBundleAtPath: bundleURL.path)
    }

    private static func runningDockApps() -> [(app: NSRunningApplication, location: URL)] {
        NSWorkspace.shared.runningApplications.compactMap { app in dockLocation(app).map { (app, $0) } }
    }

    /// nil hides: opacity to 0 over 150 ms, then out, unless a switcher opened meanwhile (Reduce motion: at once).
    /// A switcher that is not on screen yet, or whose row differs from the laid-out one, is laid out and shown first.
    private func render(_ switcher: Switcher?) {
        guard let switcher else {
            panel.dismiss()
            return
        }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if !panel.isPresented || switcher.row != laidOutRow { open(switcher.row) }
        let selection = switcher.selection
        panel.show(
            position: CGFloat(selection.position), selected: selection.selected, name: switcher.selectedApp.name,
            animatesSize: !reduceMotion)
        if selection.stretch != lastStretch, selection.stretch != 0, !reduceMotion {
            panel.springHighlight(from: CGFloat(selection.stretch) * layout.pitch)
        }
        lastStretch = selection.stretch
    }

    private func open(_ row: [AppEntry]) {
        let screen = Displays.screen(under: NSEvent.mouseLocation)
        layout = SwitcherRowLayout(iconCount: row.count, displayWidth: Double(screen?.frame.width ?? 0))
        panel.layoutRow(
            row.map { icons.icon(forSwitcher: $0) }, layout: layout, on: screen?.frame ?? .zero,
            scale: screen?.backingScaleFactor ?? 2)
        laidOutRow = row
        lastStretch = 0
        panel.present(appear: nil)
    }
}
