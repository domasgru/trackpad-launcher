import CoreServices
import Foundation
import LauncherCore

/// Scans the catalog off the main actor, on request and after an app is installed, removed or renamed in its roots.
/// Requests made during a scan coalesce into one more scan after it.
@MainActor public final class SystemAppScanner: AppScanner {
    public var onScan: (@MainActor (InstalledApps) -> Void)?
    private let catalog: AppCatalog
    private var stream: FSEventStreamRef?
    private var isScanning = false
    private var isScanPending = false

    public init(catalog: AppCatalog) {
        self.catalog = catalog
        startStream()
    }

    isolated deinit { stopStream() }

    public func scan() {
        guard !isScanning else {
            isScanPending = true
            return
        }
        isScanning = true
        Task { [catalog] in
            let installed = await Self.read(catalog)
            finishScan(installed)
        }
    }

    private func finishScan(_ installed: InstalledApps) {
        isScanning = false
        onScan?(installed)
        guard isScanPending else { return }
        isScanPending = false
        scan()
    }

    @concurrent private static func read(_ catalog: AppCatalog) async -> InstalledApps {
        catalog.installedApps()
    }

    private func startStream() {
        var context = FSEventStreamContext(
            version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil,
            copyDescription: nil)
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagWatchRoot)
        guard
            let stream = FSEventStreamCreate(
                nil, Self.callback, &context, catalog.roots.map(\.path) as CFArray,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 1.0, flags)
        else { return }
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    private func stopStream() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private static let callback: FSEventStreamCallback = { _, info, count, paths, flags, _ in
        let paths = unsafeBitCast(paths, to: NSArray.self) as? [String] ?? []
        let indices = 0..<count
        guard let info, indices.contains(where: { isInstallChange(path: paths[$0], flags: flags[$0]) }) else { return }
        let rootChanged = indices.contains { flags[$0] & FSEventStreamEventFlags(kFSEventStreamEventFlagRootChanged) != 0 }
        let scanner = Unmanaged<SystemAppScanner>.fromOpaque(info).takeUnretainedValue()
        MainActor.assumeIsolated { scanner.handleChange(rootChanged: rootChanged) }
    }

    /// A root that was created, deleted or renamed is reported only by a stream made afterwards, so the stream is
    /// re-created before the scan is requested: a change in between is then seen by one or the other.
    private func handleChange(rootChanged: Bool) {
        guard rootChanged else { return scan() }
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.stopStream()
                self.startStream()
                self.scan()
            }
        }
    }

    private static let alwaysCountingFlags = FSEventStreamEventFlags(
        kFSEventStreamEventFlagRootChanged | kFSEventStreamEventFlagMustScanSubDirs
            | kFSEventStreamEventFlagUserDropped | kFSEventStreamEventFlagKernelDropped)

    /// Whether an event can change the list. Looks only at path components, never at the roots, so `/var` against
    /// `/private/var` does not matter. Writes deeper inside a bundle than its `Contents` folder do not count: updaters
    /// and apps write there all the time.
    static func isInstallChange(path: String, flags: FSEventStreamEventFlags) -> Bool {
        if flags & alwaysCountingFlags != 0 { return true }
        let components = path.split(separator: "/")
        guard let app = components.firstIndex(where: { $0.hasSuffix(".app") }),
              components.indices.contains(app + 1), components[app + 1] == "Contents"
        else { return true }
        return components.count == app + 2
    }
}
