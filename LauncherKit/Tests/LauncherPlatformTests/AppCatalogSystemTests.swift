import Foundation
import LauncherCore
import Testing

@testable import LauncherPlatform

/// The real catalog's names: what Finder shows, never the bundle's file name. Fixture catalogs name bundles by file.
@Suite struct AppCatalogSystemTests {
    @Test func appsAreNamedAsFinderShowsThemWithoutTheExtension() throws {
        let findMy = try #require(AppCatalog.system.entry(at: URL(filePath: "/System/Applications/FindMy.app")))

        // English "Find My"; localized elsewhere, but never the file name and never with ".app".
        #expect(findMy.name != "FindMy")
        #expect(!findMy.name.hasSuffix(".app"))
    }
}
