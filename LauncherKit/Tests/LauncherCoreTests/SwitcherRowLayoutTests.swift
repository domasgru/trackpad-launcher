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
        #expect(layout.panelWidth == 536)
        #expect(layout.centreX(at: 0) == 68)
        #expect(layout.centreX(at: 1) == 168)
        #expect(layout.centreX(at: 2.5) == 318)
    }

    @Test func fourteenIconsStillFitOnA1512PointDisplay() {
        #expect(SwitcherRowLayout(iconCount: 14, displayWidth: 1512).scale == 1)
    }

    @Test func fifteenIconsShrinkIconsAndGapsByOneFactorToFillTheDisplay() {
        let layout = SwitcherRowLayout(iconCount: 15, displayWidth: 1512)
        #expect(close(layout.scale, 1456.0 / 1480.0))
        #expect(close(layout.iconSide, 78.70))
        #expect(close(layout.iconGap, 19.68))
        #expect(close(layout.panelWidth, 1512))
    }

    @Test func thirtyIconsShrinkSoTheFirstLeftEdgeAndLastRightEdgeSitInsideThePadding() {
        let layout = SwitcherRowLayout(iconCount: 30, displayWidth: 1512)
        #expect(close(layout.iconSide, 39.09))
        #expect(close(layout.iconGap, 9.77))
        #expect(close(layout.panelWidth, 1512))
        #expect(close(layout.centreX(at: 0), 47.54))
        #expect(close(layout.centreX(at: 29), 1464.46))
        #expect(close(layout.centreX(at: 0) - layout.iconSide / 2, 28))
        #expect(close(layout.centreX(at: 29) + layout.iconSide / 2, 1484))
    }

    @Test func aDisplayWidthThatIsNotPositiveMeansNoConstraint() {
        #expect(SwitcherRowLayout(iconCount: 30, displayWidth: 0).scale == 1)
        #expect(SwitcherRowLayout(iconCount: 30, displayWidth: -5).scale == 1)
    }
}
