import Testing
import LauncherCore

@Suite struct SwitcherRowLayoutTests {
    private func close(_ value: Double, _ expected: Double) -> Bool { abs(value - expected) < 0.01 }

    @Test func aRowThatFitsKeepsTheFullSizeAndPlacesIconsOnAHundredPointPitch() {
        let layout = SwitcherRowLayout(iconCount: 5, displayWidth: 1512)
        #expect(layout.scale == 1)
        #expect(layout.iconSide == 80)
        #expect(layout.iconGap == 20)
        #expect(layout.pitch == 100)
        #expect(layout.highlightSide == 92)
        #expect(layout.panelSize.width == 536)
        #expect(layout.panelSize.height == 136)
        #expect(layout.centreX(at: 0) == 68)
        #expect(layout.centreX(at: 1) == 168)
        #expect(layout.centreX(at: 2.5) == 318)
    }

    @Test func theFirstHighlightIsTwentyTwoPointsFromTheLeftTopAndBottomEdges() {
        let layout = SwitcherRowLayout(iconCount: 5, displayWidth: 1512)
        #expect(layout.centreX(at: 0) - layout.highlightSide / 2 == 22)
        #expect(layout.centreY - layout.highlightSide / 2 == 22)
        #expect(layout.panelSize.height - (layout.centreY + layout.highlightSide / 2) == 22)
    }

    @Test func theLastHighlightIsTwentyTwoPointsFromTheRightEdge() {
        let layout = SwitcherRowLayout(iconCount: 5, displayWidth: 1512)
        #expect(layout.panelSize.width - (layout.centreX(at: 4) + layout.highlightSide / 2) == 22)
    }

    @Test func aSingleIconHasTwentyTwoPointsAroundItsHighlightOnEverySide() {
        let layout = SwitcherRowLayout(iconCount: 1, displayWidth: 1512)
        #expect(layout.panelSize.width == 136)
        #expect(layout.panelSize.height == 136)
        #expect(layout.centreX(at: 0) - layout.highlightSide / 2 == 22)
        #expect(layout.panelSize.width - (layout.centreX(at: 0) + layout.highlightSide / 2) == 22)
        #expect(layout.centreY - layout.highlightSide / 2 == 22)
        #expect(layout.panelSize.height - (layout.centreY + layout.highlightSide / 2) == 22)
    }

    @Test func aRowTooWideForTheDisplayShrinksYetKeepsTheFourGapsEqual() {
        let layout = SwitcherRowLayout(iconCount: 10, displayWidth: 1024)
        #expect(abs(layout.scale - 980.0 / 992.0) < 0.0001)
        #expect(close(layout.panelSize.width, 1024))
        let left = layout.centreX(at: 0) - layout.highlightSide / 2
        let right = layout.panelSize.width - (layout.centreX(at: 9) + layout.highlightSide / 2)
        let top = layout.centreY - layout.highlightSide / 2
        let bottom = layout.panelSize.height - (layout.centreY + layout.highlightSide / 2)
        for gap in [left, right, top, bottom] { #expect(close(gap, 22)) }
    }

    @Test func aRowShrinksOnlyOnceItsPaddedWidthPassesTheDisplay() {
        let fits = SwitcherRowLayout(iconCount: 10, displayWidth: 1036)
        #expect(fits.scale == 1)
        #expect(fits.panelSize.width == 1036)
        let tight = SwitcherRowLayout(iconCount: 10, displayWidth: 1035)
        #expect(tight.scale < 1)
        #expect(close(tight.panelSize.width, 1035))
    }

    @Test func theSelectedIconIsLargerThanTheOthersAndInsideTheHighlight() {
        let selected = SwitcherRowLayout.fullIconSide * SwitcherRowLayout.selectedIconScale
        #expect(selected > SwitcherRowLayout.fullIconSide)
        #expect(selected <= SwitcherRowLayout.fullHighlightSide)
    }

    @Test func aDisplayWidthThatIsNotPositiveMeansNoConstraint() {
        #expect(SwitcherRowLayout(iconCount: 30, displayWidth: 0).scale == 1)
        #expect(SwitcherRowLayout(iconCount: 30, displayWidth: -5).scale == 1)
    }
}
