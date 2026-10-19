import AppKit
import ApplicationServices
import LauncherCore
import Testing

@testable import LauncherPlatform

/// An independent read of when a probe's first window is on screen: the window list, polled every 2 ms off the main
/// actor. Polling is for tests only.
private enum WindowClock {
    @concurrent static func firstOnScreen(of pid: pid_t, within bound: Duration) async -> ContinuousClock.Instant? {
        let deadline = ContinuousClock.now + bound
        while ContinuousClock.now < deadline {
            let all = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
            let onScreen = all.contains {
                ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid
                    && ($0[kCGWindowLayer as String] as? NSNumber)?.intValue == 0
            }
            if onScreen { return .now }
            try? await Task.sleep(for: .milliseconds(2))
        }
        return nil
    }

    /// The instant the bundle's first window is on screen, once macOS lists its process.
    @MainActor static func firstOnScreen(of bundle: ProbeBundles.Bundle, within bound: Duration) async
        -> ContinuousClock.Instant?
    {
        guard let app = await ProbeBundles.listed(bundle, within: .seconds(5)) else { return nil }
        return await firstOnScreen(of: app.processIdentifier, within: bound)
    }
}

/// Windows ending a launch bounce, through real probe apps. The rows that need Accessibility are skipped without it.
/// They extend the adapter suite so that they run one at a time with its rows: concurrent probes steal focus and
/// slow each other's startup.
extension LaunchBounceAdapterTests {
    @MainActor private final class Reports {
        var seen: [LaunchProgress] = []
        var times: [ContinuousClock.Instant] = []
        func add(_ progress: LaunchProgress) {
            seen.append(progress)
            times.append(.now)
        }
    }

    nonisolated private static var isTrusted: Bool { AXIsProcessTrusted() }

    private func open(_ bundle: ProbeBundles.Bundle) async -> NSRunningApplication? {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.promptsUserIfNeeded = false
        return try? await NSWorkspace.shared.openApplication(at: bundle.url, configuration: configuration)
    }

    private func settle(_ duration: Duration = .milliseconds(500)) async { try? await Task.sleep(for: duration) }

    @Test func lookEndsTheBounceOnAnyWindowAndOtherwiseWatchesOnlyWhenRegistered() {
        #expect(LaunchWatch.look(.registered, axWindows: 1, listedWindows: 0) == .shown)
        #expect(LaunchWatch.look(.registered, axWindows: 0, listedWindows: 1) == .shown)
        #expect(LaunchWatch.look(.noAccess, axWindows: 0, listedWindows: 1) == .shown)
        #expect(LaunchWatch.look(.notAnswering, axWindows: 0, listedWindows: 1) == .shown)
        #expect(LaunchWatch.look(.registered, axWindows: 0, listedWindows: 0) == .watching)
        #expect(LaunchWatch.look(.noAccess, axWindows: 0, listedWindows: 0) == .blind)
        #expect(LaunchWatch.look(.notAnswering, axWindows: 0, listedWindows: 0) == .blind)
    }

    @Test(.enabled(if: isTrusted), arguments: ["windowDidFinish", "windowWillFinish"])
    func aWindowMadeAtStartupEndsTheBounceWithinFiftyMillisecondsOfShowing(_ key: String) async {
        await ProbeBundles.withProbes { probes in
            let bench = BounceBench()
            bench.log.endings[.windowShown] = .launchAnimation
            let probe = probes.make([key: true])
            defer { bench.tearDown([probe]) }

            bench.actions.bringToFrontBouncing(bench.entry(probe), cap: .seconds(10))
            async let shown = WindowClock.firstOnScreen(of: probe, within: .seconds(10))
            let arrived = await bench.log.wait(forCount: 2, within: .seconds(10))
            let onScreen = await shown
            await settle()

            #expect(arrived)
            #expect(bench.log.progresses == [.finishedLaunching, .windowShown])
            if let onScreen, bench.log.entries.count == 2 {
                let lag = elapsed(from: onScreen, to: bench.log.entries[1].at)
                #expect(lag <= 0.05, "reported \(lag) s after the window was on screen")
            }
        }
    }

    @Test(.enabled(if: isTrusted))
    func aWindowOpeningLongAfterFinishingEndsTheBounceWhenItShows() async {
        await ProbeBundles.withProbes { probes in
            let bench = BounceBench()
            bench.log.endings[.windowShown] = .launchAnimation
            let probe = probes.make(["windowAfter": 1.5])
            defer { bench.tearDown([probe]) }

            bench.actions.bringToFrontBouncing(bench.entry(probe), cap: .seconds(10))
            async let shown = WindowClock.firstOnScreen(of: probe, within: .seconds(10))
            let arrived = await bench.log.wait(forCount: 2, within: .seconds(10))
            let onScreen = await shown

            #expect(arrived)
            #expect(bench.log.progresses == [.finishedLaunching, .windowShown])
            if let onScreen, bench.log.entries.count == 2 {
                let lag = elapsed(from: onScreen, to: bench.log.entries[1].at)
                #expect(abs(lag) <= 0.05, "reported \(lag) s after the window was on screen")
                let gap = elapsed(from: bench.log.entries[0].at, to: bench.log.entries[1].at)
                #expect(gap > 1, "not at finishing: \(gap) s later")
            }
        }
    }

    @Test(.enabled(if: isTrusted))
    func aSplashEndsTheBounceOnceAndNothingMoreArrivesForTheMainWindowOrTheCap() async {
        await ProbeBundles.withProbes { probes in
            let bench = BounceBench()
            let probe = probes.make(["splash": true, "windowAfter": 1])
            defer { bench.tearDown([probe]) }

            bench.actions.bringToFrontBouncing(bench.entry(probe), cap: .milliseconds(1500))
            async let shown = WindowClock.firstOnScreen(of: probe, within: .seconds(10))
            let arrived = await bench.log.wait(forCount: 2, within: .seconds(10))
            let onScreen = await shown
            await settle(.seconds(3))

            #expect(arrived)
            #expect(bench.log.progresses == [.finishedLaunching, .windowShown])
            if let onScreen, bench.log.entries.count >= 2 {
                let lag = elapsed(from: onScreen, to: bench.log.entries[1].at)
                #expect(lag <= 0.05, "reported \(lag) s after the splash was on screen")
            }
        }
    }

    @Test(.enabled(if: isTrusted))
    func aStopFromInsideTheFinishingReportKeepsTheLookFromReportingAnything() async {
        await ProbeBundles.withProbes { probes in
            let reports = Reports()
            let box = WatchBox()
            let watch = LaunchWatch { progress in
                reports.add(progress)
                if progress == .finishedLaunching { box.watch?.stop() }
            }
            box.watch = watch
            guard let app = await open(probes.make(["windowDidFinish": true])) else {
                Issue.record("did not open")
                return
            }

            watch.opened(app.processIdentifier)
            await settle(.seconds(1))

            #expect(reports.seen == [.finishedLaunching])
        }
    }

    @MainActor private final class WatchBox {
        var watch: LaunchWatch?
    }

    @Test(.enabled(if: isTrusted))
    func aLaunchingAppThatDoesNotAnswerStallsTheMainActorForNoMoreThanTheMessagingTimeout() async {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0)
        defer { AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.2) }
        await ProbeBundles.withProbes { probes in
            let marker = probes.directory.appending(path: "marker")
            let reports = Reports()
            let watch = LaunchWatch { reports.add($0) }
            let probe = probes.make(["markerThenBlock": ["marker": marker.path, "seconds": 3]])
            guard let app = await open(probe) else {
                Issue.record("did not open")
                return
            }
            let deadline = ContinuousClock.now + .seconds(10)
            while !FileManager.default.fileExists(atPath: marker.path), ContinuousClock.now < deadline {
                await settle(.milliseconds(5))
            }

            watch.opened(app.processIdentifier)
            while reports.seen.isEmpty, ContinuousClock.now < deadline { await settle(.milliseconds(5)) }
            let freed = ContinuousClock.now
            let finishedAt = reports.times.first ?? freed

            #expect(reports.seen == [.finishedLaunching])
            #expect(elapsed(from: finishedAt, to: freed) < 0.5, "the main actor was held")
            await settle(.seconds(4))
            #expect(reports.seen == [.finishedLaunching], "nothing retries")
            watch.stop()
        }
    }

    @Test func theWindowListCountsTitledAndBorderlessWindowsBelowTheStatusLevelOnly() async {
        await ProbeBundles.withProbes { probes in
            let titled = probes.make(["windowDidFinish": true])
            let splash = probes.make(["splash": true])
            let status = probes.make(["statusLevelWindow": true])
            let menuBar = probes.make(menuBarApp: true)
            var apps: [NSRunningApplication] = []
            for bundle in [titled, splash, status, menuBar] {
                guard let app = await open(bundle) else {
                    Issue.record("did not open")
                    return
                }
                apps.append(app)
            }
            for app in apps.prefix(2) {
                #expect(await WindowClock.firstOnScreen(of: app.processIdentifier, within: .seconds(10)) != nil)
            }
            await settle(.seconds(1))

            #expect(LaunchWatch.listedWindows(of: apps[0].processIdentifier) == 1)
            #expect(LaunchWatch.listedWindows(of: apps[1].processIdentifier) == 1)
            #expect(LaunchWatch.listedWindows(of: apps[2].processIdentifier) == 0)
            #expect(LaunchWatch.listedWindows(of: apps[3].processIdentifier) == 0)
            #expect(LaunchWatch.listedWindows(of: 2_000_000_000) == 0)
        }
    }

    @Test(.enabled(if: isTrusted))
    func aWatchReportsTheWindowOnceWhateverOpensAfterIt() async {
        await ProbeBundles.withProbes { probes in
            let scripts: [ProbeBundles.Script] = [
                ["splash": true, "windowAfter": 1],
                ["windowAfter": [1, 1.5]],
            ]
            for script in scripts {
                let reports = Reports()
                let watch = LaunchWatch { reports.add($0) }
                guard let app = await open(probes.make(script)) else {
                    Issue.record("did not open")
                    return
                }

                watch.opened(app.processIdentifier)
                await settle(.seconds(3))

                #expect(reports.seen == [.finishedLaunching, .windowShown], "script \(script)")
                watch.stop()
            }
        }
    }
}
