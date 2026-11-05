import Testing

@testable import LauncherPlatform

@Suite struct LaunchWatchLookTests {
    @Test func lookEndsTheBounceOnAnyWindowAndOtherwiseWatchesWhenRegisteredAndRelooksWhenNot() {
        #expect(LaunchWatch.look(.registered, axWindows: 1, listedWindows: 0) == .shown)
        #expect(LaunchWatch.look(.registered, axWindows: 0, listedWindows: 1) == .shown)
        #expect(LaunchWatch.look(.noAccess, axWindows: 0, listedWindows: 1) == .shown)
        #expect(LaunchWatch.look(.notAnswering, axWindows: 0, listedWindows: 1) == .shown)
        #expect(LaunchWatch.look(.registered, axWindows: 0, listedWindows: 0) == .watching)
        #expect(LaunchWatch.look(.noAccess, axWindows: 0, listedWindows: 0) == .relooking)
        #expect(LaunchWatch.look(.notAnswering, axWindows: 0, listedWindows: 0) == .relooking)
    }
}
