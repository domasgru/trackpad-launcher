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

    private func switcher(frontmost: AppEntry? = nil, running: [AppEntry]? = nil) throws -> Switcher {
        try #require(
            Switcher(
                frontmost: frontmost ?? safari, running: running ?? [safari, mail, slack, notes],
                leavingOut: [], trackpad: Trackpad.macBook14.id))
    }

    /// A four-item selection, as over the default four-app row.
    private func selection(travel: Double = 0) -> SwitcherSelection {
        var selection = SwitcherSelection(count: 4)
        selection.travelMM = travel
        return selection
    }

    @Test func theRowHoldsTheFrontmostAppAndTheNineMostRecentOthers() throws {
        let running = (1...12).map { entry("App\($0)") }
        let row = try switcher(frontmost: running[11], running: running).row
        #expect(row.map(\.name) == ["App12"] + (1...9).map { "App\($0)" })
    }

    @Test func theBandPastTheLeftEndIsKeptUpToAQuarterIconAndForgivenOnTheTurn() throws {
        var switcher = try switcher()
        switcher.selection.follow(-30)
        #expect(switcher.selection.travelMM == -3)
        #expect(switcher.selection.selected == 0 && switcher.selectsFrontmost)
        #expect(switcher.selection.stretch < 0 && switcher.selection.stretch > -0.2)
        switcher.selection.follow(-40)
        #expect(switcher.selection.travelMM == -3)
        switcher.selection.follow(-35)
        #expect(switcher.selection.travelMM == 5)
        #expect(switcher.selection.selected == 0)
        #expect(switcher.selection.stretch == 0)
        switcher.selection.follow(-34)
        #expect(switcher.selection.travelMM == 6)
        #expect(switcher.selection.selected == 1)
    }

    @Test func turningBackTakesTheSameHalfIconHoweverFarTheFingersWentPastTheLeftEnd() throws {
        var selection = selection()
        selection.follow(-300)
        selection.follow(-294)
        #expect(selection.selected == 1)
        #expect(selection.travelMM == 6)
    }

    @Test func theBandPastTheRightEndIsForgivenOnTheTurnToo() throws {
        var selection = selection()
        selection.follow(60)
        #expect(selection.travelMM == 39)
        #expect(selection.selected == 3)
        #expect(selection.stretch > 0 && selection.stretch < 0.2)
        selection.follow(54)
        #expect(selection.travelMM == 30)
        #expect(selection.selected == 3)
        selection.follow(53)
        #expect(selection.travelMM == 29)
        #expect(selection.selected == 2)
    }

    @Test func restingAtTheStartHasNoStretch() throws {
        var selection = selection()
        selection.follow(0)
        #expect(selection.stretch == 0)
    }

    @Test func theFrontmostAppIsAlwaysFirstAndStartsSelected() throws {
        let switcher = try switcher(frontmost: mail, running: [safari, mail, slack, notes])
        #expect(switcher.row == [mail, safari, slack, notes])
        #expect(switcher.selection.selected == 0)
        #expect(switcher.selectedApp == mail)
        #expect(switcher.selectsFrontmost)
    }

    @Test func aFrontmostAppOutsideTheRunningAppsIsShownAtTheLeftEnd() throws {
        let bartender = entry("Bartender")
        let switcher = try switcher(frontmost: bartender, running: [safari, mail])
        #expect(switcher.row == [bartender, safari, mail])
        #expect(switcher.selectedApp == bartender)
    }

    @Test func identityIsTheRunningCopysLocationNotTheBundleID() throws {
        let downloads = entry("Slack", at: "/Users/me/Downloads")
        let switcher = try switcher(frontmost: downloads, running: [safari, slack, downloads])
        #expect(switcher.row == [downloads, safari, slack])
    }

    @Test func aRowNeedsAnotherIconBesidesTheFrontmostApp() {
        let trackpad = Trackpad.macBook14.id
        #expect(Switcher(frontmost: safari, running: [mail], leavingOut: [], trackpad: trackpad)?.row.count == 2)
        #expect(Switcher(frontmost: safari, running: [], leavingOut: [], trackpad: trackpad) == nil)
        #expect(Switcher(frontmost: safari, running: [safari], leavingOut: [], trackpad: trackpad) == nil)
    }

    @Test(arguments: [
        (travel: 5.9, selected: 0), (6.0, 1), (6.1, 1), (17.9, 1), (18.0, 2), (24.0, 2), (30.0, 3), (36.0, 3),
        (60.0, 3), (-30.0, 0),
    ])
    func theSelectionIsTheNearestIconAndNeverPassesAnEnd(travel: Double, selected: Int) {
        #expect(selection(travel: travel).selected == selected)
    }

    @Test(arguments: [
        (travel: 18.0, selected: 2), (12.0, 1), (6.0, 1), (5.9, 0), (-6.0, 0),
    ])
    func theSelectionMovesBackUnderTheSameRule(travel: Double, selected: Int) {
        var selection = selection()
        selection.follow(18)
        selection.follow(travel)
        #expect(selection.selected == selected)
    }

    @Test func theHighlightSitsBetweenIconsInProportionToTheTravel() {
        let half = selection(travel: 5)
        #expect(abs(half.position - 5.0 / 12) < 1e-9)
        #expect(half.stretch == 0)
        #expect(selection(travel: 36).position == 3)
        #expect(selection(travel: -12).position == 0)
    }

    @Test func pushingPastAnEndStretchesTheHighlightButNeverByAFifthOfAnIcon() {
        let near = selection(travel: 48)
        let far = selection(travel: 60)
        #expect(near.position == 3)
        #expect(near.stretch > 0 && near.stretch < 0.2)
        #expect(far.stretch > near.stretch && far.stretch < 0.2)
        #expect(selection(travel: 1000).stretch < 0.2)
        let before = selection(travel: -12)
        #expect(before.stretch < 0 && before.stretch > -0.2)
        #expect(selection(travel: 0).stretch == 0)
        #expect(selection(travel: 36).stretch == 0)
    }
}
