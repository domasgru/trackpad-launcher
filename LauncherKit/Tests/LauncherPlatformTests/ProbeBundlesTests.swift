import AppKit
import Foundation
import Testing

extension RealAppTests {
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

        @Test func aProbeStillStartingUpWhenCleanUpRunsIsKilledToo() async throws {
            let directory = try await ProbeBundles.withProbes { probes -> URL in
                let bundle = probes.make(["preSleep": 30])
                NSWorkspace.shared.openApplication(
                    at: bundle.url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
                var spawned = false
                for _ in 0..<500 where !spawned {
                    spawned = Self.processes(in: probes.directory)
                    if !spawned { try await Task.sleep(for: .milliseconds(20)) }
                }
                #expect(spawned, "the probe process is running its slow start")
                return probes.directory
            }

            #expect(!Self.processes(in: directory), "no process runs from the probe directory")
        }

        private static func processes(in directory: URL) -> Bool {
            let pgrep = Process()
            pgrep.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
            pgrep.arguments = ["-f", directory.path]
            pgrep.standardOutput = FileHandle.nullDevice
            try! pgrep.run()
            pgrep.waitUntilExit()
            return pgrep.terminationStatus == 0
        }

        @Test func aBundleWithoutItsExecutableIsRefused() async {
            await ProbeBundles.withProbes { probes in
                let bundle = probes.makeWithoutExecutable()
                // No "damaged or incomplete" alert on the user's screen: the refusal is all this row needs.
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.promptsUserIfNeeded = false
                let opened = try? await NSWorkspace.shared.openApplication(at: bundle.url, configuration: configuration)
                #expect(opened == nil, "macOS refuses to open a bundle with no executable")
            }
        }
    }
}
