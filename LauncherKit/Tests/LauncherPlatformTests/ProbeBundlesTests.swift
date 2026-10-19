import AppKit
import Foundation
import Testing

/// The probe bundle helper end to end, against a real launch through LaunchServices.
@MainActor @Suite(.serialized) struct ProbeBundlesTests {
    @Test func aProbeLaunchesAndCleanUpRemovesEverything() async throws {
        let launched = try await ProbeBundles.withProbes { probes -> (id: String, directory: URL, finished: Bool) in
            let bundle = probes.make(["windowDidFinish": true])
            let app = try await NSWorkspace.shared.openApplication(
                at: bundle.url, configuration: NSWorkspace.OpenConfiguration())
            let finished = await ProbeBundles.finishedLaunching(app, within: .seconds(10))
            return (bundle.id, probes.directory, finished)
        }

        #expect(launched.finished, "the probe finishes launching within 10 s")
        #expect(NSRunningApplication.runningApplications(withBundleIdentifier: launched.id).isEmpty, "the process is gone")
        #expect(!FileManager.default.fileExists(atPath: launched.directory.path), "the bundle directory is deleted")
    }

    @Test func aBundleWithoutItsExecutableIsRefused() async {
        await ProbeBundles.withProbes { probes in
            let bundle = probes.makeWithoutExecutable()
            let opened = try? await NSWorkspace.shared.openApplication(
                at: bundle.url, configuration: NSWorkspace.OpenConfiguration())
            #expect(opened == nil, "macOS refuses to open a bundle with no executable")
        }
    }
}
