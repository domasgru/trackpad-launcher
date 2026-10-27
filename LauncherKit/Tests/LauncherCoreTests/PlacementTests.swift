import Foundation
import LauncherCore
import Testing

@Suite struct PlacementTests {
    private static func location(_ path: String, translocated: Bool = false, original: String? = nil, image: String? = nil)
        -> Location
    {
        Location(
            running: URL(filePath: path), original: URL(filePath: original ?? path), isTranslocated: translocated,
            diskImage: image.map { DiskImage(volume: URL(filePath: $0)) })
    }

    @Test(arguments: [
        "/Applications/TrackpadLauncher.app/",
        "/Applications/Utilities/TrackpadLauncher.app/",
    ])
    func aCopyInsideApplicationsIsInstalledWhateverItsBuild(path: String) {
        #expect(Placement(build: .release, location: Self.location(path)) == .installed)
        #expect(Placement(build: .development, location: Self.location(path)) == .installed)
    }

    @Test(arguments: [
        Self.location("/ApplicationsOld/TrackpadLauncher.app/"),
        Self.location("/Applications/../Users/me/Downloads/TrackpadLauncher.app/"),
        Self.location("/Users/me/Applications/TrackpadLauncher.app/"),
        Self.location("/Users/me/Applications/Tools/TrackpadLauncher.app/"),
        Self.location("/Users/me/Downloads/TrackpadLauncher.app/"),
        Self.location("/Volumes/Trackpad Launcher/TrackpadLauncher.app/", image: "/Volumes/Trackpad Launcher"),
    ])
    func aCopyOutsideApplicationsIsElsewhereOrDevelopment(location: Location) {
        #expect(Placement(build: .release, location: location) == .elsewhere)
        #expect(Placement(build: .development, location: location) == .development)
    }

    @Test func aTranslocatedCopyIsNeverInstalledEvenWhenItsOriginalIs() {
        let location = Self.location(
            "/private/var/folders/xx/AppTranslocation/ABC/d/TrackpadLauncher.app/", translocated: true,
            original: "/Applications/TrackpadLauncher.app/")

        #expect(Placement(build: .release, location: location) == .elsewhere)
        #expect(Placement(build: .development, location: location) == .development)
    }
}
