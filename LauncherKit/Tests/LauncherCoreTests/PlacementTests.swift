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
        "/Applications/TrackpadApp.app/",
        "/Applications/Utilities/TrackpadApp.app/",
    ])
    func aCopyInsideApplicationsIsInstalledWhateverItsBuild(path: String) {
        #expect(Placement(build: .release, location: Self.location(path)) == .installed)
        #expect(Placement(build: .development, location: Self.location(path)) == .installed)
    }

    @Test(arguments: [
        Self.location("/ApplicationsOld/TrackpadApp.app/"),
        Self.location("/Applications/../Users/me/Downloads/TrackpadApp.app/"),
        Self.location("/Users/me/Applications/TrackpadApp.app/"),
        Self.location("/Users/me/Applications/Tools/TrackpadApp.app/"),
        Self.location("/Users/me/Downloads/TrackpadApp.app/"),
        Self.location("/Volumes/Trackpad App/TrackpadApp.app/", image: "/Volumes/Trackpad App"),
    ])
    func aCopyOutsideApplicationsIsElsewhereOrDevelopment(location: Location) {
        #expect(Placement(build: .release, location: location) == .elsewhere)
        #expect(Placement(build: .development, location: location) == .development)
    }

    @Test func aTranslocatedCopyIsNeverInstalledEvenWhenItsOriginalIs() {
        let location = Self.location(
            "/private/var/folders/xx/AppTranslocation/ABC/d/TrackpadApp.app/", translocated: true,
            original: "/Applications/TrackpadApp.app/")

        #expect(Placement(build: .release, location: location) == .elsewhere)
        #expect(Placement(build: .development, location: location) == .development)
    }
}
