import AppKit
import QuartzCore
import Testing

@testable import LauncherCore
@testable import LauncherPlatform

@MainActor @Suite(.serialized) struct LaunchWatchClockTests {
    private final class Reports {
        var seen: [(time: ContinuousClock.Instant, progress: LaunchProgress)] = []
    }

    @Test func aWatchNeverGivenAPidRunsOutAtItsCapAndNeverShowsItsHost() async throws {
        let reports = Reports()
        var watch: LaunchWatch?
        let began = ContinuousClock.now
        var hostShownAtRunOut: Bool?
        let ranOut: Bool? = await awaiting("the cap") { done in
            let started = LaunchWatch { progress in
                reports.seen.append((.now, progress))
                hostShownAtRunOut = LaunchClock.hostPanel?.isVisible
                done(true)
            }
            started.start(cap: .milliseconds(200))
            #expect(LaunchClock.hostPanel?.isVisible == false)
            watch = started
        }
        #expect(ranOut == true)
        #expect(reports.seen.map(\.progress) == [.ranOut])
        let ranOutAt = try #require(reports.seen.first?.time)
        #expect(ranOutAt - began >= .milliseconds(200), "not before the cap")
        #expect(hostShownAtRunOut == false)
        try await Task.sleep(for: .milliseconds(500))
        #expect(reports.seen.count == 1, "nothing else follows")
        watch?.stop()
    }

    @Test func aLimitRunsTheWatchOutLongBeforeItsCap() async throws {
        let reports = Reports()
        var watch: LaunchWatch?
        var limited = ContinuousClock.now
        // The cap is far beyond `awaiting`'s bound, so only the limit can answer in time. The bound is generous because
        // other tests in this process hold the main actor for seconds: only lower bounds on time are asserted.
        let ranOut: Bool? = await awaiting("the limit") { done in
            let started = LaunchWatch { progress in
                reports.seen.append((.now, progress))
                done(true)
            }
            started.start(cap: .seconds(120))
            limited = .now
            started.limit(to: .milliseconds(200))
            watch = started
        }
        #expect(ranOut == true)
        #expect(reports.seen.map(\.progress) == [.ranOut])
        let ranOutAt = try #require(reports.seen.first?.time)
        #expect(ranOutAt - limited >= .milliseconds(200))
        watch?.stop()
    }

    @Test func aWatchStoppedAtOnceReportsNothing() async throws {
        let reports = Reports()
        let watch = LaunchWatch { reports.seen.append((.now, $0)) }
        watch.start(cap: .milliseconds(200))
        watch.stop()
        try await Task.sleep(for: .seconds(1))
        #expect(reports.seen.isEmpty)
        // Other suites' clocks share the host, so it closes with the last of theirs: one this watch leaked never would.
        let closed = await awaiting("the host to close") { (done: @escaping @Sendable (Bool) -> Void) in
            Task { @MainActor in
                while LaunchClock.hostPanel != nil { try? await Task.sleep(for: .milliseconds(20)) }
                done(true)
            }
        }
        #expect(closed == true, "the host closes with the last clock")
    }

    @Test func aDeadlineThatIsNotCancelledPassesOnAnyStopAndACancelledOneNever() {
        var passes = 0
        let live = LaunchClock.Deadline { passes += 1 }
        live.animationDidStop(CABasicAnimation(), finished: true)
        live.animationDidStop(CABasicAnimation(), finished: false)
        #expect(passes == 2, "a stop the system causes counts as passed too")

        let cancelled = LaunchClock.Deadline { passes += 1 }
        cancelled.isCancelled = true
        cancelled.animationDidStop(CABasicAnimation(), finished: true)
        cancelled.animationDidStop(CABasicAnimation(), finished: false)
        #expect(passes == 2)
    }
}
