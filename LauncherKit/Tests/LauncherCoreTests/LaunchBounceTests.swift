import Testing

@testable import LauncherCore

@Suite struct LaunchBounceTests {
    @Test func aWindowEndsEveryBounceWithTheLaunchAnimation() {
        #expect(WatchedLaunch.Stage.startingUp.next(after: .windowShown) == .end(.launchAnimation))
        #expect(WatchedLaunch.Stage.startedUp.next(after: .windowShown) == .end(.launchAnimation))
    }

    @Test func goingNowhereEndsEveryBounceQuietly() {
        #expect(WatchedLaunch.Stage.startingUp.next(after: .wentNowhere) == .end(.quietFade))
        #expect(WatchedLaunch.Stage.startedUp.next(after: .wentNowhere) == .end(.quietFade))
    }

    @Test func finishingLaunchingStartsTheGraceOnlyOnce() {
        #expect(WatchedLaunch.Stage.startingUp.next(after: .finishedLaunching) == .startUp(limit: .seconds(2)))
        #expect(WatchedLaunch.Stage.startedUp.next(after: .finishedLaunching) == .carryOn)
    }

    @Test func runningOutEndsQuietlyUnlessTheAppFinishedLaunching() {
        #expect(WatchedLaunch.Stage.startingUp.next(after: .ranOut) == .end(.quietFade))
        #expect(WatchedLaunch.Stage.startedUp.next(after: .ranOut) == .end(.launchAnimation))
    }

    @Test func theCapIsTenSeconds() {
        #expect(WatchedLaunch.cap == .seconds(10))
    }
}
