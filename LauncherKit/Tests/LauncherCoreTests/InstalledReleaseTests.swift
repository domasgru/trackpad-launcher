import LauncherCore
import Testing

@Suite struct InstalledReleaseTests {
    private static let macOS = Version(26, 0)

    @Test func aDeveloperIDCopyInApplicationsWithAVersionHoldsItAndThisMacsMacOS() {
        let installed = InstalledRelease(placement: .installed, developerIDSigned: true, version: "1.0.0", macOS: Self.macOS)
        #expect(installed?.version == Version(1, 0, 0))
        #expect(installed?.macOS == Self.macOS)
    }

    @Test func aCopyWithoutADeveloperIDSignatureNeverQualifies() {
        #expect(InstalledRelease(placement: .installed, developerIDSigned: false, version: "1.0.0", macOS: Self.macOS) == nil)
    }

    @Test(arguments: [Placement.elsewhere, .development])
    func aCopyOutsideApplicationsNeverQualifiesEvenWhenSigned(placement: Placement) {
        #expect(InstalledRelease(placement: placement, developerIDSigned: true, version: "1.0.0", macOS: Self.macOS) == nil)
    }

    @Test(arguments: [nil, "", "1.0.0-beta", "v1.0"] as [String?])
    func aVersionThatDoesNotParseNeverQualifies(version: String?) {
        #expect(InstalledRelease(placement: .installed, developerIDSigned: true, version: version, macOS: Self.macOS) == nil)
    }
}
