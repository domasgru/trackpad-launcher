import Foundation
import LauncherCore
import Testing

@testable import LauncherPlatform

@Suite struct ThisCopyLocationTests {
    @Test func aBundleInApplicationsWithATrailingSlashIsInstalledAndNotTranslocated() {
        let bundle = URL(filePath: "/Applications/TrackpadLauncher.app/")

        let location = ThisCopy.location(of: bundle, originalIfTranslocated: { _ in nil }, diskImage: { _ in nil })

        #expect(location.running == bundle)
        #expect(location.original == bundle)
        #expect(!location.isTranslocated)
        #expect(location.diskImage == nil)
        #expect(Placement(build: .release, location: location) == .installed)
    }

    @Test func aTranslocatedBundleFindsItsDiskImageFromTheOriginal() {
        let running = URL(filePath: "/private/var/folders/xx/AppTranslocation/ABC/d/TrackpadLauncher.app")
        let original = URL(filePath: "/Volumes/Trackpad Launcher/TrackpadLauncher.app")
        let volume = URL(filePath: "/Volumes/Trackpad Launcher")

        let location = ThisCopy.location(
            of: running,
            originalIfTranslocated: { $0 == running ? original : nil },
            diskImage: { $0.path.hasPrefix(volume.path) ? DiskImage(volume: volume) : nil })

        #expect(location.running == running)
        #expect(location.original == original)
        #expect(location.isTranslocated)
        #expect(location.diskImage == DiskImage(volume: volume))
        #expect(Placement(build: .release, location: location) == .elsewhere)
    }
}
