import Foundation
import Testing
import LauncherCore

@Suite struct NoWindowsCardValueTests {
    private let notes = AppEntry(
        bundleID: BundleID(rawValue: "com.test.notes"), name: "Notes", url: URL(fileURLWithPath: "/Applications/Notes.app"))

    private func offset(afterMM mm: Int) -> Double {
        var selection = SwitcherSelection(count: 1)
        var travel = 0.0
        for _ in 0..<abs(mm) {
            travel += mm > 0 ? 1 : -1
            selection.follow(travel)
        }
        return NoWindowsCard.offset(stretch: selection.stretch)
    }

    @Test func theOffsetIsZeroAtRest() {
        #expect(NoWindowsCard.offset(stretch: 0) == 0)
    }

    @Test func fortyMillimetresDownReachesSixPointsAndUpMinusSix() {
        #expect(offset(afterMM: 40) == 6)
        #expect(offset(afterMM: -40) == -6)
    }

    @Test func theOffsetTakesTheSignOfTheStretch() {
        #expect(NoWindowsCard.offset(stretch: 0.05) > 0)
        #expect(NoWindowsCard.offset(stretch: -0.05) < 0)
        #expect(NoWindowsCard.offset(stretch: 5) == 6)
        #expect(NoWindowsCard.offset(stretch: -5) == -6)
    }

    @Test func theFullStretchIsTheOneAQuarterStepOvershootGives() {
        #expect(abs(SwitcherSelection.fullStretch - 0.2 * (1 - 1 / 2.25)) < 1e-12)
    }

    @Test func theCardNamesTheAppInItsTwoLines() {
        let one = NoWindowsCard(.oneWindow, of: notes)
        #expect(one.title == "No other windows")
        #expect(one.message == "Notes has no other windows on this desktop.")
        let none = NoWindowsCard(.noWindows, of: notes)
        #expect(none.title == "No open windows")
        #expect(none.message == "Notes has no windows on this desktop.")
    }
}
