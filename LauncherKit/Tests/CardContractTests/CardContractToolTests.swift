import Foundation
import Testing

@Suite struct CardContractToolTests {
    struct Outcome {
        let status: Int32
        let output: Data
        let error: String
    }

    static let contractName = "TrackpadLauncher-1.0.0-macOS-26.0.aar"

    /// The built tool sits beside the test bundle, in the same products folder.
    static var tool: URL {
        Bundle(for: TestBundleLocator.self).bundleURL.deletingLastPathComponent().appending(path: "card-contract")
    }

    static func run(_ arguments: [String]) throws -> Outcome {
        let process = Process()
        process.executableURL = tool
        process.arguments = arguments
        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        let waitForExit = try process.start()
        let out = output.fileHandleForReading.readDataToEndOfFile()
        let err = error.fileHandleForReading.readDataToEndOfFile()
        waitForExit()
        return Outcome(status: process.terminationStatus, output: out, error: String(decoding: err, as: UTF8.self))
    }

    static func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "tl-contract-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func fixtureArchive(named name: String = contractName, in folder: URL) throws -> URL {
        let copy = folder.appending(path: name)
        try FileManager.default.copyItem(at: UpdateFixtures.archive, to: copy)
        return copy
    }

    @Test(.enabled(if: UpdateFixtures.arePresent, "the committed update fixtures are not generated yet"))
    func theFixtureArchiveUnderAContractNameWithItsRecordedSignerIsAccepted() throws {
        let folder = try Self.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let record = try UpdateFixtures.loadRecord()
        let archive = try Self.fixtureArchive(in: folder)

        let outcome = try Self.run([archive.path, "--team", record.team, "--identifier", record.identifier])

        #expect(outcome.status == 0, "\(outcome.error)")
        #expect(outcome.output.isEmpty)
        #expect(outcome.error.isEmpty)
    }

    @Test(.enabled(if: UpdateFixtures.arePresent, "the committed update fixtures are not generated yet"))
    func anotherTeamIsRefused() throws {
        let folder = try Self.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let record = try UpdateFixtures.loadRecord()
        let archive = try Self.fixtureArchive(in: folder)

        let outcome = try Self.run([archive.path, "--team", "AAAAAAAAAA", "--identifier", record.identifier])

        #expect(outcome.status != 0)
        #expect(outcome.output.isEmpty)
        #expect(!outcome.error.isEmpty)
    }

    @Test(.enabled(if: UpdateFixtures.arePresent, "the committed update fixtures are not generated yet"))
    func aNameOffTheContractIsRefused() throws {
        let folder = try Self.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let record = try UpdateFixtures.loadRecord()
        let archive = try Self.fixtureArchive(named: "Fixture.aar", in: folder)

        let outcome = try Self.run([archive.path, "--team", record.team, "--identifier", record.identifier])

        #expect(outcome.status != 0)
        #expect(outcome.output.isEmpty)
        #expect(!outcome.error.isEmpty)
    }

    @Test(.enabled(if: UpdateFixtures.arePresent, "the committed update fixtures are not generated yet"))
    func anArchiveWithARefusedEntryIsRefused() throws {
        let folder = try Self.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let record = try UpdateFixtures.loadRecord()
        let archive = folder.appending(path: Self.contractName)
        try CraftedArchive.make(CraftedArchive.entries(of: UpdateFixtures.developerIDApp) + [.file("TrackpadLauncher.app/../escape", Data())]).write(to: archive)

        let outcome = try Self.run([archive.path, "--team", record.team, "--identifier", record.identifier])

        #expect(outcome.status != 0)
        #expect(outcome.output.isEmpty)
        #expect(!outcome.error.isEmpty)
    }

    @Test func badUsageIsRefused() throws {
        let outcome = try Self.run(["only-an-archive"])

        #expect(outcome.status != 0)
        #expect(outcome.output.isEmpty)
        #expect(!outcome.error.isEmpty)
    }
}

private final class TestBundleLocator {}
