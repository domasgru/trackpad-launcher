import QuartzCore
import Testing

@testable import LauncherPlatform

@Suite struct LaunchWatchLookTests {
    @Test func lookEndsTheBounceOnAnyWindowAndOtherwiseWatchesOnlyWhenRegistered() {
        #expect(LaunchWatch.look(.registered, axWindows: 1, listedWindows: 0) == .shown)
        #expect(LaunchWatch.look(.registered, axWindows: 0, listedWindows: 1) == .shown)
        #expect(LaunchWatch.look(.noAccess, axWindows: 0, listedWindows: 1) == .shown)
        #expect(LaunchWatch.look(.notAnswering, axWindows: 0, listedWindows: 1) == .shown)
        #expect(LaunchWatch.look(.registered, axWindows: 0, listedWindows: 0) == .watching)
        #expect(LaunchWatch.look(.noAccess, axWindows: 0, listedWindows: 0) == .blind)
        #expect(LaunchWatch.look(.notAnswering, axWindows: 0, listedWindows: 0) == .blind)
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
