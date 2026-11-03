import AppKit
import LauncherCore
import Observation
import QuartzCore

/// Renders `launcher.switcher` and holds nothing the model holds. Owned by `SettingsShell`.
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
    private var liquid: Liquid?
    private let look: () -> LiquidLook

    /// `liquidLook` is read once per swipe.
    init(launcher: Launcher, liquidLook: @escaping () -> LiquidLook = { .shipped }) {
        self.launcher = launcher
        look = liquidLook
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
        guard app.activationPolicy == .regular, app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
            let bundleURL = app.bundleURL
        else { return nil }
        return AppEntry.location(ofBundleAtPath: bundleURL.path)
    }

    private static func runningDockApps() -> [(app: NSRunningApplication, location: URL)] {
        NSWorkspace.shared.runningApplications.compactMap { app in dockLocation(app).map { (app, $0) } }
    }

    /// nil hides: the shape fades out over 150 ms (at once with Reduce motion). A switcher that is not on screen yet,
    /// or whose row differs from the laid-out one, is laid out and shown settled first.
    private func render(_ switcher: Switcher?) {
        guard let switcher else {
            liquid = nil
            return panel.dismiss()
        }
        let now = LiquidTime(seconds: CACurrentMediaTime())
        if !panel.isPresented || switcher.row != laidOutRow { return open(switcher, at: now) }
        guard let frame = liquid?.follow(switcher.selection, at: now), !frame.isEmpty else { return }
        panel.apply(frame)
    }

    private func open(_ switcher: Switcher, at now: LiquidTime) {
        let screen = Displays.screen(under: NSEvent.mouseLocation)
        let layout = SwitcherRowLayout(
            iconCount: switcher.row.count, displayWidth: Double(screen?.frame.width ?? 0), look: look())
        panel.lay(
            out: switcher.row.map { icons.icon(forSwitcher: $0) }, layout: layout, on: screen?.frame ?? .zero,
            backingScale: screen?.backingScaleFactor ?? 2)
        panel.present(appear: nil)
        let still = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || !panel.checkMirror()
        var liquid = Liquid(layout: layout, motion: still ? .still : .flowing)
        panel.apply(liquid.follow(switcher.selection, at: now))
        self.liquid = liquid
        laidOutRow = switcher.row
    }
}
