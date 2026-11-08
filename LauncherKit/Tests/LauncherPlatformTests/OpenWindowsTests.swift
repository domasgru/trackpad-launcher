import CoreGraphics
import Foundation
import LauncherCore
import Testing

@testable import LauncherPlatform

@MainActor @Suite struct OpenWindowsTests {
    @Test func theWindowServerHoldsAListedWindowAndNotOneFarAboveEveryNumber() throws {
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        let numbers = info.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value }
        let listed = try #require(numbers.first)
        let reader = AppWindowReader()

        let open = reader.openWindows(among: [WindowID(rawValue: listed), WindowID(rawValue: UInt32.max)])

        #expect(open == [WindowID(rawValue: listed)])
    }

    @Test func askingAboutNothingAnswersNothing() {
        #expect(AppWindowReader().openWindows(among: []).isEmpty)
    }
}
