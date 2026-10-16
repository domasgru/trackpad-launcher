import Testing
import LauncherCore

@Suite struct WindowColumnLayoutTests {
    private func close(_ value: Double, _ expected: Double) -> Bool { abs(value - expected) < 1e-9 }

    @Test(arguments: [
        (aspect: 2.0, width: 120.0, height: 60.0),
        (aspect: 1.6, width: 96.0, height: 60.0),
        (aspect: 3.0, width: 120.0, height: 40.0),
        (aspect: 0.5, width: 30.0, height: 60.0),
    ])
    func aPreviewIsSixtyPointsTallKeepingItsProportionsAndAtMostOneHundredTwentyWide(
        aspect: Double, width: Double, height: Double
    ) {
        let size = WindowColumnLayout(rowCount: 3, widestTitle: 200, displayHeight: 900).previewSize(aspect: aspect)
        #expect(close(size.width, width) && close(size.height, height))
    }

    /// Ten 72-point rows 2 points apart inside 8 points of padding, plus a 12-point margin above and below.
    private static let tenRowsAtFullSizeWithMargins = 778.0

    @Test func tenRowsKeepTheFullSizeWhenTheyJustFit() {
        let layout = WindowColumnLayout(rowCount: 10, widestTitle: 200, displayHeight: Self.tenRowsAtFullSizeWithMargins)
        #expect(layout.scale == 1)
        #expect(layout.pitch == 74)
        #expect(layout.panelSize.height == 754)
        #expect(layout.rowTop(at: 0) == 8)
        #expect(layout.rowTop(at: 2) == 156)
    }

    @Test func aColumnThatWouldNotFitShrinksByOneFactorUntilItDoes() {
        let height = Self.tenRowsAtFullSizeWithMargins - 1
        let layout = WindowColumnLayout(rowCount: 10, widestTitle: 200, displayHeight: height)
        let margins = 2 * WindowColumnLayout.margin
        #expect(layout.scale < 1)
        #expect(layout.panelSize.height + margins <= height)
        #expect(layout.panelSize.height + margins > height - 1)
        #expect(close(layout.pitch, 74 * layout.scale))
        let preview = layout.previewSize(aspect: 2)
        #expect(close(preview.width, 120 * layout.scale) && close(preview.height, 60 * layout.scale))
    }

    @Test func theColumnIsAsWideAsTheWidestTitleWithinItsBounds() {
        func width(_ title: Double) -> Double {
            WindowColumnLayout(rowCount: 2, widestTitle: title, displayHeight: 900).panelSize.width
        }
        let around = 2 * 8.0 + 2 * 6.0 + 120 + 12
        #expect(width(100) == around + 180)
        #expect(width(250) == around + 250)
        #expect(width(900) == around + 320)
    }

    @Test func theLargestPreviewWorthCapturingFillsTheSlotAtTheDisplaysBackingScale() {
        let pixels = WindowColumnLayout(rowCount: 3, widestTitle: 200, displayHeight: 900).previewPixels(scale: 2)
        #expect(pixels.width == 240 && pixels.height == 120)
    }
}
