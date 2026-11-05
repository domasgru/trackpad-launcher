import LauncherCore
import Testing
@testable import LauncherUI

@Suite struct ThumbCornerRuleTests {
    @Test(arguments: [
        (ThumbCorner.topLeft, true), (.topRight, false), (.bottomLeft, false), (.bottomRight, false),
    ])
    func theGuideShowsOnlyForTheTopLeftCorner(corner: ThumbCorner, shows: Bool) {
        #expect(corner.showsGuide == shows)
    }

    @Test(arguments: [
        (ThumbCorner.topLeft, "gesture-1"), (.bottomLeft, "gesture-1"),
        (.topRight, "gesture-1-inverse"), (.bottomRight, "gesture-1-inverse"),
    ])
    func eachSideUsesItsTopCornerPicture(corner: ThumbCorner, name: String) {
        #expect(corner.illustration("gesture-1") == name)
    }
}
