import Foundation
import LauncherCore
import Testing

@testable import LauncherPlatform

@Suite struct SparkleEngineTests {
    struct OutcomeRow: Sendable, CustomTestStringConvertible {
        let kind: CycleKind
        let domain: String?
        let code: Int
        let feedRead: Bool
        let found: AppVersion?
        let outcome: CycleOutcome
        var testDescription: String {
            "\(kind) \(domain ?? "no error") \(code) feedRead=\(feedRead) found=\(found?.description ?? "nothing")"
        }
    }

    private static let sparkle = "SUSparkleErrorDomain"

    nonisolated static let outcomes: [OutcomeRow] = [
        OutcomeRow(kind: .probe, domain: nil, code: 0, feedRead: true, found: AppVersion("1.1.23"), outcome: .found(AppVersion("1.1.23"))),
        OutcomeRow(kind: .probe, domain: nil, code: 0, feedRead: true, found: nil, outcome: .nothingNew),
        OutcomeRow(kind: .probe, domain: sparkle, code: 1001, feedRead: true, found: nil, outcome: .nothingNew),
        OutcomeRow(kind: .probe, domain: sparkle, code: 2001, feedRead: false, found: nil, outcome: .requestFailed),
        OutcomeRow(kind: .probe, domain: sparkle, code: 2001, feedRead: true, found: nil, outcome: .requestFailed),
        OutcomeRow(kind: .probe, domain: sparkle, code: 1000, feedRead: false, found: nil, outcome: .failed),
        OutcomeRow(kind: .probe, domain: sparkle, code: 4005, feedRead: true, found: AppVersion("1.1.23"), outcome: .failed),
        OutcomeRow(kind: .probe, domain: sparkle, code: 4007, feedRead: true, found: nil, outcome: .failed),
        OutcomeRow(kind: .probe, domain: "NSURLErrorDomain", code: 2001, feedRead: false, found: nil, outcome: .failed),
        OutcomeRow(kind: .update, domain: sparkle, code: 1001, feedRead: true, found: nil, outcome: .nothingNew),
        OutcomeRow(kind: .update, domain: sparkle, code: 2001, feedRead: false, found: nil, outcome: .requestFailed),
        OutcomeRow(kind: .update, domain: nil, code: 0, feedRead: true, found: AppVersion("1.1.23"), outcome: .failed),
        OutcomeRow(kind: .update, domain: sparkle, code: 2001, feedRead: true, found: AppVersion("1.1.23"), outcome: .failed),
        OutcomeRow(kind: .update, domain: sparkle, code: 3001, feedRead: true, found: AppVersion("1.1.23"), outcome: .failed),
        OutcomeRow(kind: .update, domain: sparkle, code: 4004, feedRead: true, found: AppVersion("1.1.23"), outcome: .failed),
        OutcomeRow(kind: .update, domain: sparkle, code: 4005, feedRead: true, found: AppVersion("1.1.23"), outcome: .failed),
        OutcomeRow(kind: .update, domain: sparkle, code: 4007, feedRead: true, found: AppVersion("1.1.23"), outcome: .cancelled),
        OutcomeRow(kind: .update, domain: sparkle, code: 4008, feedRead: true, found: AppVersion("1.1.23"), outcome: .failed),
        OutcomeRow(kind: .update, domain: "NSURLErrorDomain", code: 2001, feedRead: false, found: nil, outcome: .failed),
    ]

    @Test(arguments: outcomes)
    func aCycleEndsAsItsKindAndSparkleErrorSay(row: OutcomeRow) {
        let error = row.domain.map { NSError(domain: $0, code: row.code) }

        #expect(
            SparkleEngine.outcome(of: error, kind: row.kind, feedRead: row.feedRead, found: row.found) == row.outcome)
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

    private struct Manifest: Decodable {
        let tag: String
        let flags: [String]
    }

    private static func vendoredManifest() throws -> Manifest {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Vendor/Sparkle/manifest.json")
        return try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
    }

    @Test func sparkleInternalsWereProvenOnTheVendoredTag() throws {
        let manifest = try Self.vendoredManifest()

        #expect(SparkleInternals.provenOn == manifest.tag)
        #expect(manifest.flags.contains("SPARKLE_BUILD_UI_BITS=0"))
    }

    @Test @MainActor func touchingSparkleBringsNoWebKitWithIt() throws {
        let engine = SparkleEngine(bundle: Bundle.main.bundleURL, signer: Signer(team: "TEAM", identifier: "id"))
        withExtendedLifetime(engine) {}

        #expect(NSClassFromString("SPUUpdater") != nil, "the Sparkle framework is loaded")
        let sparkle = try #require(Self.imageIndex(endingWith: "Sparkle.framework/Versions/B/Sparkle"))
        let closure = Self.dependencyClosure(ofImage: sparkle)
        #expect(closure.contains { $0.hasSuffix("Foundation.framework/Versions/C/Foundation") }, "the walk reaches Foundation")
        #expect(!closure.contains { $0.contains("WebKit.framework") }, "Sparkle's dependencies hold no WebKit")
        #expect(!closure.contains { $0.contains("AppKit.framework") }, "Sparkle's dependencies hold no AppKit")
    }

    private static func imageIndex(endingWith suffix: String) -> UInt32? {
        (0..<_dyld_image_count()).first { index in
            _dyld_get_image_name(index).map { String(cString: $0).hasSuffix(suffix) } ?? false
        }
    }

    /// Install names a loaded image links, read from its load commands.
    private static func linkedNames(ofImage index: UInt32) -> [String] {
        guard let header = _dyld_get_image_header(index) else { return [] }
        let machHeader = UnsafeRawPointer(header).assumingMemoryBound(to: mach_header_64.self)
        var command = UnsafeRawPointer(machHeader.advanced(by: 1))
        var names: [String] = []
        let linking: Set<UInt32> = [
            UInt32(LC_LOAD_DYLIB), UInt32(LC_LOAD_WEAK_DYLIB), UInt32(LC_REEXPORT_DYLIB), UInt32(LC_LAZY_LOAD_DYLIB),
        ]
        for _ in 0..<machHeader.pointee.ncmds {
            let load = command.assumingMemoryBound(to: load_command.self).pointee
            if linking.contains(load.cmd) {
                let dylib = command.assumingMemoryBound(to: dylib_command.self).pointee
                let name = (command + Int(dylib.dylib.name.offset)).assumingMemoryBound(to: CChar.self)
                names.append(String(cString: name))
            }
            command += Int(load.cmdsize)
        }
        return names
    }

    private static func dependencyClosure(ofImage root: UInt32) -> Set<String> {
        var seen: Set<String> = []
        var pending = linkedNames(ofImage: root)
        while let name = pending.popLast() {
            guard seen.insert(name).inserted else { continue }
            let tail = name.hasPrefix("@rpath/") ? String(name.dropFirst("@rpath/".count)) : name
            if let index = imageIndex(endingWith: tail) { pending += linkedNames(ofImage: index) }
        }
        return seen
    }
}
