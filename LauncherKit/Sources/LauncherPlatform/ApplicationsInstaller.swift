import AppKit
import LauncherCore

/// Puts this copy into /Applications. The copy runs off the main actor; only `done` hops back.
@MainActor public final class ApplicationsInstaller: Installer {
    private let location: Location
    private let applications: URL

    public convenience init(location: Location) {
        self.init(location: location, applications: URL(filePath: "/Applications"))
    }

    init(location: Location, applications: URL) {
        self.location = location
        self.applications = applications
    }

    public func install(then done: @escaping @MainActor (InstallOutcome) -> Void) {
        let location = location
        let applications = applications
        Task {
            let outcome = await Self.copy(location, into: applications)
            done(outcome)
        }
    }

    public func removeOriginal() {
        guard location.diskImage == nil else { return }
        let destination = Self.destination(of: location, in: applications)
        guard location.original.standardizedFileURL != destination.standardizedFileURL else { return }
        BundleInstall.removeOriginal(location.original)
    }

    public func openInstalledCopy() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(
            at: Self.destination(of: location, in: applications), configuration: configuration)
    }

    /// The bundle with this app's identifier already directly inside `applications`, under any name; else the original's
    /// name there.
    private nonisolated static func destination(of location: Location, in applications: URL) -> URL {
        let name = location.original.lastPathComponent
        let identifier = Bundle(url: location.running)?.bundleIdentifier
        let installed = (try? FileManager.default.contentsOfDirectory(
            at: applications, includingPropertiesForKeys: nil)) ?? []
        let ours =
            installed
            .filter { $0.pathExtension == "app" && identifier != nil && Bundle(url: $0)?.bundleIdentifier == identifier }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return ours.first { $0.lastPathComponent == name } ?? ours.first ?? applications.appending(path: name)
    }

    @concurrent
    private static func copy(_ location: Location, into applications: URL) async -> InstallOutcome {
        let destination = destination(of: location, in: applications)
        let staged: URL
        do {
            staged = try BundleInstall.stage(location.running, near: destination)
        } catch {
            return .failed(reason: error.localizedDescription)
        }
        let files = FileManager.default
        let canWrite =
            files.isWritableFile(atPath: applications.path)
            && (!files.fileExists(atPath: destination.path) || files.isWritableFile(atPath: destination.path))
        guard canWrite else {
            BundleInstall.discard(staged)
            return .failed(reason: Copy.cannotWriteToApplications)
        }
        do {
            try BundleInstall.swap(staged, into: destination)
            return .installed
        } catch {
            BundleInstall.discard(staged)
            return .failed(reason: error.localizedDescription)
        }
    }
}
