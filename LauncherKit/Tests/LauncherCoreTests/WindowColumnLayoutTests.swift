import Testing
import LauncherCore

@Suite struct WindowColumnLayoutTests {
    private func close(_ value: Double, _ expected: Double, within tolerance: Double = 1e-9) -> Bool {
        abs(value - expected) < tolerance
    }

    @Test(arguments: [
        (aspect: 2.0, width: 120.0, height: 60.0),
        (aspect: 1.6, width: 96.0, height: 60.0),
        (aspect: 3.0, width: 120.0, height: 40.0),
        (aspect: 0.5, width: 30.0, height: 60.0),
    ])
    func aPreviewIsSixtyPointsTallKeepingItsProportionsAndAtMostOneHundredTwentyWide(
        aspect: Double, width: Double, height: Double
    ) {
        let size = WindowColumnLayout(rowCount: 3, displayHeight: 900).previewSize(aspect: aspect)
        #expect(close(size.width, width) && close(size.height, height))
    }

    /// Ten 72-point rows 2 points apart inside 8 points of padding, plus a 12-point margin above and below.
    private static let tenRowsAtFullSizeWithMargins = 778.0

    @Test func tenRowsKeepTheFullSizeWhenTheyJustFit() {
        let layout = WindowColumnLayout(rowCount: 10, displayHeight: Self.tenRowsAtFullSizeWithMargins)
        #expect(layout.scale == 1)
        #expect(layout.pitch == 74)
        #expect(layout.panelSize.height == 754)
        #expect(layout.rowTop(at: 0) == 8)
        #expect(layout.rowTop(at: 2) == 156)
    }

    @Test func aColumnThatWouldNotFitShrinksByOneFactorUntilItDoes() {
        // 777 points: one short of the 778 the column needs at full size.
        let height = Self.tenRowsAtFullSizeWithMargins - 1
        let layout = WindowColumnLayout(rowCount: 10, displayHeight: height)
        let margins = 2 * WindowColumnLayout.margin
        #expect(layout.scale < 1)
        #expect(layout.panelSize.height + margins <= height)
        #expect(layout.panelSize.height + margins > height - 1)
        #expect(close(layout.pitch, 74 * layout.scale))
        let preview = layout.previewSize(aspect: 2)
        #expect(close(preview.width, 120 * layout.scale) && close(preview.height, 60 * layout.scale))
    }

    @Test func theColumnIsThreeHundredSixtyPointsWideWhateverTheRowCount() {
        #expect(WindowColumnLayout(rowCount: 2, displayHeight: 900).panelSize.width == 360)
        #expect(WindowColumnLayout(rowCount: 10, displayHeight: 900).panelSize.width == 360)
    }

    @Test func aShrunkColumnNarrowsItsWidthAndTitleColumnByTheRowsFactor() {
        let layout = WindowColumnLayout(rowCount: 10, displayHeight: Self.tenRowsAtFullSizeWithMargins - 1)
        #expect(layout.scale < 1)
        #expect(close(layout.panelSize.width, 359.5225, within: 0.001))
        #expect(close(layout.titleWidth, 199.7347, within: 0.001))
    }

    @Test func theTitleColumnEndsAtTheRowsInsetAtEveryScale() {
        let full = WindowColumnLayout(rowCount: 3, displayHeight: 900)
        #expect(full.titleLeading == 138)
        #expect(full.titleLeading + full.titleWidth == 338)
        let shrunk = WindowColumnLayout(rowCount: 10, displayHeight: Self.tenRowsAtFullSizeWithMargins - 1)
        #expect(close(shrunk.titleLeading, 137.8170, within: 0.001))
        #expect(close(shrunk.titleLeading + shrunk.titleWidth, 337.5517, within: 0.001))
    }

    @Test func theLargestPreviewWorthCapturingFillsTheSlotAtTheDisplaysBackingScale() {
        let pixels = WindowColumnLayout(rowCount: 3, displayHeight: 900).previewPixels(scale: 2)
        #expect(pixels.width == 240 && pixels.height == 120)
    }
}
