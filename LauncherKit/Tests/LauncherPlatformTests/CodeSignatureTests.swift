import Foundation
import LauncherCore
import Testing

@testable import LauncherPlatform

private final class Anchor {}

@Suite struct CodeSignatureTests {
    @Test func theTestsOwnAdHocBinaryIsADevelopmentBuild() throws {
        let binary = try #require(Bundle(for: Anchor.self).executableURL)
        #expect(CodeSignature.build(of: binary) == .development)
    }

    @Test func thisProcessIsReleaseOnlyWithTheExactArgument() {
        #expect(CodeSignature.buildOfThisProcess(arguments: []) == .development)
        #expect(CodeSignature.buildOfThisProcess(arguments: ["--as-release-build"]) == .release)
        #expect(CodeSignature.buildOfThisProcess(arguments: ["x", "--as-release-build"]) == .release)
        #expect(CodeSignature.buildOfThisProcess(arguments: ["--as-release"]) == .development)
    }

    private static func codesignAuthorities(of app: URL) -> String? {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/codesign")
        process.arguments = ["-dvv", app.path]
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = Pipe()
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    @Test func everyAppInApplicationsIsReleaseExactlyWhenCodesignSaysDeveloperID() throws {
        let apps = try FileManager.default.contentsOfDirectory(
            at: URL(filePath: "/Applications"), includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "app" }
        let readings = apps.compactMap { app in
            Self.codesignAuthorities(of: app).map { (app, $0.contains("Authority=Developer ID Application")) }
        }
        guard readings.contains(where: \.1), readings.contains(where: { !$0.1 }) else { return }

        for (app, isDeveloperID) in readings {
            #expect(CodeSignature.build(of: app) == (isDeveloperID ? .release : .development), "\(app.lastPathComponent)")
        }
    }

    @Test func theAdHocSignedTestRunnerHasNoDeveloperIDSignerEvenWhenItIsToldItIsARelease() {
        #expect(CodeSignature.developerIDSigner() == nil)
        #expect(CodeSignature.buildOfThisProcess(arguments: ["--as-release-build"]) == .release)
    }

    private static func line(_ name: String, in report: String) -> String? {
        report.split(separator: "\n").first { $0.hasPrefix("\(name)=") }.map { String($0.dropFirst(name.count + 1)) }
    }

    private static func expectedSigner(_ report: String) -> Signer? {
        guard report.contains("Authority=Developer ID Application"), let team = line("TeamIdentifier", in: report),
            let identifier = line("Identifier", in: report)
        else { return nil }
        return Signer(team: team, identifier: identifier)
    }

    @Test func everyAppInApplicationsAndSystemApplicationsHasASignerExactlyWhenCodesignNamesADeveloperID() throws {
        let apps = try ["/Applications", "/System/Applications"].flatMap {
            try FileManager.default.contentsOfDirectory(at: URL(filePath: $0), includingPropertiesForKeys: nil)
        }.filter { $0.pathExtension == "app" }
        let readings = apps.compactMap { app in Self.codesignAuthorities(of: app).map { (app, $0) } }
        guard readings.contains(where: { $0.1.contains("Authority=Developer ID Application") }) else { return }

        for (app, report) in readings {
            #expect(CodeSignature.developerIDSigner(of: app) == Self.expectedSigner(report), "\(app.lastPathComponent)")
        }
    }

    @Test(.enabled(if: UpdateFixtures.arePresent, "run Scripts/make-update-fixtures.sh to generate the fixtures"))
    func theCommittedDeveloperIDFixtureHasTheRecordedSignerAndTheAppleDevelopmentCopyHasNone() throws {
        let record = try UpdateFixtures.loadRecord()
        #expect(
            CodeSignature.developerIDSigner(of: UpdateFixtures.developerIDApp)
                == Signer(team: record.team, identifier: record.identifier))
        let report = try #require(Self.codesignAuthorities(of: UpdateFixtures.developerIDApp))
        #expect(Self.expectedSigner(report) == Signer(team: record.team, identifier: record.identifier))
        #expect(CodeSignature.developerIDSigner(of: UpdateFixtures.appleDevelopmentApp) == nil)
    }

    private static func offer(_ version: String, build: String = "1", needs macOS: String = "26.0") -> ExpectedUpdate {
        ExpectedUpdate(version: version, build: build, minimumMacOS: macOS)
    }

    @Test func anUnsignedBundleIsNeverGenuine() throws {
        let fixture = try BundleFixture()
        let app = try fixture.makeBundle(named: "TrackpadLauncher.app", in: fixture.folder("Release"), version: "1.1.0")

        #expect(!CodeSignature.isGenuine(app, as: Self.offer("1.1.0"), signer: Signer(team: "ABCDE12345", identifier: BundleFixture.identifier)))
    }

    @Test func aSignerWhoseNamesCouldBreakOutOfTheRequirementIsNeverMatched() throws {
        let fixture = try BundleFixture()
        let app = try fixture.makeBundle(named: "TrackpadLauncher.app", in: fixture.folder("Release"), version: "1.1.0")

        #expect(!CodeSignature.isGenuine(app, as: Self.offer("1.1.0"), signer: Signer(team: "x\" or anchor apple or \"", identifier: "y")))
    }

    @Test(.enabled(if: UpdateFixtures.arePresent, "run Scripts/make-update-fixtures.sh to generate the fixtures"))
    func onlyTheNotarisedDeveloperIDFixtureOfTheOfferedVersionAndSignerIsGenuine() throws {
        let record = try UpdateFixtures.loadRecord()
        let signer = Signer(team: record.team, identifier: record.identifier)
        let offered = Self.offer(record.version, needs: record.minimumMacOS)

        #expect(CodeSignature.isGenuine(UpdateFixtures.developerIDApp, as: offered, signer: signer))
        #expect(!CodeSignature.isGenuine(UpdateFixtures.developerIDApp, as: Self.offer("9.9.9", needs: record.minimumMacOS), signer: signer))
        #expect(!CodeSignature.isGenuine(UpdateFixtures.developerIDApp, as: Self.offer(record.version, needs: "99.0"), signer: signer))
        #expect(!CodeSignature.isGenuine(UpdateFixtures.developerIDApp, as: Self.offer(record.version, build: "2", needs: record.minimumMacOS), signer: signer))
        #expect(!CodeSignature.isGenuine(UpdateFixtures.developerIDApp, as: offered, signer: Signer(team: "AAAAAAAAAA", identifier: record.identifier)))
        #expect(!CodeSignature.isGenuine(UpdateFixtures.developerIDApp, as: offered, signer: Signer(team: record.team, identifier: "com.example.other")))
        #expect(!CodeSignature.isGenuine(UpdateFixtures.appleDevelopmentApp, as: offered, signer: signer))
    }
}
