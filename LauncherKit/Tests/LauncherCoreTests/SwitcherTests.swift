import Foundation
import Testing
import LauncherCore

@Suite struct SwitcherTests {
    private func entry(_ name: String, at directory: String = "/Applications") -> AppEntry {
        AppEntry(
            bundleID: BundleID(rawValue: "com.test.\(name.lowercased())"), name: name,
            url: URL(fileURLWithPath: "\(directory)/\(name).app"))
    }

    private var safari: AppEntry { entry("Safari") }
    private var mail: AppEntry { entry("Mail") }
    private var slack: AppEntry { entry("Slack") }
    private var notes: AppEntry { entry("Notes") }

    private func switcher(frontmost: AppEntry? = nil, running: [AppEntry]? = nil, travel: Double = 0) -> Switcher {
        var switcher = Switcher(
            frontmost: frontmost ?? safari, running: running ?? [safari, mail, slack, notes],
            trackpad: Trackpad.macBook14.id)!
        switcher.travelMM = travel
        return switcher
    }

    @Test func theRowHoldsTheFrontmostAppAndTheNineMostRecentOthers() {
        let running = (1...12).map { entry("App\($0)") }
        let row = switcher(frontmost: running[11], running: running).row
        #expect(row.map(\.name) == ["App12"] + (1...9).map { "App\($0)" })
    }

    @Test func theBandPastTheLeftEndIsKeptUpToAQuarterIconAndForgivenOnTheTurn() {
        var switcher = switcher()
        switcher.follow(-30)
        #expect(switcher.travelMM == -3)
        #expect(switcher.selected == 0 && switcher.selectsFrontmost)
        #expect(switcher.stretch < 0 && switcher.stretch > -0.2)
        switcher.follow(-40)
        #expect(switcher.travelMM == -3)
        switcher.follow(-35)
        #expect(switcher.travelMM == 5)
        #expect(switcher.selected == 0)
        #expect(switcher.stretch == 0)
        switcher.follow(-34)
        #expect(switcher.travelMM == 6)
        #expect(switcher.selected == 1)
    }

    @Test func turningBackTakesTheSameHalfIconHoweverFarTheFingersWentPastTheLeftEnd() {
        var switcher = switcher()
        switcher.follow(-300)
        switcher.follow(-294)
        #expect(switcher.selected == 1)
        #expect(switcher.travelMM == 6)
    }

    @Test func theBandPastTheRightEndIsForgivenOnTheTurnToo() {
        var switcher = switcher()
        switcher.follow(60)
        #expect(switcher.travelMM == 39)
        #expect(switcher.selected == 3)
        #expect(switcher.stretch > 0 && switcher.stretch < 0.2)
        switcher.follow(54)
        #expect(switcher.travelMM == 30)
        #expect(switcher.selected == 3)
        switcher.follow(53)
        #expect(switcher.travelMM == 29)
        #expect(switcher.selected == 2)
    }

    @Test func restingAtTheStartHasNoStretch() {
        var switcher = switcher()
        switcher.follow(0)
        #expect(switcher.stretch == 0)
    }

    @Test func theFrontmostAppIsAlwaysFirstAndStartsSelected() {
        let switcher = switcher(frontmost: mail, running: [safari, mail, slack, notes])
        #expect(switcher.row == [mail, safari, slack, notes])
        #expect(switcher.selected == 0)
        #expect(switcher.selectedApp == mail)
        #expect(switcher.selectsFrontmost)
    }

    @Test func aFrontmostAppOutsideTheRunningAppsIsShownAtTheLeftEnd() {
        let bartender = entry("Bartender")
        let switcher = switcher(frontmost: bartender, running: [safari, mail])
        #expect(switcher.row == [bartender, safari, mail])
        #expect(switcher.selectedApp == bartender)
    }

    @Test func identityIsTheRunningCopysLocationNotTheBundleID() {
        let downloads = entry("Slack", at: "/Users/me/Downloads")
        let switcher = switcher(frontmost: downloads, running: [safari, slack, downloads])
        #expect(switcher.row == [downloads, safari, slack])
    }

    @Test func aRowNeedsAnotherIconBesidesTheFrontmostApp() {
        let trackpad = Trackpad.macBook14.id
        #expect(Switcher(frontmost: safari, running: [mail], trackpad: trackpad)?.row.count == 2)
        #expect(Switcher(frontmost: safari, running: [], trackpad: trackpad) == nil)
        #expect(Switcher(frontmost: safari, running: [safari], trackpad: trackpad) == nil)
    }

    @Test(arguments: [
        (travel: 5.9, selected: 0), (6.0, 1), (6.1, 1), (17.9, 1), (18.0, 2), (24.0, 2), (30.0, 3), (36.0, 3),
        (60.0, 3), (-30.0, 0),
    ])
    func theSelectionIsTheNearestIconAndNeverPassesAnEnd(travel: Double, selected: Int) {
        #expect(switcher(travel: travel).selected == selected)
    }

    @Test(arguments: [
        (travel: 18.0, selected: 2), (12.0, 1), (6.0, 1), (5.9, 0), (-6.0, 0),
    ])
    func theSelectionMovesBackUnderTheSameRule(travel: Double, selected: Int) {
        var switcher = switcher()
        switcher.follow(18)
        switcher.follow(travel)
        #expect(switcher.selected == selected)
    }

    @Test func theHighlightSitsBetweenIconsInProportionToTheTravel() {
        let half = switcher(travel: 5)
        #expect(abs(half.position - 5.0 / 12) < 1e-9)
        #expect(half.stretch == 0)
        #expect(switcher(travel: 36).position == 3)
        #expect(switcher(travel: -12).position == 0)
    }

    @Test func pushingPastAnEndStretchesTheHighlightButNeverByAFifthOfAnIcon() {
        let near = switcher(travel: 48)
        let far = switcher(travel: 60)
        #expect(near.position == 3)
        #expect(near.stretch > 0 && near.stretch < 0.2)
        #expect(far.stretch > near.stretch && far.stretch < 0.2)
        #expect(switcher(travel: 1000).stretch < 0.2)
        let before = switcher(travel: -12)
        #expect(before.stretch < 0 && before.stretch > -0.2)
        #expect(switcher(travel: 0).stretch == 0)
        #expect(switcher(travel: 36).stretch == 0)
    }
}
