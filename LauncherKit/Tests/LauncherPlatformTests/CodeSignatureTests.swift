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
}
