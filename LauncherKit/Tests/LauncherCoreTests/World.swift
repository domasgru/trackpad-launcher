import Foundation
import LauncherCore
import Synchronization

/// What `registeredCopies` answers; a test edits it to stand in for LaunchServices.
final class Registry: Sendable {
    private let storage = Mutex<[BundleID: [URL]]>([:])

    subscript(bundleID: BundleID) -> [URL] {
        get { storage.withLock { $0[bundleID] ?? [] } }
        set { storage.withLock { $0[bundleID] = newValue } }
    }
}

/// What `lastOpened` answers; a test edits it to stand in for Spotlight. Keyed by canonical bundle path.
final class LaunchRecord: Sendable {
    private let storage = Mutex<[String: Date]>([:])

    static func key(_ url: URL) -> String { url.resolvingSymlinksInPath().path }

    subscript(url: URL) -> Date? {
        get { storage.withLock { $0[Self.key(url)] } }
        set { storage.withLock { $0[Self.key(url)] = newValue } }
    }

    /// Strictly increasing from the reference date, so no test depends on how recent a launch is.
    func record(_ url: URL) {
        storage.withLock { $0[Self.key(url)] = Date(timeIntervalSinceReferenceDate: Double($0.count + 1)) }
    }
}

/// The real `Launcher` over in-memory adapters, a temp directory of fake app bundles and a throwaway suite.
@MainActor final class World {
    let root: URL
    let applications: URL
    let systemApplications: URL
    let userApplications: URL
    let coreServices: URL
    let downloads: URL
    let trashFolder: URL
    let suiteName = "tl-test-\(UUID().uuidString)"

    let hardware: InMemoryTrackpads
    let preferences = InMemoryTrackpadPreferences()
    let system = RecordingSystemActions()
    let access: InMemoryAccessibilityPermission
    let registry = Registry()
    let launches = LaunchRecord()
    let scanner: InMemoryAppScanner
    let catalog: AppCatalog
    private(set) var store: SettingsStore
    private(set) var launcher: Launcher
    private var delivered: [TrackpadID: Double] = [:]

    init(apps: [String] = [], attached: [Trackpad] = [.macBook14], accessGranted: Bool = false) {
        let root = FileManager.default.temporaryDirectory.appending(path: "tl-world-\(UUID().uuidString)")
        self.root = root
        applications = root.appending(path: "Applications")
        systemApplications = root.appending(path: "SystemApplications")
        userApplications = root.appending(path: "UserApplications")
        coreServices = root.appending(path: "CoreServices")
        downloads = root.appending(path: "Downloads")
        trashFolder = root.appending(path: ".Trash")
        for dir in [applications, systemApplications, userApplications, coreServices, downloads, trashFolder] {
            try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        hardware = InMemoryTrackpads(attached: attached)
        access = InMemoryAccessibilityPermission(granted: accessGranted)
        let registry = registry
        let launches = launches
        let catalog = AppCatalog(
            roots: [applications, systemApplications, userApplications],
            extras: [coreServices.appending(path: "Finder.app")],
            registeredCopies: { registry[$0] },
            lastOpened: { launches[$0] })
        self.catalog = catalog
        scanner = InMemoryAppScanner(catalog: catalog)
        let store = SettingsStore(defaults: UserDefaults(suiteName: suiteName)!)
        self.store = store
        launcher = Self.makeLauncher(
            hardware: hardware, preferences: preferences, access: access, system: system, catalog: catalog,
            scanner: scanner, store: store)
        install("Finder", in: coreServices)
        for name in apps { install(name) }
    }

    private static func makeLauncher(
        hardware: InMemoryTrackpads, preferences: InMemoryTrackpadPreferences, access: InMemoryAccessibilityPermission,
        system: RecordingSystemActions, catalog: AppCatalog, scanner: InMemoryAppScanner, store: SettingsStore
    ) -> Launcher {
        Launcher(
            hardware: hardware, preferences: preferences, access: access, system: system, catalog: catalog,
            scanner: scanner, store: store)
    }

    deinit {
        UserDefaults().removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: root)
    }

    static func bundleID(_ name: String) -> BundleID {
        BundleID(rawValue: "com.test." + name.lowercased().replacingOccurrences(of: " ", with: "-"))
    }

    @discardableResult
    func install(_ name: String, in directory: URL? = nil, bundleID: String? = nil) -> URL {
        let url = (directory ?? applications).appending(path: "\(name).app")
        let contents = url.appending(path: "Contents")
        try! FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: [String: Any] = ["CFBundleIdentifier": bundleID ?? Self.bundleID(name).rawValue]
        try! PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: contents.appending(path: "Info.plist"))
        return url
    }

    /// Spotlight records a launch of the installed app.
    func recordLaunch(_ name: String, in directory: URL? = nil) {
        launches.record((directory ?? applications).appending(path: "\(name).app"))
    }

    /// The entry for an installed app, as it is on disk right now.
    func app(_ name: String, in directory: URL? = nil) -> AppEntry {
        catalog.entry(at: (directory ?? applications).appending(path: "\(name).app"))!
    }

    func remove(_ name: String, in directory: URL? = nil) {
        try! FileManager.default.removeItem(at: (directory ?? applications).appending(path: "\(name).app"))
    }

    @discardableResult
    func move(_ name: String, to directory: URL) -> URL {
        let destination = directory.appending(path: "\(name).app")
        try! FileManager.default.moveItem(at: applications.appending(path: "\(name).app"), to: destination)
        return destination
    }

    @discardableResult
    func trash(_ name: String) -> URL {
        let destination = trashFolder.appending(path: "\(name).app")
        try! FileManager.default.moveItem(at: applications.appending(path: "\(name).app"), to: destination)
        return destination
    }

    func tap(_ fingers: Int, on trackpad: Trackpad = .macBook14, thumbAtMM thumb: (x: Double, y: Double) = (10, 10)) {
        hardware.touch(TouchScript(trackpad.surface).thumb(atMM: thumb).tap(fingers: fingers).frames, on: trackpad.id)
    }

    /// Delivers the frames of `script` newer than any already delivered on that trackpad, so one hand in progress can
    /// be played in pieces with intents and reconciles in between.
    func play(_ script: TouchScript, on trackpad: Trackpad = .macBook14) {
        let newer = script.frames.filter { $0.time.seconds > (delivered[trackpad.id] ?? 0) }
        guard let last = newer.last else { return }
        delivered[trackpad.id] = last.time.seconds
        hardware.touch(newer, on: trackpad.id)
    }

    /// A second `Launcher` over the same adapters and a fresh `UserDefaults` instance on the same suite.
    @discardableResult
    func relaunch() -> Launcher {
        let store = SettingsStore(defaults: UserDefaults(suiteName: suiteName)!)
        self.store = store
        launcher = Self.makeLauncher(
            hardware: hardware, preferences: preferences, access: access, system: system, catalog: catalog,
            scanner: scanner, store: store)
        return launcher
    }
}

extension World {
    /// What the next swipe reads as frontmost; nil models no active app, or Trackpad Launcher itself.
    func makeFrontmost(_ name: String?) {
        system.frontmost = name.map { app($0).url }
    }

    /// Safari, Mail, Slack and Notes installed, Mail, Slack and Notes listed in that order, Safari frontmost, started.
    static func switcherWorld(accessGranted: Bool = false) -> World {
        let world = World(apps: ["Safari", "Mail", "Slack", "Notes"], accessGranted: accessGranted)
        world.launcher.start()
        for name in ["Mail", "Slack", "Notes"] { world.launcher.addToSwitcher(.app(world.app(name))) }
        world.makeFrontmost("Safari")
        return world
    }

    /// Thumb at (10, 10), two fingers down, each slide in turn (millimetres, positive right), then the fingers lift
    /// unless `lift` is false. Returns its script so a row can continue it with `play`.
    @discardableResult
    func swipe(_ slidesMM: Double..., lift: Bool = true, on trackpad: Trackpad = .macBook14) -> TouchScript {
        var script = TouchScript(trackpad.surface).thumb(atMM: (10, 10)).land(fingers: 2)
        for slide in slidesMM { script = script.slide(byMM: (slide, 0)) }
        if lift { script = script.lift() }
        play(script, on: trackpad)
        return script
    }
}
