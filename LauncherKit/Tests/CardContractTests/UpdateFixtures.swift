import Foundation

/// The committed fixtures of a genuine release, kept beside the platform tests and read from there. Tests that need
/// them are skipped while they are absent.
enum UpdateFixtures {
    static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().appending(path: "LauncherPlatformTests/UpdateFixtures")

    static let developerIDApp = folder.appending(path: "DeveloperID/TrackpadLauncher.app")
    static let archive = folder.appending(path: "TrackpadLauncher-fixture.aar")
    static let record = folder.appending(path: "fixture.json")

    static var arePresent: Bool {
        [developerIDApp, archive, record].allSatisfy { FileManager.default.fileExists(atPath: $0.path) }
    }

    struct Record: Decodable {
        let version: String
        let minimumMacOS: String
        let team: String
        let identifier: String
        let manifest: [String: String]
    }

    static func loadRecord() throws -> Record {
        try JSONDecoder().decode(Record.self, from: Data(contentsOf: record))
    }
}
