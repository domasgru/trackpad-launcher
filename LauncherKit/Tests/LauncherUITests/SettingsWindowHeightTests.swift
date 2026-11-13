import CoreGraphics
import Testing

@testable import LauncherUI

@Suite struct SettingsWindowHeightTests {
    private let titleBar: CGFloat = 28

    @Test func aTallContentIsCappedSoTheWholeWindowIsNinetyPercentOfTheVisibleHeight() {
        let content = SettingsWindowHeight.contentHeight(fitting: 1_000 - 28, titleBar: titleBar, visible: 800)
        #expect(content == 692)
        #expect(content + titleBar == 720)
    }

    @Test func aContentThatFitsKeepsItsOwnHeight() {
        #expect(SettingsWindowHeight.contentHeight(fitting: 900, titleBar: titleBar, visible: 1_200) == 900)
    }

    @Test func theWindowGrowsToTheCapAndNoFurther() {
        #expect(SettingsWindowHeight.contentHeight(fitting: 860, titleBar: titleBar, visible: 1_000) == 860)
        #expect(SettingsWindowHeight.contentHeight(fitting: 960, titleBar: titleBar, visible: 1_000) == 872)
    }

    @Test func aContentExactlyAtTheCapIsReturnedAsIs() {
        #expect(SettingsWindowHeight.contentHeight(fitting: 872, titleBar: titleBar, visible: 1_000) == 872)
    }

    @Test func aCappedWindowWidensByALegacyScrollersWidth() {
        #expect(SettingsWindowHeight.contentWidth(fitting: 358, isCapped: true, scrollerWidth: 15) == 373)
    }

    @Test func aCappedWindowWithAnOverlayScrollerKeepsTheContentsWidth() {
        #expect(SettingsWindowHeight.contentWidth(fitting: 358, isCapped: true, scrollerWidth: 0) == 358)
    }

    @Test func aWindowThatFitsKeepsTheContentsWidthWhateverTheScroller() {
        #expect(SettingsWindowHeight.contentWidth(fitting: 358, isCapped: false, scrollerWidth: 15) == 358)
    }
}
