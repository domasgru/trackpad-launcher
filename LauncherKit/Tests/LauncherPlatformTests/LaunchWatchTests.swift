import AppKit
import LauncherCore
import Testing

@testable import LauncherPlatform

extension RealAppTests {
    /// The watch with macOS's answer withheld and injected by the test, which opens the probe itself.
    @MainActor @Suite(.serialized) struct LaunchWatchTests {
        @MainActor private final class Reports {
            var seen: [LaunchProgress] = []
        }

        private func open(_ bundle: ProbeBundles.Bundle) async -> NSRunningApplication? {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.promptsUserIfNeeded = false
            return try? await NSWorkspace.shared.openApplication(at: bundle.url, configuration: configuration)
        }

        private func settle() async { try? await Task.sleep(for: .milliseconds(500)) }

        @Test func aPidDeliveredAfterTheAppFinishedLaunchingStillReportsItOnce() async {
            await ProbeBundles.withProbes { probes in
                let reports = Reports()
                let watch = LaunchWatch { reports.seen.append($0) }
                guard let app = await open(probes.make(menuBarApp: true)) else {
                    Issue.record("did not open")
                    return
                }
                #expect(await ProbeBundles.finishedLaunching(app, within: .seconds(10)))

                watch.opened(app.processIdentifier)
                await settle()

                #expect(reports.seen == [.finishedLaunching])
                watch.stop()
            }
        }

        @Test func aPidDeliveredAfterTheAppWasKilledReportsWentNowhere() async {
            await ProbeBundles.withProbes { probes in
                let reports = Reports()
                let watch = LaunchWatch { reports.seen.append($0) }
                guard let app = await open(probes.make(menuBarApp: true)) else {
                    Issue.record("did not open")
                    return
                }
                let pid = app.processIdentifier
                app.forceTerminate()
                #expect(await ProbeBundles.terminated(app, within: .seconds(5)))

                watch.opened(pid)
                await settle()

                #expect(reports.seen == [.wentNowhere])
                watch.stop()
            }
        }

        @Test func aMissingPidReportsWentNowhere() async {
            let reports = Reports()
            let watch = LaunchWatch { reports.seen.append($0) }

            watch.opened(nil)
            await settle()

            #expect(reports.seen == [.wentNowhere])
        }

        @Test func aStopBetweenTheAdoptionAndTheFinishingHopReportsNothing() async {
            await ProbeBundles.withProbes { probes in
                let reports = Reports()
                let watch = LaunchWatch { reports.seen.append($0) }
                guard let app = await open(probes.make(menuBarApp: true)) else {
                    Issue.record("did not open")
                    return
                }
                #expect(await ProbeBundles.finishedLaunching(app, within: .seconds(10)))

                watch.opened(app.processIdentifier)
                Task { @MainActor in watch.stop() }
                await settle()

                #expect(reports.seen.isEmpty)
            }
        }

        @Test func aStopBeforeThePidArrivesReportsNothingEvenAfterTheAppFinishedLaunching() async {
            await ProbeBundles.withProbes { probes in
                let reports = Reports()
                let watch = LaunchWatch { reports.seen.append($0) }
                guard let app = await open(probes.make(["preSleep": 0.5], menuBarApp: true)) else {
                    Issue.record("did not open")
                    return
                }

                watch.stop()
                watch.opened(app.processIdentifier)
                #expect(await ProbeBundles.finishedLaunching(app, within: .seconds(10)))
                try? await Task.sleep(for: .seconds(1))

                #expect(reports.seen.isEmpty)
            }
        }
    }
}
