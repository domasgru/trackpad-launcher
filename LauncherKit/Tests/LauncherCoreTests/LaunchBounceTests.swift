import Testing

@testable import LauncherCore

@Suite struct LaunchBounceTests {
    @Test func aWindowEndsEveryBounceWithTheLaunchAnimation() {
        #expect(LaunchBounce.startingUp.next(after: .windowShown) == .end(.launchAnimation))
        #expect(LaunchBounce.startedUp.next(after: .windowShown) == .end(.launchAnimation))
    }

    @Test func goingNowhereEndsEveryBounceQuietly() {
        #expect(LaunchBounce.startingUp.next(after: .wentNowhere) == .end(.quietFade))
        #expect(LaunchBounce.startedUp.next(after: .wentNowhere) == .end(.quietFade))
    }

    @Test func finishingLaunchingStartsTheGraceOnlyOnce() {
        #expect(LaunchBounce.startingUp.next(after: .finishedLaunching) == .startUp(limit: .seconds(2)))
        #expect(LaunchBounce.startedUp.next(after: .finishedLaunching) == .carryOn)
    }

    @Test func runningOutEndsQuietlyUnlessTheAppFinishedLaunching() {
        #expect(LaunchBounce.startingUp.next(after: .ranOut) == .end(.quietFade))
        #expect(LaunchBounce.startedUp.next(after: .ranOut) == .end(.launchAnimation))
    }

    @Test func theCapIsTenSeconds() {
        #expect(LaunchBounce.cap == .seconds(10))
    }
}
