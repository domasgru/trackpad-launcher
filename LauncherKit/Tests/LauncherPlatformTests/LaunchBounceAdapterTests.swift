import AppKit
import LauncherCore
import QuartzCore
import Testing

@testable import LauncherPlatform

extension RealAppTests {
    /// The real `WorkspaceActions` driving real probe apps, with the render server's own clock: rows pass short caps and
    /// limits and bound each wait. The suite moves focus to probe apps and shows icons on screen.
    @MainActor @Suite(.serialized) struct LaunchBounceAdapterTests {
        private let slowStart: ProbeBundles.Script = ["preSleep": 5]

        @Test func hasProcessIsTrueFromTheMomentMacOSListsTheProcessAndFalseOnceItIsGone() async {
            await ProbeBundles.withProbes { probes in
                let bench = BounceBench()
                let slow = probes.make(["blockInWillFinish": 3])
                let id = BundleID(rawValue: slow.id)
                #expect(!bench.actions.hasProcess(id), "a bundle never launched")

                let app = await openLikeTheDock(slow, within: .milliseconds(500))

                #expect(app != nil, "macOS lists the process within 0.5 s")
                #expect(bench.actions.hasProcess(id), "listed while it is still starting")
                #expect(app?.isFinishedLaunching == false)

                let menuBar = probes.make(menuBarApp: true)
                let menuBarProcess = await openLikeTheDock(menuBar)
                #expect(menuBarProcess != nil)
                if let menuBarProcess { _ = await ProbeBundles.finishedLaunching(menuBarProcess, within: .seconds(10)) }
                #expect(bench.actions.hasProcess(BundleID(rawValue: menuBar.id)))
                #expect(!bench.actions.runningApps().contains(menuBar.url), "the ⌘-Tab list does not show it")

                app?.forceTerminate()
                if let app { _ = await ProbeBundles.terminated(app, within: .seconds(5)) }
                #expect(!bench.actions.hasProcess(id), "gone with its process")
            }
        }

        @Test func anAppStillStartingAtTheCapEndsWithOnlyARanOutReport() async {
            await ProbeBundles.withProbes { probes in
                let bench = BounceBench()
                bench.log.endings[.ranOut] = .quietFade
                let probe = probes.make(slowStart)
                let started = ContinuousClock.now

                bench.actions.bringToFrontBouncing(bench.entry(probe), cap: .milliseconds(400))
                let arrived = await bench.log.wait(forCount: 1, within: .seconds(2))
                try? await Task.sleep(for: .seconds(1))

                #expect(arrived)
                #expect(bench.log.progresses == [.ranOut])
                let delay = elapsed(from: started, to: bench.log.entries.first?.at ?? started)
                #expect((0.4...0.9).contains(delay), "ran out at \(delay) s")
                #expect(bench.actions.hasProcess(BundleID(rawValue: probe.id)), "the app keeps starting")
            }
        }

        @Test func aMenuBarAppWithNoWindowRunsOutAtTheLimitLongBeforeTheCap() async {
            await ProbeBundles.withProbes { probes in
                let bench = BounceBench()
                bench.log.endings[.ranOut] = .launchAnimation
                bench.log.limitOnFinish = .milliseconds(300)
                let probe = probes.make(menuBarApp: true)

                bench.actions.bringToFrontBouncing(bench.entry(probe), cap: .seconds(5))
                let arrived = await bench.log.wait(forCount: 2, within: .seconds(5))

                #expect(arrived)
                #expect(bench.log.progresses == [.finishedLaunching, .ranOut])
                if bench.log.entries.count == 2 {
                    let gap = elapsed(from: bench.log.entries[0].at, to: bench.log.entries[1].at)
                    #expect((0.3...0.8).contains(gap), "ran out \(gap) s after the limit")
                }
            }
        }

        @Test func aLaterLimitNeverExtendsABounceAndWhicheverPassesFirstReportsOnce() async {
            await ProbeBundles.withProbes { probes in
                let bench = BounceBench()
                let first = probes.make(slowStart)
                let second = probes.make(slowStart)
                defer { bench.tearDown([first, second]) }

                let capFirst = ContinuousClock.now
                bench.actions.bringToFrontBouncing(bench.entry(first), cap: .milliseconds(500))
                bench.actions.limitLaunchBounce(of: BundleID(rawValue: first.id), to: .seconds(2))
                let arrived = await bench.log.wait(forCount: 1, within: .seconds(2))
                #expect(arrived)
                let delay = elapsed(from: capFirst, to: bench.log.entries.first?.at ?? capFirst)
                #expect((0.5...1.0).contains(delay), "cap passed after \(delay) s")
                try? await Task.sleep(for: .seconds(2))
                #expect(bench.log.progresses == [.ranOut], "the later limit reports nothing")

                let start = ContinuousClock.now
                bench.actions.bringToFrontBouncing(bench.entry(second), cap: .seconds(2))
                bench.actions.limitLaunchBounce(of: BundleID(rawValue: second.id), to: .milliseconds(200))
                let limited = await bench.log.wait(forCount: 2, within: .seconds(2))
                #expect(limited)
                let limitDelay = elapsed(from: start, to: bench.log.entries.last?.at ?? start)
                #expect((0.2...0.7).contains(limitDelay), "limit passed after \(limitDelay) s")
                try? await Task.sleep(for: .milliseconds(2500))
                #expect(bench.log.progresses == [.ranOut, .ranOut], "the cap passing later reports nothing more")
                #expect(Set(bench.log.entries.map(\.app.rawValue)) == [first.id, second.id])
            }
        }

        @Test func aDeadlineOfAnEndedBounceNeverRunsTheNextBounceOfTheSameAppOut() async {
            await ProbeBundles.withProbes { probes in
                let bench = BounceBench()
                let probe = probes.make(slowStart)
                let id = BundleID(rawValue: probe.id)
                defer { bench.tearDown([probe]) }

                bench.actions.bringToFrontBouncing(bench.entry(probe), cap: .milliseconds(300))
                try? await Task.sleep(for: .milliseconds(100))
                let restart = ContinuousClock.now
                bench.actions.endLaunchBounce(of: id, with: .quietFade)
                bench.actions.bringToFrontBouncing(bench.entry(probe), cap: .seconds(2))
                let early = await bench.log.wait(forCount: 1, within: .milliseconds(1800))
                #expect(!early, "nothing runs the new bounce out before its own cap")

                let late = await bench.log.wait(forCount: 1, within: .milliseconds(1000))
                #expect(late)
                let delay = elapsed(from: restart, to: bench.log.entries.first?.at ?? restart)
                #expect((2.0...2.5).contains(delay), "ran out \(delay) s after the restart")
            }
        }

        @Test func aBounceEndedBeforeMacOSAnswersHearsNothingMoreForIt() async {
            await ProbeBundles.withProbes { probes in
                let bench = BounceBench()
                let probe = probes.make(["preSleep": 0.3, "windowDidFinish": true])

                bench.actions.bringToFrontBouncing(bench.entry(probe), cap: .seconds(5))
                bench.actions.endLaunchBounce(of: BundleID(rawValue: probe.id), with: .quietFade)

                let app = await ProbeBundles.listed(probe, within: .seconds(5))
                #expect(app != nil, "macOS lists the process within 5 s")
                if let app { _ = await ProbeBundles.finishedLaunching(app, within: .seconds(10)) }
                try? await Task.sleep(for: .seconds(1))

                #expect(bench.log.entries.isEmpty)
            }
        }

        @Test func aLaunchThatCannotHappenReportsWentNowhereOnceAndNothingElse() async {
            await ProbeBundles.withProbes { probes in
                for (name, bundle) in [("no executable", probes.makeWithoutExecutable()), ("exits early", probes.make(["crashAfter": 0.5]))] {
                    let bench = BounceBench()
                    bench.log.endings[.wentNowhere] = .quietFade

                    bench.actions.bringToFrontBouncing(bench.entry(bundle), cap: .seconds(5))
                    let arrived = await bench.log.wait(forCount: 1, within: .seconds(2))
                    try? await Task.sleep(for: .milliseconds(500))

                    #expect(arrived, "\(name)")
                    #expect(bench.log.progresses == [.wentNowhere], "\(name)")
                }

                let bench = BounceBench()
                let refused = probes.makeWithoutExecutable()
                bench.actions.bringToFrontBouncing(bench.entry(refused), cap: .milliseconds(500))
                let arrived = await bench.log.wait(forCount: 1, within: .seconds(2))
                try? await Task.sleep(for: .seconds(1))
                #expect(arrived)
                #expect(bench.log.progresses == [.wentNowhere], "the cap passing later adds no second ending")
                bench.tearDown([refused])
            }
        }

        @Test func killingALaunchAtRandomReportsWentNowhereWithinASecond() async {
            let seed = UInt64.random(in: 0...UInt64.max)
            var generator = SplitMix(state: seed)
            await ProbeBundles.withProbes { probes in
                for run in 0..<10 {
                    let bench = BounceBench()
                    bench.log.endings[.wentNowhere] = .quietFade
                    let probe = probes.make(["preSleep": 0.4, "blockInWillFinish": 0.6, "windowAfter": 2.0])
                    bench.actions.bringToFrontBouncing(bench.entry(probe), cap: .seconds(10))
                    guard let app = await ProbeBundles.listed(probe, within: .seconds(5)) else {
                        Issue.record("run \(run), seed \(seed): never listed")
                        continue
                    }
                    let delay = Double.random(in: 0...1.4, using: &generator)
                    try? await Task.sleep(for: .seconds(delay))
                    let killed = ContinuousClock.now
                    app.forceTerminate()
                    let arrived = await bench.log.wait(forCount: bench.log.entries.count + 1, within: .seconds(1))
                    try? await Task.sleep(for: .milliseconds(300))

                    let history = bench.log.progresses
                    #expect(
                        history == [.wentNowhere] || history == [.finishedLaunching, .wentNowhere],
                        "run \(run), seed \(seed), killed at \(delay) s: \(history)")
                    _ = arrived
                    if let last = bench.log.entries.last {
                        #expect(
                            elapsed(from: killed, to: last.at) < 1, "run \(run), seed \(seed): reported \(elapsed(from: killed, to: last.at)) s after the kill")
                    }
                }
            }
        }

        @Test func aRepeatedGestureForALiveBounceBringsToFrontOnlyAndShowsOneRowPanel() async {
            await ProbeBundles.withProbes { probes in
                let bench = BounceBench()
                let probe = probes.make(menuBarApp: true)
                bench.actions.bringToFrontBouncing(bench.entry(probe), cap: .seconds(5))
                _ = await bench.log.wait(forCount: 1, within: .seconds(5))
                #expect(bench.log.progresses == [.finishedLaunching])

                bench.actions.bringToFrontBouncing(bench.entry(probe), cap: .seconds(5))
                try? await Task.sleep(for: .seconds(1))

                #expect(bench.log.progresses == [.finishedLaunching], "no second finishing report")
                #expect(OwnWindows.panels().count == 1, "one row panel")
                bench.tearDown([probe])
            }
        }

        @Test func aRowIsOnePanelOnThePointersDisplayAndEachEndingLeavesNothingBehind() async {
            await ProbeBundles.withProbes { probes in
                let bench = BounceBench()
                bench.tip = CGPoint(x: 700, y: 400)
                let first = probes.make(slowStart)
                let second = probes.make(slowStart)
                defer { bench.tearDown([first, second]) }

                bench.actions.bringToFrontBouncing(bench.entry(first), cap: .seconds(10))
                bench.actions.bringToFrontBouncing(bench.entry(second), cap: .seconds(10))
                try? await Task.sleep(for: .milliseconds(300))
                let row = OwnWindows.panels()
                let display = BounceBench.display(holding: bench.tip)
                #expect(row.count == 1, "one panel for the whole row: \(row)")
                #expect(row.first == display, "the row panel is the display holding the tip: \(row)")

                bench.actions.endLaunchBounce(of: BundleID(rawValue: first.id), with: .quietFade)
                let fade = await OwnWindows.sample(until: { $0.count == 2 }, within: .milliseconds(300))
                let icon = fade.panels.first { $0.width < 100 }
                #expect(icon.map { abs($0.width - 60) < 1 && abs($0.height - 60) < 1 } == true, "a 60 x 60 fade panel: \(fade.panels)")
                let faded = await OwnWindows.sample(until: { $0.count == 1 }, within: .milliseconds(500))
                #expect(faded.matched, "the fade is gone within 0.5 s while the row stays")

                bench.actions.endLaunchBounce(of: BundleID(rawValue: second.id), with: .launchAnimation)
                let flight = await OwnWindows.sample(until: { $0.contains { $0.width > 60 && $0.width < 400 } }, within: .milliseconds(300))
                #expect(flight.matched, "a flight panel larger than the icon appears: \(flight.panels)")
                #expect(!flight.panels.contains(display), "the row panel is gone")
                let flown = await OwnWindows.sample(until: { $0.isEmpty }, within: .milliseconds(600))
                #expect(flown.matched, "the flight is gone within 0.6 s")

                bench.actions.endLaunchBounce(of: BundleID(rawValue: second.id), with: .launchAnimation)
                try? await Task.sleep(for: .seconds(1))
                #expect(OwnWindows.panels().isEmpty, "nothing of ours remains")
            }
        }

        @Test func theFadeSitsAboveTheTipCutAtTheEdgesAndInRowOrder() async {
            let display = BounceBench.display(holding: CGPoint(x: 700, y: 400))
            await ProbeBundles.withProbes { probes in
                let bench = BounceBench()
                let ids = [probes.make(slowStart), probes.make(slowStart)]
                defer { bench.tearDown(ids) }

                @MainActor func fadeOfFirst(bouncing count: Int, tip: CGPoint, after wait: Duration = .zero) async -> CGRect? {
                    bench.tip = tip
                    for bundle in ids.prefix(count) {
                        bench.actions.bringToFrontBouncing(bench.entry(bundle), cap: .seconds(10))
                    }
                    try? await Task.sleep(for: wait)
                    bench.actions.endLaunchBounce(of: BundleID(rawValue: ids[0].id), with: .quietFade)
                    let seen = await OwnWindows.sample(until: { $0.contains { $0.width < display.width } }, within: .milliseconds(300))
                    let fade = seen.panels.first { $0.width < display.width }
                    for bundle in ids.prefix(count) { bench.actions.endLaunchBounce(of: BundleID(rawValue: bundle.id), with: .quietFade) }
                    _ = await OwnWindows.sample(until: { $0.isEmpty }, within: .seconds(1))
                    return fade
                }

                LaunchTuning.setReduceMotion(true)
                defer { LaunchTuning.setReduceMotion(false) }

                let centre = CGPoint(x: 700, y: 400)
                if let fade = await fadeOfFirst(bouncing: 1, tip: centre) {
                    #expect(abs(fade.width - 60) < 1 && abs(fade.height - 60) < 1, "60 x 60: \(fade)")
                    #expect(abs(fade.midX - 700) < 1 && abs(fade.minY - 408) < 1, "bottom centre at (700, 408): \(fade)")
                } else {
                    Issue.record("no fade panel at rest")
                }

                let nearRight = CGPoint(x: display.maxX - 10, y: 400)
                if let fade = await fadeOfFirst(bouncing: 1, tip: nearRight) {
                    #expect(abs(fade.maxX - display.maxX) < 1, "its right edge is the display's: \(fade)")
                } else {
                    Issue.record("no fade panel near the right edge")
                }

                let nearTop = CGPoint(x: 700, y: display.maxY - 30)
                if let fade = await fadeOfFirst(bouncing: 1, tip: nearTop) {
                    #expect(abs(fade.maxY - display.maxY) < 1, "the top edge cuts it: \(fade)")
                    #expect(abs(fade.minY - (nearTop.y + 8)) < 1, "its bottom stays 8 above the tip: \(fade)")
                } else {
                    Issue.record("no fade panel near the top edge")
                }

                if let fade = await fadeOfFirst(bouncing: 2, tip: centre, after: .milliseconds(500)) {
                    #expect(abs(fade.midX - (700 - 36)) < 1, "the older icon sits 36 pt left of the tip: \(fade)")
                } else {
                    Issue.record("no fade panel for the older icon")
                }

                LaunchTuning.setReduceMotion(false)
                if let fade = await fadeOfFirst(bouncing: 1, tip: centre, after: .milliseconds(200)) {
                    #expect(fade.minY > 408 && fade.minY <= 438, "mid-jump: bottom between tip + 8 and tip + 38: \(fade)")
                    #expect(abs(fade.midX - 700) < 1, "centred on the tip: \(fade)")
                } else {
                    Issue.record("no fade panel mid-jump")
                }
            }
        }

        @Test func aBounceThatCannotBeShownRunsOutOnTheNextTurnAndShowsNothing() async {
            await ProbeBundles.withProbes { probes in
                let bench = BounceBench()
                bench.disconnectDisplays()
                let probe = probes.make(slowStart)
                defer { bench.tearDown([probe]) }

                bench.actions.bringToFrontBouncing(bench.entry(probe), cap: .seconds(5))
                #expect(bench.log.entries.isEmpty, "nothing is reported during the call")

                let arrived = await bench.log.wait(forCount: 1, within: .seconds(1))
                try? await Task.sleep(for: .milliseconds(500))

                #expect(arrived)
                #expect(bench.log.progresses == [.ranOut])
                #expect(OwnWindows.panels().isEmpty)
            }
        }
    }
}

extension LaunchTuning {
    /// Forces the Reduce motion look, or restores the shipped tuning.
    @MainActor static func setReduceMotion(_ on: Bool) {
        #if DEBUG
        var tuning = LaunchTuning.shipped
        tuning.forceReduceMotion = on
        tunerOverride.withLock { $0 = tuning }
        #endif
    }
}

/// A seeded generator, so a failing random run can be repeated from the seed in its message.
struct SplitMix: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@MainActor @Suite struct BounceDeadlineTests {
    @Test func aDeadlineThatIsNotCancelledPassesOnAnyStopAndACancelledOneNever() {
        var passes = 0
        let live = BounceOverlay.Deadline { passes += 1 }
        live.animationDidStop(CABasicAnimation(), finished: true)
        live.animationDidStop(CABasicAnimation(), finished: false)
        #expect(passes == 2, "a stop the system causes counts as passed too")

        let cancelled = BounceOverlay.Deadline { passes += 1 }
        cancelled.isCancelled = true
        cancelled.animationDidStop(CABasicAnimation(), finished: true)
        cancelled.animationDidStop(CABasicAnimation(), finished: false)
        #expect(passes == 2)
    }
}
