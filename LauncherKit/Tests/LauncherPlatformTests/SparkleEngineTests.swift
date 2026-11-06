import Foundation
import LauncherCore
import Testing

@testable import LauncherPlatform

@Suite struct SparkleEngineTests {
    @Test(arguments: [
        (domain: "SUSparkleErrorDomain", code: 1001, outcome: CycleOutcome.nothingNew),
        (domain: "SUSparkleErrorDomain", code: 2001, outcome: .requestFailed),
        (domain: "SUSparkleErrorDomain", code: 1000, outcome: .failed),
        (domain: "SUSparkleErrorDomain", code: 1002, outcome: .failed),
        (domain: "SUSparkleErrorDomain", code: 2000, outcome: .failed),
        (domain: "SUSparkleErrorDomain", code: 3001, outcome: .failed),
        (domain: "SUSparkleErrorDomain", code: 4005, outcome: .failed),
        (domain: "SUSparkleErrorDomain", code: 4007, outcome: .failed),
        (domain: "SUSparkleErrorDomain", code: 4008, outcome: .failed),
        (domain: "NSURLErrorDomain", code: 2001, outcome: .failed),
    ])
    func aCycleEndsAsItsSparkleErrorSays(row: (domain: String, code: Int, outcome: CycleOutcome)) {
        let error = NSError(domain: row.domain, code: row.code)

        #expect(SparkleEngine.outcome(of: error) == row.outcome)
    }

    @Test func noErrorIsNothingNew() {
        #expect(SparkleEngine.outcome(of: nil) == .nothingNew)
    }

    private static let github = "https://github.com/domasgru/trackpad-launcher/releases/download/"
    private static let local = "http://127.0.0.1:8765/v2/"

    @Test func theShippedEnclosureAndALocalOneUnderTheirPrefixesArePinned() {
        let release = URL(string: Self.github + "v1.2.3/TrackpadLauncher-1.2.3-macOS-26.0.aar")
        let stand = URL(string: Self.local + "TrackpadLauncher-2-macOS-26.0.aar")

        #expect(isPinned(enclosure: release, under: Self.github))
        #expect(isPinned(enclosure: stand, under: "http://127.0.0.1:8765/v2/"))
    }

    @Test(arguments: [
        "https://example.com/domasgru/trackpad-launcher/releases/download/v1/App.aar",
        "https://github.com/someone/else/releases/download/v1/App.aar",
        "https://github.com/domasgru/trackpad-launcher/releases/download-x/v1/App.aar",
        "https://github.com/domasgru/trackpad-launcher/releases/download/v1/App.dmg",
        "http://github.com/domasgru/trackpad-launcher/releases/download/v1/App.aar",
        "https://github.com/domasgru/trackpad-launcher/releases/download/v1/App.dmg?.aar",
        "https://github.com/domasgru/trackpad-launcher/releases/download/../../x/App.aar",
        "https://github.com/domasgru/trackpad-launcher/releases/download/%2e%2e/x/App.aar",
        "https://github.com/domasgru/trackpad-launcher/releases/download/%2E./x/App.aar",
    ])
    func everyOtherEnclosureIsRefused(address: String) {
        #expect(!isPinned(enclosure: URL(string: address), under: Self.github))
    }

    @Test func aMissingEnclosureOrPrefixAdmitsNothing() {
        let release = URL(string: Self.github + "v1/App.aar")

        #expect(!isPinned(enclosure: nil, under: Self.github))
        #expect(!isPinned(enclosure: release, under: nil))
    }

    @Test func aWritableBundleCanReplaceItselfAndTheListingNeverChanges() throws {
        let parent = FileManager.default.temporaryDirectory.appending(path: "tl-replace-\(UUID().uuidString)")
        let bundle = parent.appending(path: "App.app")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: parent.path)
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bundle.path)
            try? FileManager.default.removeItem(at: parent)
        }
        let listing = { try FileManager.default.contentsOfDirectory(atPath: parent.path) }
        let before = try listing()

        #expect(SparkleEngine.canReplace(bundle))

        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: bundle.path)
        #expect(!SparkleEngine.canReplace(bundle))

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bundle.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: parent.path)
        #expect(!SparkleEngine.canReplace(bundle))

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: parent.path)
        #expect(try listing() == before)
    }

    @Test func aSystemBundleCannotReplaceItself() {
        #expect(!SparkleEngine.canReplace(URL(filePath: "/System/Applications/Calculator.app")))
    }

    @Test func sparkleInternalsWereProvenOnThePinnedVersion() throws {
        let resolved = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Package.resolved")
        let json = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: resolved)) as? [String: Any])
        let pins = try #require(json["pins"] as? [[String: Any]])
        let sparkle = try #require(pins.first { $0["identity"] as? String == "sparkle" })
        let state = try #require(sparkle["state"] as? [String: Any])

        #expect(SparkleInternals.provenOn == state["version"] as? String)
    }
}
