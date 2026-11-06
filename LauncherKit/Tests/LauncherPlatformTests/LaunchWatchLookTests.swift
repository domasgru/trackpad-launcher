import CoreGraphics
import Testing

@testable import LauncherPlatform

@Suite struct LaunchWatchLookTests {
    @Test func onlyAListedWindowEndsTheLookAndAnUnlistedOneKeepsLooking() {
        #expect(LaunchWatch.look(.registered, axWindows: 0, listedWindows: 1) == .shown)
        #expect(LaunchWatch.look(.registered, axWindows: 1, listedWindows: 1) == .shown)
        #expect(LaunchWatch.look(.noAccess, axWindows: 0, listedWindows: 1) == .shown)
        #expect(LaunchWatch.look(.notAnswering, axWindows: 0, listedWindows: 1) == .shown)
        #expect(LaunchWatch.look(.registered, axWindows: 0, listedWindows: 0) == .watching)
        #expect(LaunchWatch.look(.noAccess, axWindows: 0, listedWindows: 0) == .relooking)
        #expect(LaunchWatch.look(.notAnswering, axWindows: 0, listedWindows: 0) == .relooking)
    }

    @Test func aHiddenStartupWindowIsNotShown() {
        #expect(LaunchWatch.look(.registered, axWindows: 1, listedWindows: 0) == .relooking)
    }

    private func entry(pid: Int32 = 7, layer: Int = 0, alpha: Double = 1, width: Int = 800, height: Int = 600)
        -> [String: Any] {
        [
            kCGWindowOwnerPID as String: pid, kCGWindowLayer as String: layer, kCGWindowAlpha as String: alpha,
            kCGWindowBounds as String: ["X": 0, "Y": 0, "Width": width, "Height": height],
        ]
    }

    @Test func aWindowOfTheAppAtNormalLevelCounts() {
        #expect(LaunchWatch.isVisibleWindow(entry(), of: 7, statusLevel: 25))
        #expect(LaunchWatch.isVisibleWindow(entry(width: 320, height: 200), of: 7, statusLevel: 25))
    }

    @Test func whatAUserCannotSeeDoesNotCount() {
        #expect(!LaunchWatch.isVisibleWindow(entry(pid: 8), of: 7, statusLevel: 25))
        #expect(!LaunchWatch.isVisibleWindow(entry(layer: 25), of: 7, statusLevel: 25))
        #expect(!LaunchWatch.isVisibleWindow(entry(alpha: 0), of: 7, statusLevel: 25))
        #expect(!LaunchWatch.isVisibleWindow(entry(width: 1, height: 1), of: 7, statusLevel: 25))
    }
}
