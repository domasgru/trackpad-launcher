import Testing
import LauncherCore

@Suite struct SwitcherRowLayoutTests {
    private func close(_ value: Double, _ expected: Double, within tolerance: Double = 0.01) -> Bool {
        abs(value - expected) < tolerance
    }

    /// Left is measured with the highlight on the first icon, right with it on the last.
    private func gaps(_ layout: SwitcherRowLayout) -> (left: Double, right: Double, top: Double, bottom: Double) {
        let half = layout.highlightSide / 2
        return (
            left: layout.centreX(at: 0) - half,
            right: layout.panelSize.width - (layout.centreX(at: Double(layout.iconCount - 1)) + half),
            top: layout.centreY - half,
            bottom: layout.panelSize.height - (layout.centreY + half)
        )
    }

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
        let edge = gaps(SwitcherRowLayout(iconCount: 5, displayWidth: 1512))
        #expect(edge.left == 22)
        #expect(edge.top == 22)
        #expect(edge.bottom == 22)
    }

    @Test func theLastHighlightIsTwentyTwoPointsFromTheRightEdge() {
        #expect(gaps(SwitcherRowLayout(iconCount: 5, displayWidth: 1512)).right == 22)
    }

    @Test func aSingleIconHasTwentyTwoPointsAroundItsHighlightOnEverySide() {
        let layout = SwitcherRowLayout(iconCount: 1, displayWidth: 1512)
        #expect(layout.panelSize.width == 136)
        #expect(layout.panelSize.height == 136)
        let edge = gaps(layout)
        #expect(edge.left == 22)
        #expect(edge.right == 22)
        #expect(edge.top == 22)
        #expect(edge.bottom == 22)
    }

    @Test func aRowTooWideForTheDisplayShrinksYetKeepsTheFourGapsEqual() {
        let layout = SwitcherRowLayout(iconCount: 10, displayWidth: 1024)
        #expect(close(layout.scale, 980.0 / 992.0, within: 0.0001))
        #expect(close(layout.panelSize.width, 1024))
        let edge = gaps(layout)
        for gap in [edge.left, edge.right, edge.top, edge.bottom] { #expect(close(gap, 22)) }
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
        #expect(SwitcherRowLayout.selectedIconScale == 1.12)
        #expect(close(selected, 89.6))
        #expect(selected > SwitcherRowLayout.fullIconSide)
        #expect(selected <= SwitcherRowLayout.fullHighlightSide)
    }

    @Test func aDisplayWidthThatIsNotPositiveMeansNoConstraint() {
        #expect(SwitcherRowLayout(iconCount: 30, displayWidth: 0).scale == 1)
        #expect(SwitcherRowLayout(iconCount: 30, displayWidth: -5).scale == 1)
    }
}
